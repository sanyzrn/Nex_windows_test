// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LinkMetadata {
  const LinkMetadata({this.title, this.excerpt});
  final String? title;
  final String? excerpt;
}

/// Reads web page titles and descriptions up to 256 KB with an 8-second timeout.
/// Strictly parses Open Graph metadata first, then falls back to <title>.
class LinkReader {
  static const int maxBytes = 256 * 1024; // 256 KB cap
  static const Duration timeout = Duration(seconds: 8);

  /// Reads link metadata from an HTTP/HTTPS stream.
  /// If [customStream] is supplied (for testing), reads from it instead of opening network socket.
  static Future<LinkMetadata?> readFromStream(
    Stream<List<int>> stream, {
    String? contentType,
  }) async {
    if (contentType != null &&
        !contentType.contains('text/html') &&
        !contentType.contains('application/xhtml+xml')) {
      return null;
    }

    final bytes = <int>[];
    try {
      await for (final chunk in stream.timeout(timeout)) {
        final remaining = maxBytes - bytes.length;
        if (remaining <= 0) break;
        if (chunk.length <= remaining) {
          bytes.addAll(chunk);
        } else {
          bytes.addAll(chunk.sublist(0, remaining));
          break;
        }
      }
    } on TimeoutException {
      // Partial read before timeout is still parsed
    } catch (_) {
      if (bytes.isEmpty) return null;
    }

    if (bytes.isEmpty) return null;
    final html = utf8.decode(bytes, allowMalformed: true);
    return parseHtml(html);
  }

  /// Parses Open Graph and HTML title tags.
  static LinkMetadata? parseHtml(String html) {
    String? ogTitle;
    String? ogDesc;
    String? fallbackTitle;

    // 1. Open Graph title: <meta property="og:title" content="..."> or name="og:title"
    final ogTitleRegex = RegExp(
      r'''<meta\s+[^>]*?(?:property|name)=["']og:title["'][^>]*?content=["']([^"']*)["']''',
      caseSensitive: false,
    );
    final ogTitleMatch = ogTitleRegex.firstMatch(html);
    if (ogTitleMatch != null) {
      ogTitle = _unescapeHtml(ogTitleMatch.group(1));
    } else {
      // Reversed attributes: content="..." property="og:title"
      final ogTitleRevRegex = RegExp(
        r'''<meta\s+[^>]*?content=["']([^"']*)["'][^>]*?(?:property|name)=["']og:title["']''',
        caseSensitive: false,
      );
      final revMatch = ogTitleRevRegex.firstMatch(html);
      if (revMatch != null) {
        ogTitle = _unescapeHtml(revMatch.group(1));
      }
    }

    // 2. Open Graph description: og:description or description
    final ogDescRegex = RegExp(
      r'''<meta\s+[^>]*?(?:property|name)=["'](?:og:description|description)["'][^>]*?content=["']([^"']*)["']''',
      caseSensitive: false,
    );
    final ogDescMatch = ogDescRegex.firstMatch(html);
    if (ogDescMatch != null) {
      ogDesc = _unescapeHtml(ogDescMatch.group(1));
    } else {
      final ogDescRevRegex = RegExp(
        r'''<meta\s+[^>]*?content=["']([^"']*)["'][^>]*?(?:property|name)=["'](?:og:description|description)["']''',
        caseSensitive: false,
      );
      final revDescMatch = ogDescRevRegex.firstMatch(html);
      if (revDescMatch != null) {
        ogDesc = _unescapeHtml(revDescMatch.group(1));
      }
    }

    // 3. Fallback <title>
    final titleRegex = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false);
    final titleMatch = titleRegex.firstMatch(html);
    if (titleMatch != null) {
      fallbackTitle = _unescapeHtml(titleMatch.group(1)?.trim());
    }

    final title = (ogTitle != null && ogTitle.isNotEmpty) ? ogTitle : fallbackTitle;
    final excerpt = (ogDesc != null && ogDesc.isNotEmpty) ? ogDesc : null;

    if (title == null && excerpt == null) return null;
    return LinkMetadata(title: title, excerpt: excerpt);
  }

  /// Live HTTP fetch for URLs.
  static Future<LinkMetadata?> fetch(Uri uri, {HttpClient? client}) async {
    final http = client ?? (HttpClient()..connectionTimeout = timeout);
    try {
      final request = await http.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'Nex/1.0');
      request.headers.set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml');
      final response = await request.close().timeout(timeout);

      final contentType = response.headers.contentType?.mimeType;
      if (contentType != null &&
          contentType != 'text/html' &&
          contentType != 'application/xhtml+xml') {
        await response.drain();
        return null;
      }

      return await readFromStream(response, contentType: contentType);
    } catch (_) {
      return null;
    } finally {
      if (client == null) http.close(force: true);
    }
  }

  static String? _unescapeHtml(String? text) {
    if (text == null) return null;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

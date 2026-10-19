// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:nex_core/nex_core.dart';

String noteCopyText(Note note) => formatNoteForCopy(note);

/// Formats note content according to Nex platform copy rules:
/// - Caption outranks everything
/// - Voice transcript or photo OCR text next
/// - For text/md/docx documents, the text capped to 50,000 characters
/// - Defaults to note.displayText
String formatNoteForCopy(Note note) {
  final caption = note.caption?.trim();
  if (caption != null && caption.isNotEmpty) return caption;

  final transcript = note.transcriptText?.trim();
  if (transcript != null && transcript.isNotEmpty) return transcript;

  final ocr = note.ocrText?.trim();
  if (ocr != null && ocr.isNotEmpty) return ocr;

  if (note.type == NoteType.file) {
    final path = note.mediaUri;
    final filename = (note.originalFilename ?? path ?? '').toLowerCase();
    final isTextDoc = filename.endsWith('.txt') ||
        filename.endsWith('.md') ||
        filename.endsWith('.markdown') ||
        filename.endsWith('.docx') ||
        filename.endsWith('.json') ||
        filename.endsWith('.csv');
    if (isTextDoc && path != null) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.trim().isNotEmpty) {
            return content.length > 50000
                ? content.substring(0, 50000)
                : content;
          }
        } catch (_) {}
      }
    }
  }

  return note.displayText ?? note.content ?? '';
}

/// Whitelist of permitted Markdown link schemes: only http, https, mailto, tel.
/// Any other scheme (e.g. javascript:, file:, data:) is rejected.
bool isSafeLinkUrl(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' ||
      scheme == 'https' ||
      scheme == 'mailto' ||
      scheme == 'tel';
}

// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/nex/link_reader.dart';

void main() {
  test('caps stream at 256 KB on infinite streams', () async {
    final titleChunk = utf8.encode('<html><head><title>Streaming Test</title></head><body>');
    final bigChunk = utf8.encode('x' * (32 * 1024)); // 32 KB chunk
    // 15 chunks * 32 KB = 480 KB > 256 KB
    final stream = Stream<List<int>>.fromIterable([
      titleChunk,
      for (int i = 0; i < 15; i++) bigChunk,
    ]);

    final meta = await LinkReader.readFromStream(
      stream,
      contentType: 'text/html',
    );

    expect(meta?.title, 'Streaming Test');
  });

  test('Open Graph title and description outrank fallback title', () {
    const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Regular Document Title</title>
  <meta property="og:title" content="Open Graph Social Title" />
  <meta property="og:description" content="A summary of the linked article." />
</head>
<body></body>
</html>
''';

    final meta = LinkReader.parseHtml(html);
    expect(meta?.title, 'Open Graph Social Title');
    expect(meta?.excerpt, 'A summary of the linked article.');
  });

  test('fallback to <title> when og:title is missing', () {
    const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Fallback Standard Title</title>
  <meta name="description" content="Standard description meta tag." />
</head>
<body></body>
</html>
''';

    final meta = LinkReader.parseHtml(html);
    expect(meta?.title, 'Fallback Standard Title');
    expect(meta?.excerpt, 'Standard description meta tag.');
  });

  test('rejects non-HTML content types', () async {
    final stream = Stream.value(utf8.encode('{"json": "not html"}'));
    final meta = await LinkReader.readFromStream(
      stream,
      contentType: 'application/json',
    );
    expect(meta, isNull);
  });

  test('unescapes HTML entities in title and description', () {
    const html = '''
<html><head>
<title>Tom &amp; Jerry &quot;Show&quot; &#39;Special&#39;</title>
</head></html>
''';
    final meta = LinkReader.parseHtml(html);
    expect(meta?.title, 'Tom & Jerry "Show" \'Special\'');
  });
}

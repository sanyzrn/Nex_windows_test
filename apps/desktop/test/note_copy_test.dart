// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/nex/note_copy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1);

  test('caption outranks raw content and transcript', () {
    final note = Note(
      id: 'n1',
      type: NoteType.voice,
      content: 'audio-file.m4a',
      caption: 'My handwritten caption',
      transcriptText: 'Spoken transcript',
      createdAt: now,
      updatedAt: now,
      deviceId: 'test',
      rev: 1,
      syncState: SyncState.synced,
    );

    expect(formatNoteForCopy(note), 'My handwritten caption');
  });

  test('transcript used when caption is empty', () {
    final note = Note(
      id: 'n2',
      type: NoteType.voice,
      content: 'audio-file.m4a',
      transcriptText: 'Meeting recording transcript',
      createdAt: now,
      updatedAt: now,
      deviceId: 'test',
      rev: 1,
      syncState: SyncState.synced,
    );

    expect(formatNoteForCopy(note), 'Meeting recording transcript');
  });

  test('text document capped at 50,000 characters', () {
    final tmpDir = Directory.systemTemp.createTempSync('note_copy_test_');
    final filePath = '${tmpDir.path}/notes.md';
    final longText = 'A' * 60000;
    File(filePath).writeAsStringSync(longText);

    final note = Note(
      id: 'n3',
      type: NoteType.file,
      content: 'notes.md',
      mediaUri: filePath,
      createdAt: now,
      updatedAt: now,
      deviceId: 'test',
      rev: 1,
      syncState: SyncState.synced,
    );

    final copied = formatNoteForCopy(note);
    expect(copied.length, 50000);
    tmpDir.deleteSync(recursive: true);
  });

  test('isSafeLinkUrl allows only http, https, mailto, and tel', () {
    expect(isSafeLinkUrl('https://example.com/test'), isTrue);
    expect(isSafeLinkUrl('http://example.org'), isTrue);
    expect(isSafeLinkUrl('mailto:support@nex.app'), isTrue);
    expect(isSafeLinkUrl('tel:+989123456789'), isTrue);

    expect(isSafeLinkUrl('javascript:alert(1)'), isFalse);
    expect(isSafeLinkUrl('file:///C:/Windows/System32/calc.exe'), isFalse);
    expect(isSafeLinkUrl('data:text/html;base64,PHNjcmlwdD4='), isFalse);
    expect(isSafeLinkUrl('ms-settings:privacy'), isFalse);
  });
}

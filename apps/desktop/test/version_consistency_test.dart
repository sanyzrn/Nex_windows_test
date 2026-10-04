// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nex_desktop/core/app_meta.dart';

/// Rule 10 of the quality round: the version must be identical in
/// `pubspec.yaml`, the About screen, `Runner.rc`, `nex.iss` (including the
/// installer file name), `README.md` and `CHANGELOG.md`. These tests fail
/// when any copy drifts from `lib/core/app_meta.dart`, the single in-app
/// source of truth.
void main() {
  final root = Directory.current.path;

  String read(String relative) =>
      File('$root/$relative').readAsStringSync().replaceAll('\r\n', '\n');

  test('pubspec.yaml declares the same version', () {
    final pubspec = read('pubspec.yaml');
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(
      pubspec,
    );
    expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(match!.group(1), kAppVersionString);
  });

  test('Runner.rc resource version and string match', () {
    final rc = read('windows/runner/Runner.rc');
    final number = RegExp(
      r'#define VERSION_AS_NUMBER\s+(\d+),(\d+),(\d+),(\d+)',
    ).firstMatch(rc);
    expect(number, isNotNull, reason: 'Runner.rc has no VERSION_AS_NUMBER');
    expect(
      '${number!.group(1)}.${number.group(2)}.${number.group(3)}.${number.group(4)}',
      kAppResourceVersion,
    );
    final string = RegExp(
      r'#define VERSION_AS_STRING\s+"([^"]+)"',
    ).firstMatch(rc);
    expect(string, isNotNull, reason: 'Runner.rc has no VERSION_AS_STRING');
    expect(string!.group(1), kAppVersionString);
  });

  test('nex.iss installer version and file name match', () {
    final iss = read('installer/nex.iss');
    expect(iss, contains('AppVersion=$kAppVersionString'));
    expect(iss, contains('VersionInfoVersion=$kAppResourceVersion'));
    expect(iss, contains('OutputBaseFilename=$kInstallerFileBase'));
  });

  test('no stale hard-coded version literals remain in lib', () {
    final libDir = Directory('$root/lib');
    final offenders = <String>[];
    for (final file in libDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (file.path.replaceAll('\\', '/').endsWith('core/app_meta.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      // Older release strings must not linger in application code.
      for (final stale in ['0.9.0', '0.10.0', '0.11.0']) {
        if (text.contains(stale)) offenders.add('${file.path}: $stale');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('root README and desktop CHANGELOG state this version', () {
    expect(read('../../README.md'), contains('0.12.0+8'));
    expect(read('CHANGELOG.md'), contains('## 0.12.0'));
  });

  test('the About screen renders the shared version constant', () {
    final settings = read('lib/nex/settings.dart');
    expect(settings, contains('kAppShortVersion'));
    expect(settings, contains('kAppVersionString'));      // The old hard-coded literal must not come back.
      expect(
        RegExp(r'v0\.\d+\.\d+ \(Build \d+\)').hasMatch(settings),
        isFalse,
        reason: 'About screen must use app_meta constants, not literals',
      );
  });
}

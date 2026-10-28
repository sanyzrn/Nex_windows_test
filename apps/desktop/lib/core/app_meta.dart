// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The single in-app declaration of the Windows app version.
///
/// `test/version_consistency_test.dart` fails when this string disagrees
/// with `pubspec.yaml`, `windows/runner/Runner.rc` or `installer/nex.iss`,
/// so the version can only ever be bumped once per file set.
library;

const String kAppVersionString = '0.36.0+29';

/// `major.minor.build` for display, e.g. `Nex Windows v0.12.0 (Build 8)`.
const String kAppShortVersion = '0.36.0';

/// The `+n` build number.
const int kAppBuild = 29;

/// Windows resource version `major.minor.patch.build` as written in
/// `Runner.rc` (`VERSION_AS_NUMBER`) and `nex.iss` (`VersionInfoVersion`).
const String kAppResourceVersion = '0.36.0.29';

/// Installer file name without extension, as configured in `nex.iss`
/// (`OutputBaseFilename`).
const String kInstallerFileBase = 'Nex-Windows-Setup-0.36.0-x64';

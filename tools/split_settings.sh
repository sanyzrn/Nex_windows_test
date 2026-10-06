#!/usr/bin/env bash
set -e
cd apps/desktop/lib/nex

cat > hdr.txt <<'EOF'
// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the settings view split (see settings.dart); do not import this
// file directly.
part of 'settings.dart';

EOF

# Local declarations repeated at the top of every extracted card builder.
locals() { printf '    final c = LiquidScope.panelOf(context);\n    final l = AppLocalizations.of(context)!;\n    final f = NexScope.maybeOf(context);\n    final scheme = Theme.of(context).colorScheme;\n\n'; }

# Extract inclusive range minus trailing blank lines
extract() { awk "NR>=$2 && NR<=$3" settings.dart | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

# 1) Display + Appearance cards (original lines 49-210)
{ cat hdr.txt; printf 'mixin _SettingsDisplayAppearance on _NexSettingsViewState {\n'; printf '  @override\n  Widget _buildDisplayAppearance(BuildContext context) {\n'; locals; extract x 49 210; printf '  }\n}\n'; } > settings_display_appearance.dart

# 2) Shortcuts + Backup cards (original lines 211-531)
{ cat hdr.txt; printf 'mixin _SettingsShortcutsBackup on _NexSettingsViewState {\n  Widget _buildShortcutsBackup(BuildContext context) {\n'; locals; extract x 211 531; printf '  }\n}\n'; } > settings_shortcuts_backup.dart

# 3) Tools + About cards (original lines 532-636)
{ cat hdr.txt; printf 'mixin _SettingsToolsAbout on _NexSettingsViewState {\n  Widget _buildToolsAbout(BuildContext context) {\n'; locals; extract x 532 636; printf '  }\n}\n'; } > settings_tools_about.dart

rm hdr.txt
wc -l settings_display_appearance.dart settings_shortcuts_backup.dart settings_tools_about.dart

#!/usr/bin/env bash
set -e
cd apps/desktop/lib/ui

cat > hdr.txt <<'EOF'
// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

EOF

# awk 'from,to' line-range extractor: body lines inclusive, minus trailing blank
extract() { awk "NR>=$2 && NR<=$3" window_shell.dart | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

# 1) window_nav_rail.dart: lines 127-578 (_WindowNavRail .. _ModeSwitchButtonState end)
{ cat hdr.txt; extract x 127 578; } > window_nav_rail.dart

# 2) window_section.dart: lines 579-785 (_WindowSection .. _HeaderIcon end)
{ cat hdr.txt; extract x 579 785; } > window_section.dart

# 3) window_sections.dart: lines 786-863 (_CaptureSection .. _CenteredColumn end)
{ cat hdr.txt; extract x 786 863; } > window_sections.dart

# 4) window_tools.dart: lines 864-1150 (_ToolsDirectory .. _ToolCard/_WindowToast end)
{ cat hdr.txt; extract x 864 1150; } > window_tools.dart

# 5) record_stop_button.dart: lines 1151-end (RecordStopButton, public)
{ cat hdr.txt; extract x 1151 2000; } > record_stop_button.dart

rm hdr.txt split_ws.awk 2>/dev/null || true
wc -l window_shell.dart window_nav_rail.dart window_section.dart window_sections.dart window_tools.dart record_stop_button.dart

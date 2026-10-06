#!/usr/bin/env bash
set -e
cd apps/desktop/lib/ui

cat > hdr.txt <<'EOF'
// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the dock split (see dock.dart); do not import this file directly.
part of 'dock.dart';

EOF

extract() { awk "NR>=$2 && NR<=$3" dock.dart | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

# 1) dock_tools.dart: lines 226-509 (_ToolSlot, ToolVisual, ToolVisualState)
{ cat hdr.txt; extract x 226 509; } > dock_tools.dart

# 2) dock_pill.dart: lines 510-734 (_Pill, _TabShapePainter, AppIconImage)
{ cat hdr.txt; extract x 510 734; } > dock_pill.dart

rm hdr.txt
wc -l dock.dart dock_tools.dart dock_pill.dart

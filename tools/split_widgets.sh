#!/usr/bin/env bash
set -e
cd apps/desktop/lib/ui

cat > hdr.txt <<'EOF'
// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the shared widget library split (see widgets.dart); do not import
// this file directly.
part of 'widgets.dart';

EOF

extract() { awk "NR>=$2 && NR<=$3" widgets.dart | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

# 1) widgets_inputs.dart: lines 53-220 (Field, Btn)
{ cat hdr.txt; extract x 53 220; } > widgets_inputs.dart

# 2) widgets_rows.dart: lines 403-634 (ItemRow, ItemAction, Empty, Hint, Toggle)
{ cat hdr.txt; extract x 403 634; } > widgets_rows.dart

# 3) widgets_forms.dart: lines 635-734 (SetRow, SegmentedTabs, _SegTab)
{ cat hdr.txt; extract x 635 734; } > widgets_forms.dart

# 4) widgets_rgba.dart: lines 735-end (RgbaImage, _RgbaPainter)
{ cat hdr.txt; extract x 735 900; } > widgets_rgba.dart

rm hdr.txt
wc -l widgets.dart widgets_inputs.dart widgets_rows.dart widgets_forms.dart widgets_rgba.dart

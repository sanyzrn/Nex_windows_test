#!/usr/bin/env bash
set -e
cd apps/desktop/lib/nex

cat > hdr.txt <<'EOF'
// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the capture view split (see capture_view.dart); do not import
// this file directly.
part of 'capture_view.dart';

EOF

extract() { awk "NR>=$2 && NR<=$3" capture_view.dart | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'; }

# 1) capture_wide.dart: mixin with _buildWide (249-522) + _CaptureAction (546-580)
{ cat hdr.txt
  printf '/// Desktop window layout builder plus the shared capture action tile.\nmixin _CaptureWide on _CaptureViewBase {\n'
  extract x 249 522
  printf '}\n\n'
  extract x 546 580
} > capture_wide.dart

rm hdr.txt
wc -l capture_view.dart capture_wide.dart

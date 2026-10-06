// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

class RecordStopButton extends StatelessWidget {
  const RecordStopButton({super.key, required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    final f = NexScope.maybeOf(context);
    if (f == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: IconButton(
        tooltip: l.stop,
        onPressed: f.recordingBusy ? null : () => f.record(controller),
        icon: Icon(
          Icons.stop_circle_outlined,
          size: 20,
          color: scheme.onErrorContainer,
        ),
      ),
    );
  }
}

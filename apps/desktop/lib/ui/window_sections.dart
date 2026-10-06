// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the window shell split (see window_shell.dart); do not import
// this file directly.
part of 'window_shell.dart';

class _CaptureSection extends StatelessWidget {
  const _CaptureSection();

  @override
  Widget build(BuildContext context) {
    if (NexScope.maybeOf(context) == null) {
      // Tests boot the shell without a store; keep the surface renderable.
      return const Center(child: CircularProgressIndicator());
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: NexCaptureView(compact: false)),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
      children: const [NexSettingsView(windowLayout: true)],
    );
  }
}

/// Placeholder for shells booted without a store (tests).
class _MissingStoreNotice extends StatelessWidget {
  const _MissingStoreNotice();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage_rounded, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            l.libraryUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Centers the child and caps its width for readable line lengths.
class _CenteredColumn extends StatelessWidget {
  const _CenteredColumn({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The tools directory: every dockable utility and pinned app as a large
/// tile. Panel tools open inside the window; actions run directly.

// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the shared widget library split (see widgets.dart); do not import
// this file directly.
part of 'widgets.dart';

class SetRow extends StatelessWidget {
  const SetRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: SizedBox(
        height: 28,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Expanded(child: child)],
        ),
      ),
    );
  }
}

/// `.tabs` segmented control.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.current,
    this.onSwitch,
  });

  final List<String> tabs;
  final String current;
  final ValueChanged<String>? onSwitch;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: _SegTab(
                label: t,
                on: t == current,
                onTap: () => onSwitch?.call(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegTab extends StatefulWidget {
  const _SegTab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_SegTab> createState() => _SegTabState();
}

class _SegTabState extends State<_SegTab> {
  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 26,
          decoration: BoxDecoration(
            color: widget.on ? p.inv : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: _body(context, size: 12).copyWith(
                color: widget.on ? p.invInk : p.muted,
                fontWeight: widget.on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

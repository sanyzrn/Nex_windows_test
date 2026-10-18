import 'package:flutter/material.dart';
import '../tokens/nex_tokens.dart';

/// Quiet desktop surfaces, shared by the window and edge panel. All colours
/// resolve from the active Nex theme, including comfort and high contrast.
class NexWorkspaceCard extends StatelessWidget {
  const NexWorkspaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = NexRadius.lg,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.onSurface.withValues(alpha: .12)),
        boxShadow: MediaQuery.highContrastOf(context)
            ? null
            : [
                // A whisper, not a Material card shadow: on the flat navy
                // page the tonal step and hairline carry the boundary, and a
                // heavy drop shadow was making every quiet surface shout.
                BoxShadow(
                  color: c.shadow.withValues(alpha: .03),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class NexWorkspaceIntro extends StatelessWidget {
  const NexWorkspaceIntro({
    super.key,
    required this.title,
    required this.description,
    this.compact = false,
  });
  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A page title, not a billboard: 36px was competing with everything on
    // the page below it. The Android app's headers sit at ~20–22dp.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: compact ? 20 : 22,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class NexShortcutHint extends StatelessWidget {
  const NexShortcutHint(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          border: Border.all(color: c.outlineVariant),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: c.onSurfaceVariant,
            fontSize: 10,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// A shared keyboard-accessible destination, with a restrained active state.
class NexWorkspaceDestination extends StatelessWidget {
  const NexWorkspaceDestination({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.compact = false,
    this.shortcut,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool compact;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: shortcut == null ? label : '$label ($shortcut)',
        child: TextButton(
          onPressed: onPressed,
          style:
              TextButton.styleFrom(
                foregroundColor: selected ? c.primary : c.onSurfaceVariant,
                backgroundColor: selected
                    ? c.primary.withValues(alpha: .09)
                    : Colors.transparent,
                // 40px is the desktop rail convention (WinUINavigationView);
                // the 8px gap between rows keeps the 48px acquisition pitch
                // Material asks for, and every item keeps its keyboard ring.
                minimumSize: const Size(40, 40),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : 12,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ).copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? BorderSide(color: c.primary, width: 2)
                      : BorderSide.none,
                ),
              ),
          child: compact
              ? Icon(icon, size: 20)
              : Row(
                  children: [
                    Icon(icon, size: 19),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

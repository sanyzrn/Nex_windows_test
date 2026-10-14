import 'package:flutter/material.dart';

/// Quiet desktop surfaces, shared by the window and edge panel. All colours
/// resolve from the active Nex theme, including comfort and high contrast.
class NexWorkspaceCard extends StatelessWidget {
  const NexWorkspaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 24,
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
                BoxShadow(
                  color: c.shadow.withValues(alpha: .04),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: -12,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: compact ? 24 : 36,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          border: Border.all(color: c.outlineVariant),
          borderRadius: BorderRadius.circular(6),
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
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? BorderSide(color: c.primary, width: 2)
                      : BorderSide.none,
                ),
              ),
          child: compact
              ? Icon(icon, size: 22)
              : Row(
                  children: [
                    Icon(icon, size: 21),
                    const SizedBox(width: 12),
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
                    if (shortcut != null) ...[
                      const SizedBox(width: 4),
                      NexShortcutHint(shortcut!),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../tokens/nex_tokens.dart';
import '../tokens/nex_contrast.dart';

/// Shared with the Windows settings, assistant and utility directory. Tonal
/// groups and a quiet coloured edge mirror Nex's Android surfaces.
class NexSoftCard extends StatelessWidget {
  const NexSoftCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final contrast = MediaQuery.highContrastOf(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          c.onSurface.withValues(
            alpha: Theme.of(context).brightness == Brightness.light
                ? .075
                : .025,
          ),
          c.surfaceContainerLow,
        ),
        gradient: accent == null || contrast
            ? null
            : LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Color.alphaBlend(accent!.withValues(alpha: .11), c.surface),
                  c.surfaceContainerLowest,
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: contrast
              ? c.outline
              : accent?.withValues(alpha: .35) ??
                    c.outlineVariant.withValues(alpha: .35),
          width: contrast ? 2 : 1,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class NexIconBadge extends StatelessWidget {
  const NexIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.size = 36,
    this.filled = false,
  });
  final IconData icon;
  final Color? color;
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme, accent = color ?? c.primary;
    final foreground = filled
        ? (nexContrast(accent, c.onSurface) >= nexContrast(accent, c.surface)
              ? c.onSurface
              : c.surface)
        : accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? accent : accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, color: foreground, size: size * .5),
    );
  }
}

class NexSettingsLink extends StatelessWidget {
  const NexSettingsLink({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
    this.trailing,
    this.leading,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: leading ?? NexIconBadge(icon: icon, color: color, size: 32),
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: onTap,
  );
}

/// The grid wraps naturally under large text instead of truncating labels.
class NexFeatureCard extends StatelessWidget {
  const NexFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title, description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return NexSoftCard(
      accent: value && onChanged != null ? c.primary : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NexIconBadge(
                icon: icon,
                size: 32,
                filled: value && onChanged != null,
              ),
              const Spacer(),
              Semantics(
                label: title,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The height of one tile in a tools or shelf grid — a name and two lines.
/// Every tile on a page is this tall, whatever it says, so the grid reads as
/// one family.
const double nexTileMinHeight = 74;

class NexResponsiveGrid extends StatelessWidget {
  const NexResponsiveGrid({
    super.key,
    required this.children,
    this.minWidth = 240,
    this.maxColumns = 2,
    this.spacing = 14,
    this.equalHeights = false,
  });
  final List<Widget> children;
  final double minWidth, spacing;
  final int maxColumns;

  /// Cards in one row take the tallest one's height. Off by default: it asks
  /// every child for its intrinsic height, which a `ListTile` (settings rows)
  /// answers without counting wrapped lines.
  final bool equalHeights;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaled = box.maxWidth / MediaQuery.textScalerOf(context).scale(1);
      final columns = ((scaled + spacing) / (minWidth + spacing)).floor().clamp(
        1,
        maxColumns,
      );
      final width = (box.maxWidth - (columns - 1) * spacing) / columns;
      if (!equalHeights) {
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      }
      // Cards in one row are one height: the tallest sets it. A Wrap left
      // each card as tall as its own words, and a row of boxes in three
      // heights looked like a mistake.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) SizedBox(height: spacing),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) SizedBox(width: spacing),
                    Expanded(
                      child: start + i < children.length
                          ? children[start + i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

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
    this.dense = false,
    this.shortcut,
    this.iconWidget,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool compact;

  /// The quiet desktop rail row: a short, small row with a neutral wash for
  /// the current place instead of the accent's.
  final bool dense;

  /// A count or a mark at the far end of a dense row.
  final Widget? trailing;
  final String? shortcut;
  final Widget? iconWidget;

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
                foregroundColor: dense
                    ? (selected ? c.onSurface : c.onSurfaceVariant)
                    : (selected ? c.primary : c.onSurfaceVariant),
                backgroundColor: selected
                    ? (dense
                          ? c.onSurface.withValues(alpha: .07)
                          : c.primary.withValues(alpha: .09))
                    : Colors.transparent,
                // 40px is the desktop rail convention (WinUINavigationView);
                // the 8px gap between rows keeps the 48px acquisition pitch
                // Material asks for, and every item keeps its keyboard ring.
                minimumSize: Size(40, dense ? 34 : 40),
                tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : (dense ? 10 : 12),
                  vertical: dense ? 6 : 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dense ? 10 : 16),
                ),
              ).copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? BorderSide(color: c.primary, width: 2)
                      : BorderSide.none,
                ),
              ),
          child: compact
              ? (iconWidget ?? Icon(icon, size: 20))
              : Row(
                  children: [
                    iconWidget ?? Icon(icon, size: dense ? 18 : 19),
                    SizedBox(width: dense ? 10 : 11),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
        ),
      ),
    );
  }
}

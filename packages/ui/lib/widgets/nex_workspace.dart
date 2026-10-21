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
    this.padding = const EdgeInsets.all(22),
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
        borderRadius: BorderRadius.circular(24),
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
    this.size = 44,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    leading: leading ?? NexIconBadge(icon: icon, color: color, size: 38),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NexIconBadge(icon: icon, filled: value && onChanged != null),
              const Spacer(),
              Semantics(
                label: title,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: c.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class NexResponsiveGrid extends StatelessWidget {
  const NexResponsiveGrid({
    super.key,
    required this.children,
    this.minWidth = 240,
    this.maxColumns = 2,
    this.spacing = 14,
  });
  final List<Widget> children;
  final double minWidth, spacing;
  final int maxColumns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaled = box.maxWidth / MediaQuery.textScalerOf(context).scale(1);
      final columns = ((scaled + spacing) / (minWidth + spacing)).floor().clamp(
        1,
        maxColumns,
      );
      final width = (box.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
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
    this.shortcut,
    this.iconWidget,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool compact;
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
                  borderRadius: BorderRadius.circular(16),
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
                    iconWidget ?? Icon(icon, size: 19),
                    const SizedBox(width: 11),
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
                  ],
                ),
        ),
      ),
    );
  }
}

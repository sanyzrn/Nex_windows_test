import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../l10n/app_localizations.dart';

class NexWindowCaption extends StatelessWidget {
  const NexWindowCaption({super.key, required this.controller});
  final PanelController controller;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .4),
            ),
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => controller.native.windowCommand('drag'),
                  onDoubleTap: () =>
                      controller.native.windowCommand('maximize'),
                  onSecondaryTap: () => controller.native.windowCommand('menu'),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: scheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l.applicationName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _CaptionButton(
                label: l.minimizeWindow,
                icon: Icons.remove_rounded,
                onPressed: () => controller.native.windowCommand('minimize'),
              ),
              _CaptionButton(
                label: l.maximizeWindow,
                icon: controller.S.windowMaximized
                    ? Icons.filter_none_rounded
                    : Icons.crop_square_rounded,
                onPressed: () => controller.native.windowCommand('maximize'),
              ),
              _CaptionButton(
                label: l.closeWindow,
                icon: Icons.close_rounded,
                close: true,
                onPressed: () => controller.native.windowCommand('close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.close = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool close;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 46,
      height: 44,
      child: IconButton(
        tooltip: label,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          hoverColor: close
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          foregroundColor: close ? scheme.error : scheme.onSurfaceVariant,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
      ),
    );
  }
}

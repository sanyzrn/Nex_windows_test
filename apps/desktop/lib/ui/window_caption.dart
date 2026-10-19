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
      height: 36,
      // No bar of its own: the caption is the window surface itself — the
      // mark on the leading side, the window buttons on the other.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => controller.native.windowCommand('drag'),
                onDoubleTap: () => controller.native.windowCommand('maximize'),
                onSecondaryTap: () => controller.native.windowCommand('menu'),
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: scheme.onPrimary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.applicationName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                          color: scheme.onSurfaceVariant,
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
      width: 40,
      height: 36,
      child: IconButton(
        tooltip: label,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          hoverColor: close
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          foregroundColor: close ? scheme.error : scheme.onSurfaceVariant,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
      ),
    );
  }
}

part of 'shell.dart';

/// The floating clone that follows the cursor during widget drags.
class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DragInfo?>(
      valueListenable: controller.dragInfo,
      builder: (context, drag, _) {
        if (drag == null || !drag.moved || drag.pointer == null) {
          return const SizedBox.shrink();
        }
        final p = LiquidScope.paletteOf(context);
        final info = ToolInfo.of(drag.id);
        return Positioned(
          left: drag.pointer!.dx,
          top: drag.pointer!.dy,
          child: Transform.translate(
            offset: const Offset(-22, -22),
            child: Transform.scale(
              scale: 1.06,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.liquid,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withValues(alpha: 0.45),
                      offset: const Offset(0, 10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: info.emoji != null
                      ? Text(
                          info.emoji!,
                          style: const TextStyle(
                            fontFamily: 'Segoe UI Emoji',
                            fontSize: 19,
                          ),
                        )
                      : info.kind == ToolKind.app && info.app?.icon != null
                      ? AppIconImage(dataUri: info.app!.icon!)
                      : (info.svg != null
                            ? SvgIcon(info.svg!, size: 20, color: p.ink)
                            : const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DropHintOverlay extends StatelessWidget {
  const _DropHintOverlay({required this.controller});
  final PanelController controller;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller.dropHintOn,
    builder: (context, visible, _) {
      final left = controller.S.edge == 'left';
      final p = controller.palette;
      return Positioned(
        left: left ? 90 : null,
        right: left ? null : 90,
        top: 20,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              key: const ValueKey('capture-drop-hint'),
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.liquid,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Text(
                AppLocalizations.of(context)!.dropFiles,
                style: TextStyle(color: p.ink),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The toast that pops in at the bottom of the panel.
class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({required this.controller});

  final PanelController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.toastMsg,
      builder: (context, msg, _) {
        final text = msg?.split('\x00').first;
        final visible = text != null;
        final c = controller;
        final left = c.S.edge == 'left';
        return Positioned(
          left: left ? 100 : null,
          right: left ? null : 100,
          bottom: 20,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: visible ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 550),
                curve: kPop,
                offset: visible ? Offset.zero : const Offset(0, 1),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 550),
                  curve: kPop,
                  scale: visible ? 1 : .8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.palette.liquid,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.palette.line),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.35),
                          offset: const Offset(0, 10),
                          blurRadius: 30,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: Text(
                      text ?? '',
                      style: TextStyle(
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        fontFamilyFallback: const ['Segoe UI'],
                        fontSize: 12,
                        color: c.palette.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

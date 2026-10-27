import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import '../l10n/shortcut_labels.dart';
import '../l10n/utility_strings.dart';
import '../l10n/intelligence_strings.dart';
import '../l10n/desktop_strings.dart';
import '../l10n/desktop_format.dart';
import '../core/controller.dart';
import '../core/registry.dart';
import '../nex/command_palette.dart';
import '../nex/features.dart';
import '../nex/modules/modules.dart';
import '../nex/collection_shelves.dart';
import '../nex/workspace_home.dart';
import '../nex/settings.dart';
import '../nex/intelligence/workspace.dart';
import '../nex/shortcuts_dialog.dart';
import 'dock.dart' show AppIconImage;
import 'flyout.dart' show buildPanelView;
import 'svg_icon.dart';
import 'widgets.dart';
import 'rail_tags.dart';
import 'window_caption.dart';
import '../updates/widgets.dart';

part 'window_nav_rail.dart';
part 'window_slim_rail.dart';
part 'window_section.dart';
part 'window_sections.dart';
part 'window_tools.dart';
part 'record_stop_button.dart';

/// Window width (logical px) from which the rail grows labels beside its
/// icons. Below it — the compact card Nex opens as — the rail is the slim
/// icon-over-label column.
const double kWindowWideAt = 960;

/// How much smaller the desktop window sets its type than the edge panel:
/// a pointer needs no touch-sized text, and a wide page reads calmer small.
const double kWindowTypeDensity = .92;

/// The surface behind the content card: the surface tone washed with the
/// accent, so every theme gets a window of its own colour rather than a
/// neutral grey.
Color nexWindowTint(ColorScheme scheme) => Color.alphaBlend(
  scheme.primary.withValues(
    alpha: scheme.brightness == Brightness.light ? .08 : .12,
  ),
  scheme.surfaceContainerLow,
);

/// The classic accent is an icon/focus color. Navigation labels need a
/// stronger ink over the tinted rail and its selected wash.
ThemeData nexDesktopRailTheme(ThemeData base) {
  final colors = base.colorScheme;
  final selected = Color.alphaBlend(
    colors.primary.withValues(alpha: .09),
    nexWindowTint(colors),
  );
  return base.copyWith(
    colorScheme: colors.copyWith(
      primary: nexReadableOn(colors.primary, selected, ratio: 5),
    ),
  );
}

/// The full desktop window shell — the app's main mode. A navigation rail on
/// the leading edge switches between Capture, Library, Tools and Settings;
/// the edge slide-out panel remains available as an optional mode and both
/// surfaces drive the same [PanelController], [NexFeatures] and store.
///
/// The window itself is a normal resizable, minimize/maximize-able Win32
/// window (the bridge restyles the host when this shell is active), so this
/// widget paints an opaque background and stays put when focus is lost.
class NexWindowShell extends StatefulWidget {
  const NexWindowShell({super.key, required this.controller, this.features});

  final PanelController controller;
  final NexFeatures? features;

  @override
  State<NexWindowShell> createState() => _NexWindowShellState();
}

class _NexWindowShellState extends State<NexWindowShell> {
  bool _writing = false;
  @override
  void initState() {
    super.initState();
    // Stale geometry hooks from the panel shell must never be called while
    // the window shell owns the surface.
    final c = widget.controller;
    c.dockAnchorOf = null;
    c.moreAnchorOf = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && c.isWindowMode) {
        unawaited(c.native.surfaceReady('window').catchError((_) {}));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    Widget buildSurface(BuildContext context, Widget? child) {
      final wide = MediaQuery.sizeOf(context).width >= kWindowWideAt;
      final surface = Column(
        children: [
          NexWindowCaption(controller: c),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_writing)
                  Theme(
                    data: nexDesktopRailTheme(Theme.of(context)),
                    child: wide
                        ? _WindowNavRail(
                            controller: c,
                            features: widget.features,
                          )
                        : _SlimRail(controller: c, features: widget.features),
                  ),
                Expanded(
                  key: const ValueKey('window-content'),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: NexSpacing.sm + 2,
                      bottom: NexSpacing.sm + 2,
                    ),
                    child: Material(
                      key: const ValueKey('window-card'),
                      color: scheme.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NexRadius.xl),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: .5),
                        ),
                      ),
                      child: Column(
                        children: [
                          NexUpdateBanner(updates: widget.features?.updates),
                          Expanded(
                            child: _WindowSection(
                              controller: c,
                              writing: _writing,
                              toggleWriting: () =>
                                  setState(() => _writing = !_writing),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      // The selected palette owns its motif on every platform. The desktop
      // uses a quieter strength behind its dense working content.
      if (MediaQuery.highContrastOf(context)) return surface;
      return NexTextureBackdrop(
        texture: nexThemeTexture(c.S.preset),
        extent: 0.4,
        alpha: 0.018,
        child: surface,
      );
    }

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Scaffold(
        // transparentScaffold is for the floating edge panel; the desktop
        // window must paint an opaque surface.
        backgroundColor: nexWindowTint(scheme),
        body: LiquidScope(
          controller: c,
          palette: c.palette,
          dir: 1,
          child: Focus(
            skipTraversal: true,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final isCtrl = HardwareKeyboard.instance.isControlPressed;
                final isShift = HardwareKeyboard.instance.isShiftPressed;

                if (event.logicalKey == LogicalKeyboardKey.f1 ||
                    (isCtrl && event.logicalKey == LogicalKeyboardKey.slash)) {
                  showShortcutsDialog(context);
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyK) {
                  unawaited(
                    showCommandPalette(
                      context,
                      controller: c,
                      features: widget.features,
                    ),
                  );
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyL) {
                  c.selectWindowSection('library');
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.comma) {
                  c.selectWindowSection('settings');
                  return KeyEventResult.handled;
                }

                if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
                  c.selectWindowSection('capture');
                  if (widget.features != null) {
                    unawaited(widget.features!.fresh(asChecklist: isShift));
                  }
                  return KeyEventResult.handled;
                }

                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  if (_writing) {
                    setState(() => _writing = false);
                    return KeyEventResult.handled;
                  }
                  final tool = c.windowTool.value;
                  if (tool != null) {
                    c.windowTool.value = null;
                    c.refresh();
                    return KeyEventResult.handled;
                  }
                }
              }
              return KeyEventResult.ignored;
            },
            // Capture and status widgets subscribe independently. A composer
            // keystroke must not rebuild the caption, card and navigation.
            child: Builder(builder: (context) => buildSurface(context, null)),
          ),
        ),
      ),
    );
  }
}

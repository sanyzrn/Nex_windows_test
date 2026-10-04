import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/controller.dart';
import 'views/clipboard_view.dart';
import 'views/color_view.dart';
import 'views/emoji_view.dart';
import 'views/more_view.dart';
import '../nex/features.dart';
import '../nex/settings.dart';
import '../l10n/app_localizations.dart';
import '../l10n/utility_strings.dart';

import 'views/small_views.dart';
import 'views/small_views2.dart';
import 'widgets.dart';

/// The flyout that pours out next to the clicked dock button: 360px wide,
/// moved by the grow/fy springs with velocity-driven squash and a radius
/// that starts huge and settles to 22.
class Flyout extends StatelessWidget {
  const Flyout({super.key, required this.controller});

  final PanelController controller;

  static const double width = 360;
  static const double rightOffset = 90; // dock width + 12

  @override
  Widget build(BuildContext context) {
    // While closing, the old panel stays visible as the flyout shrinks.
    final panelId = controller.panel ?? controller.lastPanel;
    final content = panelId == null
        ? const SizedBox(width: width, height: 1)
        : SizedBox(
            width: width,
            child: KeyedSubtree(
              key: ValueKey('$panelId-${controller.panelSerial}'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelHeader(controller: controller, id: panelId),
                  buildPanelView(context, controller, panelId),
                ],
              ),
            ),
          );

    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      child: content,
      builder: (context, _, child) {
        final g = controller.grow.v;
        final gv = controller.grow.vel;
        final gs = g < 0 ? 0.0 : g;
        final Y = controller.fy.v;
        final flyH = controller.flyH;
        final dir = controller.dir;
        double clamp01(double x) => x.clamp(0.0, 1.0);
        final stX = 1 + (gv * .04).clamp(-.15, .15);
        final stY = 1 - (gv * .025).clamp(-.1, .1);
        final opacity = clamp01(gs * 1.6);
        final tx = (1 - clamp01(gs)) * 40 * dir;
        final ty = Y - flyH / 2;
        final sx = .05 > gs * stX ? .05 : gs * stX;
        final sy = .1 > (.25 + .75 * clamp01(gs)) * stY
            ? .1
            : (.25 + .75 * clamp01(gs)) * stY;
        final radius = 22 + (1 - clamp01(gs)) * 60;

        return Positioned(
          left: controller.dir < 0 ? rightOffset : null,
          right: controller.dir < 0 ? null : rightOffset,
          top: 0,
          width: width,
          // Transforms must precede bounded opacity in the hit-test tree.
          // Otherwise the translated lower half paints outside Opacity's
          // unshifted bounds and receives no input despite being visible.
          child: Transform.translate(
            offset: Offset(tx, ty),
            child: Transform(
              alignment: controller.dir < 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              transform: (Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: controller.palette.liquid,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: controller.palette.line),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: .16),
                        offset: const Offset(0, 6),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: ConstrainedBox(
                      key: controller.flyBoxKey,
                      constraints: BoxConstraints(
                        maxHeight: (MediaQuery.sizeOf(context).height - 20)
                            .clamp(0, double.infinity),
                      ),
                      child: SingleChildScrollView(child: child),
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.controller, required this.id});
  final PanelController controller;
  final String id;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final features = NexScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              utilityLabelForText(context, ToolInfo.of(id).name),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const ValueKey('panel-pin'),
            tooltip: controller.S.panelPinned ? l.unpinPanel : l.pinPanel,
            isSelected: controller.S.panelPinned,
            style: IconButton.styleFrom(
              backgroundColor: controller.S.panelPinned
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              foregroundColor: controller.S.panelPinned
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : null,
            ),
            onPressed: controller.togglePanelPin,
            icon: const Icon(Icons.push_pin_outlined, size: 19),
            selectedIcon: const Icon(Icons.push_pin_rounded, size: 19),
          ),
          if (features?.recordingAt != null)
            IconButton(
              tooltip: l.stop,
              onPressed: features!.recordingBusy
                  ? null
                  : () => features.record(controller),
              icon: Icon(
                Icons.stop_circle_outlined,
                color: Theme.of(context).colorScheme.error,
                size: 19,
              ),
            ),
          IconButton(
            tooltip: l.close,
            onPressed: controller.close,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

/// Builds the content of the open panel.
Widget buildPanelView(
  BuildContext context,
  PanelController controller,
  String id,
) {
  switch (id) {
    case 'emoji':
      return const EmojiView();
    case 'clip':
      return const ClipboardView();
    case 'color':
      return const ColorView();
    case 'note':
      return NexScope.maybeOf(context) == null
          ? const SizedBox(height: 200)
          : const NexCaptureView();
    case 'timeline':
      return const NexLibraryView();
    case 'more':
      return const MoreView();
    case 'calc':
      return const CalcView();
    case 'timer':
      return const TimerView();
    case 'stopwatch':
      return const StopwatchView();
    case 'text':
      return const TextToolsView();
    case 'pass':
      return const PasswordView();
    case 'unit':
      return const UnitsView();
    case 'media':
      return const MediaView();
    case 'gen':
      return const GenerateView();
    case 'folders':
      return const FoldersView();
    case 'snippets':
      return const SnippetsView();
    case 'search':
      return const SearchView();
    case 'clock':
      return const ClockView();
    case 'settings':
      return const NexSettingsView();
    default:
      return const SizedBox(width: Flyout.width);
  }
}

/// `.panel`: column, 16px padding, 10px gaps, children rising in staggered
/// (8px up + blur 5px, 30ms steps, .45s cubic-bezier(.2,.8,.2,1)).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _Rise(
              delay: Duration(milliseconds: (i.clamp(0, 4) * 30)),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _Rise extends StatefulWidget {
  const _Rise({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _started ? 1 : 0),
      duration: const Duration(milliseconds: 450),
      curve: kRise,
      builder: (context, t, __) {
        Widget c = Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: widget.child,
          ),
        );
        if (t < 1) {
          c = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 5 * (1 - t),
              sigmaY: 5 * (1 - t),
            ),
            child: c,
          );
        }
        return c;
      },
    );
  }
}

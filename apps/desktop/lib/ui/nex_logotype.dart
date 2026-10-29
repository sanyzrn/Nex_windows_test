// Nex wordmark paths and motion adapted from DbsNex (MIT), commit 5561c017.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class NexBrand {
  /// The wordmark's n, e and the ink strokes of the x.
  static final ui.Path wordN = nexSvgPath(_n);
  static final ui.Path wordE = nexSvgPath(_e)
    ..fillType = ui.PathFillType.evenOdd;
  static final ui.Path wordX = nexSvgPath(_xLow)
    ..addPath(nexSvgPath(_xHigh), Offset.zero);

  /// The x's blue stroke.
  static final ui.Path swoosh = nexSvgPath(_swoosh);

  /// The blue dot after the x.
  static const dot = Offset(823.2855, 111.6896);
  static const dotRadius = 22.7299;

  /// Where the wordmark's ink sits in its own coordinates.
  static final Rect wordBounds = wordN
      .getBounds()
      .expandToInclude(wordE.getBounds())
      .expandToInclude(wordX.getBounds())
      .expandToInclude(swoosh.getBounds())
      .expandToInclude(Rect.fromCircle(center: dot, radius: dotRadius));

  /// The wordmark's n.
  static const _n =
      'M273.2514,198.0063c-27.9847,0-50.6708-22.6861-50.6708-50.6708v-52.0313c0-30.6064-8.5015-38.0879-41.1484-38.0879h-55.0918c-31.9668,0-41.1489,7.4814-41.1489,38.0879v102.7021h-50.6709v-104.4023c0-58.8325,20.0645-79.917,88.4189-79.917h61.5532c68.6948,0,88.7588,21.0845,88.7588,79.917v104.4023h0Z';

  /// The e, with its counter as a second subpath (even-odd).
  static const _e =
      'M361.3315,124.5507v8.5015c0,22.4448,6.8018,26.5259,30.6064,26.5259h59.853c0,21.2233-17.2049,38.4282-38.4282,38.4282h-21.4248c-58.4922,0-81.2773-21.0845-81.2773-70.0552v-42.5088c0-53.7314,18.7041-71.7554,83.6582-71.7554h89.0986c52.7114,0,67.3345,21.0845,67.3345,50.3306v60.5332h-189.4204ZM500.081,68.0985c0-12.2427-5.4409-15.3032-20.7441-15.3032h-84.3379c-25.5059,0-33.6675,2.7207-33.6675,29.2461v9.8623h138.7495v-23.8052Z';

  /// The blue stroke of the x.
  static const _swoosh =
      'M608.5122,198.0063s-62.7047-.6252-62.7047,0C706.3112,3.3623,890.5281,15.9327,890.5281,15.9327c0,0-143.038,7.1349-282.0159,182.0736Z';

  /// The lower half of the x's other stroke.
  static const _xLow =
      'M682.8498,139.6855l11.2852,12.0868c55.9391,55.9391,66.0732,46.2338,106.4205,46.234h0s-85.3818-86.3167-85.3818-86.3167c-10.6105,8.4734-21.4095,17.7771-32.3239,27.9958Z';

  /// The upper half of the x's other stroke.
  static const _xHigh =
      'M666.0425,64.4799l-48.7862-50.7931h-60.873s75.4403,74.8124,75.4403,74.8124c11.3323-8.8257,22.7773-16.8059,34.2189-24.0193Z';
}

/// Parses SVG path data into a [ui.Path].
///
/// Covers what the brand files use and their neighbours — M, L, H, V, C, S and
/// Z, absolute and relative — and throws on anything else rather than drawing
/// something subtly wrong.
ui.Path nexSvgPath(String data) {
  final path = ui.Path();
  final tokens = RegExp(
    r'[A-DF-Za-df-z]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((m) => m[0]!).toList();
  var i = 0;
  var command = '';
  var x = 0.0, y = 0.0;
  var startX = 0.0, startY = 0.0;
  // The second control point of the last curve, for S's reflection.
  double? controlX, controlY;

  bool isCommand(String token) => RegExp(r'^[A-Za-z]$').hasMatch(token);
  double next() {
    if (i >= tokens.length || isCommand(tokens[i])) {
      throw FormatException('command $command is missing a number', data);
    }
    return double.parse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (isCommand(tokens[i])) {
      command = tokens[i++];
    } else if (command.isEmpty) {
      throw FormatException('path data must start with a command', data);
    }
    final relative = command == command.toLowerCase();
    final ox = relative ? x : 0.0, oy = relative ? y : 0.0;
    switch (command.toUpperCase()) {
      case 'M':
        x = ox + next();
        y = oy + next();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        controlX = controlY = null;
        // Further pairs after a move are lines.
        command = relative ? 'l' : 'L';
      case 'L':
        x = ox + next();
        y = oy + next();
        path.lineTo(x, y);
        controlX = controlY = null;
      case 'H':
        x = ox + next();
        path.lineTo(x, y);
        controlX = controlY = null;
      case 'V':
        y = oy + next();
        path.lineTo(x, y);
        controlX = controlY = null;
      case 'C':
        final x1 = ox + next(), y1 = oy + next();
        final x2 = ox + next(), y2 = oy + next();
        x = ox + next();
        y = oy + next();
        path.cubicTo(x1, y1, x2, y2, x, y);
        controlX = x2;
        controlY = y2;
      case 'S':
        final x1 = controlX == null ? x : 2 * x - controlX;
        final y1 = controlY == null ? y : 2 * y - controlY;
        final x2 = ox + next(), y2 = oy + next();
        x = ox + next();
        y = oy + next();
        path.cubicTo(x1, y1, x2, y2, x, y);
        controlX = x2;
        controlY = y2;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        controlX = controlY = null;
      default:
        throw FormatException('unsupported path command $command', data);
    }
  }
  return path;
}

/// The same wordmark without motion, used in the window caption.
class NexStaticLogotype extends StatelessWidget {
  const NexStaticLogotype({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) {
    final bounds = NexBrand.wordBounds;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Nex',
      image: true,
      child: CustomPaint(
        size: Size(height * bounds.width / bounds.height, height),
        painter: _LivingLogotypePainter(
          ink: colors.onSurface,
          accent: colors.primary,
          t: 0,
        ),
      ),
    );
  }
}

/// The wordmark at the top of the timeline: its blue parts in the app's
/// accent, and alive.
///
/// The stroke through the x and the dot after it were the brand blue whatever
/// palette was chosen — the one patch of colour on the screen that ignored
/// the theme. They take the accent now, so Forest's wordmark is green.
///
/// And every few seconds they move, once and briefly: a light runs along the
/// stroke, the way a pen would draw it, and the dot gives a small hop and
/// lands. Seven seconds apart, under a second each, and never at all with
/// animations turned off — a sign of life in the corner, not something
/// competing with the notes. A touch plays it at once, and the seven
/// seconds start again from there.
class NexLivingLogotype extends StatefulWidget {
  const NexLivingLogotype({super.key, required this.height});

  final double height;

  /// Between one movement and the next.
  static const interval = Duration(seconds: 7);

  /// The first one, a moment after the screen appears.
  static const firstDelay = Duration(milliseconds: 1600);

  /// Whether the movement happens at all.
  ///
  /// Off under `flutter test`, where the clock is fake: a test that waits for
  /// the screen to settle in ten-second steps would find a fresh movement
  /// started in every step and never settle. The wordmark's own test turns it
  /// back on. Not `const` so that test can.
  static bool enabled = !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<NexLivingLogotype> createState() => _NexLivingLogotypeState();
}

class _NexLivingLogotypeState extends State<NexLivingLogotype>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = null;
    if (!NexLivingLogotype.enabled || MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 0;
      return;
    }
    // A timer between movements rather than a repeating animation: nothing is
    // ticking in the six seconds the wordmark is still, and a test that waits
    // for the screen to settle is not waiting on a loop that never ends.
    _timer = Timer(NexLivingLogotype.firstDelay, _play);
  }

  void _play() {
    if (!mounted) return;
    unawaited(_motion.forward(from: 0));
    _timer = Timer(NexLivingLogotype.interval, _play);
  }

  /// A touch plays it now, and the seven seconds start again from here —
  /// the next one is not due a moment after the one just asked for.
  void _touched() {
    if (!NexLivingLogotype.enabled || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer?.cancel();
    HapticFeedback.selectionClick();
    _play();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bounds = NexBrand.wordBounds;
    return Semantics(
      label: 'Nex',
      image: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Not a control, so not announced as one: a small thing to find.
        excludeFromSemantics: true,
        onTap: _touched,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) => CustomPaint(
            size: Size(
              widget.height * bounds.width / bounds.height,
              widget.height,
            ),
            painter: _LivingLogotypePainter(
              ink: theme.colorScheme.onSurface,
              accent: theme.colorScheme.primary,
              t: _motion.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _LivingLogotypePainter extends CustomPainter {
  _LivingLogotypePainter({
    required this.ink,
    required this.accent,
    required this.t,
  });

  final Color ink;
  final Color accent;
  final double t;

  static double _span(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final hop = _span(t, 0.35, 0.85);
    nexPaintLogotype(
      canvas,
      size,
      ink: ink,
      accent: accent,
      light: Curves.easeInOutCubic.transform(_span(t, 0, 0.6)),
      // 75 units of the wordmark's own coordinates, as it always hopped.
      lift: math.sin(math.pi * hop) * 75 / (NexBrand.wordBounds.height * 0.55),
      squash: math.sin(math.pi * _span(t, 0.85, 1)) * 0.18,
    );
  }

  @override
  bool shouldRepaint(_LivingLogotypePainter old) =>
      old.t != t || old.ink != ink || old.accent != accent;
}

/// Paints the "nex" wordmark into [size], the parts that move in [accent]
/// (2.3.3: shared by the timeline's wordmark and pull to refresh).
///
/// [written] is how much of the x's stroke is drawn, tail to tip; [light]
/// where a light running along it is (0 and 1 mean none); [dot] how big the
/// dot is, overshoot allowed; [lift] how far it has hopped, as a share of
/// the wordmark's height; [squash] how much it gives where it lands.
void nexPaintLogotype(
  Canvas canvas,
  Size size, {
  required Color ink,
  required Color accent,
  double written = 1,
  double light = 0,
  double dot = 1,
  double lift = 0,
  double squash = 0,
  double opacity = 1,
}) {
  if (opacity <= 0) return;
  final bounds = NexBrand.wordBounds;
  final scale = size.height / bounds.height;
  canvas
    ..save()
    ..scale(scale)
    ..translate(-bounds.left, -bounds.top);
  final inkPaint = Paint()..color = ink.withValues(alpha: ink.a * opacity);
  canvas
    ..drawPath(NexBrand.wordN, inkPaint)
    ..drawPath(NexBrand.wordE, inkPaint)
    ..drawPath(NexBrand.wordX, inkPaint);
  final tone = accent.withValues(alpha: accent.a * opacity);
  if (written > 0) {
    final box = NexBrand.swoosh.getBounds();
    final stroke = Paint()..color = tone;
    if (light > 0 && light < 1) {
      final glow = Color.lerp(tone, Colors.white, 0.6)!;
      final at = -0.2 + 1.4 * light;
      stroke.shader = ui.Gradient.linear(
        box.bottomLeft,
        box.topRight,
        [tone, glow, tone],
        [
          (at - 0.18).clamp(0.0, 1.0),
          at.clamp(0.0, 1.0),
          (at + 0.18).clamp(0.0, 1.0),
        ],
      );
    }
    canvas.save();
    if (written < 1) {
      // Written from its tail at the bottom left to its tip at the top
      // right, the way a pen would draw it.
      canvas.clipRect(
        Rect.fromLTRB(
          box.left,
          box.bottom - box.height * written,
          box.left + box.width * written,
          box.bottom,
        ),
      );
    }
    canvas
      ..drawPath(NexBrand.swoosh, stroke)
      ..restore();
  }
  if (dot > 0) {
    canvas
      ..save()
      ..translate(
        NexBrand.dot.dx,
        NexBrand.dot.dy - lift * bounds.height * 0.55,
      )
      ..scale(dot * (1 + squash), dot * (1 - squash))
      ..drawCircle(Offset.zero, NexBrand.dotRadius, Paint()..color = tone)
      ..restore();
  }
  canvas.restore();
}

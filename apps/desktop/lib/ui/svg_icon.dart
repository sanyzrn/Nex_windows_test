import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Minimal SVG-subset renderer for the icon set: supports <path>, <circle>,
/// <rect> (with rx) inside a 24x24 viewBox, with path data commands
/// M m L l H h V v C c S s Q q T t A a Z z — including implicit
/// parameter repetition. Keeps the exact geometry of the original icons.
Path parseSvgPathData(String d) {
  final path = Path();
  final re = RegExp(
    r'([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d*\.\d+|\d+)(?:[eE][+-]?\d+)?)',
  );
  final tokens = re.allMatches(d.replaceAll(',', ' ')).toList();

  var i = 0;
  var cx = 0.0, cy = 0.0; // current point
  var sx = 0.0, sy = 0.0; // sub-path start
  var cmd = '';

  bool moreNums() => i < tokens.length && tokens[i].group(1) == null;
  double num() => double.parse(tokens[i++].group(0)!);

  while (i < tokens.length) {
    final c = tokens[i].group(1);
    if (c != null) {
      cmd = c;
      i++;
    }
    switch (cmd) {
      case 'M':
      case 'm':
        var first = true;
        while (moreNums() &&
            i + 1 < tokens.length &&
            tokens[i + 1].group(1) == null) {
          var x = num(), y = num();
          if (cmd == 'm') {
            x += cx;
            y += cy;
          }
          if (first) {
            path.moveTo(x, y);
            sx = x;
            sy = y;
          } else {
            _lineTo(path, cx, cy, x, y);
          }
          first = false;
          cx = x;
          cy = y;
        }
        // implicit repetitions of M are line-tos
        cmd = cmd == 'M' ? 'L' : 'l';
        break;
      case 'L':
      case 'l':
        while (moreNums() &&
            i + 1 < tokens.length &&
            tokens[i + 1].group(1) == null) {
          var x = num(), y = num();
          if (cmd == 'l') {
            x += cx;
            y += cy;
          }
          _lineTo(path, cx, cy, x, y);
          cx = x;
          cy = y;
        }
        break;
      case 'H':
      case 'h':
        while (moreNums()) {
          var x = num();
          if (cmd == 'h') x += cx;
          _lineTo(path, cx, cy, x, cy);
          cx = x;
        }
        break;
      case 'V':
      case 'v':
        while (moreNums()) {
          var y = num();
          if (cmd == 'v') y += cy;
          _lineTo(path, cx, cy, cx, y);
          cy = y;
        }
        break;
      case 'C':
      case 'c':
        while (moreNums() &&
            i + 5 < tokens.length &&
            tokens[i + 5].group(1) == null) {
          var x1 = num(),
              y1 = num(),
              x2 = num(),
              y2 = num(),
              x = num(),
              y = num();
          if (cmd == 'c') {
            x1 += cx;
            y1 += cy;
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          path.cubicTo(x1, y1, x2, y2, x, y);
          cx = x;
          cy = y;
        }
        break;
      case 'S':
      case 's':
        while (moreNums() &&
            i + 3 < tokens.length &&
            tokens[i + 3].group(1) == null) {
          var x2 = num(), y2 = num(), x = num(), y = num();
          if (cmd == 's') {
            x2 += cx;
            y2 += cy;
            x += cx;
            y += cy;
          }
          path.cubicTo(cx, cy, x2, y2, x, y);
          cx = x;
          cy = y;
        }
        break;
      case 'Q':
      case 'q':
        while (moreNums() &&
            i + 3 < tokens.length &&
            tokens[i + 3].group(1) == null) {
          var x1 = num(), y1 = num(), x = num(), y = num();
          if (cmd == 'q') {
            x1 += cx;
            y1 += cy;
            x += cx;
            y += cy;
          }
          path.quadraticBezierTo(x1, y1, x, y);
          cx = x;
          cy = y;
        }
        break;
      case 'T':
      case 't':
        while (moreNums() &&
            i + 1 < tokens.length &&
            tokens[i + 1].group(1) == null) {
          var x = num(), y = num();
          if (cmd == 't') {
            x += cx;
            y += cy;
          }
          path.quadraticBezierTo(cx, cy, x, y);
          cx = x;
          cy = y;
        }
        break;
      case 'A':
      case 'a':
        while (moreNums() &&
            i + 6 < tokens.length &&
            tokens[i + 6].group(1) == null) {
          final rx = num(), ry = num(), _ = num();
          final largeArc = num() != 0;
          final sweep = num() != 0;
          var x = num(), y = num();
          if (cmd == 'a') {
            x += cx;
            y += cy;
          }
          _arc(path, cx, cy, x, y, rx, ry, largeArc, sweep);
          cx = x;
          cy = y;
        }
        break;
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
        break;
      default:
        i++; // skip stray token
        break;
    }
  }
  return path;
}

void _lineTo(Path path, double x1, double y1, double x2, double y2) {
  // Browsers render near-zero-length segments (h.01) as dots when round
  // caps are set; nudge them so Skia does the same.
  final dx = x2 - x1, dy = y2 - y1;
  if (dx.abs() < .02 && dy.abs() < .02) {
    path.lineTo(x1 + .05, y1 + .05);
  } else {
    path.lineTo(x2, y2);
  }
}

/// SVG endpoint-parameterization arc -> Flutter addArc (axis-aligned arcs
/// are exact; rotated arcs approximate, which the icon set never uses).
void _arc(
  Path path,
  double x1,
  double y1,
  double x2,
  double y2,
  double rx,
  double ry,
  bool largeArc,
  bool sweep,
) {
  rx = rx.abs();
  ry = ry.abs();
  if (rx == 0 || ry == 0) {
    path.lineTo(x2, y2);
    return;
  }
  // F.6.5 center conversion (rotation ignored).
  final x1p = (x1 - x2) / 2;
  final y1p = (y1 - y2) / 2;
  final num_ = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  final den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  var coef = 0.0;
  if (den != 0) coef = math.sqrt(math.max(0, num_ / den));
  final sign = (largeArc != sweep) ? 1.0 : -1.0;
  final cxp = sign * coef * (rx * y1p / ry);
  final cyp = sign * coef * (-(ry * x1p / rx));
  final cx = cxp + (x1 + x2) / 2;
  final cy = cyp + (y1 + y2) / 2;

  final theta1 = _angle(1.0, 0.0, (x1p - cxp) / rx, (y1p - cyp) / ry);
  var delta = _angle(
    (x1p - cxp) / rx,
    (y1p - cyp) / ry,
    (-x1p - cxp) / rx,
    (-y1p - cyp) / ry,
  );
  if (!sweep && delta > 0) delta -= 2 * math.pi;
  if (sweep && delta < 0) delta += 2 * math.pi;

  if ((rx - ry).abs() < .001) {
    path.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: rx),
      theta1,
      delta,
    );
  } else {
    final steps = (delta.abs() / 1.5).ceil().clamp(1, 16);
    var prev = Offset(cx + rx * math.cos(theta1), cy + ry * math.sin(theta1));
    for (var k = 1; k <= steps; k++) {
      final t = theta1 + delta * k / steps;
      final p = Offset(cx + rx * math.cos(t), cy + ry * math.sin(t));
      path.moveTo(prev.dx, prev.dy);
      path.lineTo(p.dx, p.dy);
      prev = p;
    }
  }
}

double _angle(double ux, double uy, double vx, double vy) {
  final dot = ux * vx + uy * vy;
  final len = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
  if (len == 0) return 0;
  var a = math.acos((dot / len).clamp(-1.0, 1.0));
  if (ux * vy - uy * vx < 0) a = -a;
  return a;
}

final Map<String, Path> _pathCache = {};

/// Parses the inner SVG body (a sequence of <path>, <circle>, <rect>
/// elements) into one flat [Path] in 24x24 coordinates. Cached.
Path parseSvgBody(String body) {
  final cached = _pathCache[body];
  if (cached != null) return cached;
  final combined = Path();
  final tagRe = RegExp(r'<(path|circle|rect)\b([^>]*)/?>');
  final attrRe = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');
  for (final tag in tagRe.allMatches(body)) {
    final name = tag.group(1)!;
    final attrs = <String, String>{};
    for (final a in attrRe.allMatches(tag.group(2)!)) {
      attrs[a.group(1)!] = a.group(2)!;
    }
    double attr(String k, [double d = 0]) =>
        double.tryParse(attrs[k] ?? '') ?? d;
    switch (name) {
      case 'path':
        combined.addPath(parseSvgPathData(attrs['d'] ?? ''), Offset.zero);
        break;
      case 'circle':
        final cx = attr('cx'), cy = attr('cy'), r = attr('r');
        combined.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
        break;
      case 'rect':
        final x = attr('x'), y = attr('y');
        final w = attr('width'), h = attr('height');
        var rx = attr('rx');
        var ry = attr('ry');
        if (attrs.containsKey('rx') && !attrs.containsKey('ry')) ry = rx;
        if (attrs.containsKey('ry') && !attrs.containsKey('rx')) rx = ry;
        final r = math
            .min(math.min(rx, w / 2), h / 2)
            .clamp(0, double.infinity)
            .toDouble();
        combined.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
        );
        break;
    }
  }
  _pathCache[body] = combined;
  return combined;
}

/// Renders one of the original's SVG icons at [size] logical pixels.
class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.body, {
    super.key,
    this.size = 20,
    this.strokeWidth = 1.8,
    this.filled = false,
    this.color,
  });

  final String body;
  final double size;
  final double strokeWidth;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        DefaultTextStyle.of(context).style.color ??
        const Color(0xFFFFFFFF);
    return CustomPaint(
      size: Size.square(size),
      painter: _SvgIconPainter(parseSvgBody(body), c, strokeWidth, filled),
    );
  }
}

class _SvgIconPainter extends CustomPainter {
  _SvgIconPainter(this.path, this.color, this.strokeWidth, this.filled);

  final Path path;
  final Color color;
  final double strokeWidth;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (filled) {
      paint.style = PaintingStyle.fill;
    } else {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = strokeWidth;
      paint.strokeCap = StrokeCap.round;
      paint.strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgIconPainter old) =>
      old.path != path ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.filled != filled;
}

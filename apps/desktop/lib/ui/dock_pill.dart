// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the dock split (see dock.dart); do not import this file directly.
part of 'dock.dart';

class _Pill extends StatelessWidget {
  const _Pill({
    required this.controller,
    required this.viewportH,
    required this.bodyH,
  });

  final PanelController controller;
  final double viewportH;
  final double bodyH;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, __) {
        final py = controller.pillY.v;
        var ps = controller.pillS.v;
        if (ps < 0) ps = 0;
        if (ps < .001) return const SizedBox.shrink();
        final stretch = (controller.pillY.vel.abs() / 900).clamp(0.0, .45);
        final activeId = controller.activeToolId;
        final am = activeId != null
            ? 1 + controller.springsFor(activeId).mg.v * .16
            : 1.0;

        final sxP = ps * am * (1 - stretch * .35);
        final syP = ps * am * (1 + stretch);

        return Positioned(
          left: 17,
          top: -22,
          width: 44,
          height: 44,
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(0, py),
              child: Transform.scale(
                scaleX: sxP,
                scaleY: syP,
                child: Container(
                  decoration: BoxDecoration(
                    color: controller.palette.inv,
                    // Audit defect 12: the active marker was a circle while
                    // every inactive tile is a rounded square of the same
                    // size — one shape language now, radius 14.
                    borderRadius: BorderRadius.circular(14),
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

/// The tab silhouette: body with rounded left corners + concave quarter
/// circle flaps (size [flap]) at the edge side, drawn with a soft shadow —
/// exactly the shape produced by the CSS border-radius + radial-gradient
/// pseudo elements.
class _TabShapePainter extends CustomPainter {
  _TabShapePainter({
    required this.radius,
    required this.flap,
    required this.dir,
    required this.color,
    required this.shadow,
  });

  final double radius;
  final double flap;
  final double dir;
  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _silhouette(size, radius, flap.clamp(0.0, 44.0));

    // shadow: blurred silhouette offset away from the screen edge
    // (CSS: -18px 0 40px -20px rgba(0,0,0,.35))
    final shadowDir = dir > 0 ? -4.0 : 4.0;
    canvas.save();
    canvas.translate(shadowDir, 0);
    if (dir < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();

    canvas.save();
    if (dir < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  /// Outline of the tab for the right-edge case, built clockwise:
  /// rounded left corners, square edge-side corners, concave quarter-circle
  /// flaps above and below the edge side — the "liquid melt" shape.
  static Path _silhouette(Size size, double rr, double f) {
    final w = size.width;
    final h = size.height;
    final p = Path();
    // top-left rounded corner: (0, rr) -> (rr, 0)
    p.moveTo(0, rr);
    p.arcTo(
      Rect.fromCircle(center: Offset(rr, rr), radius: rr),
      math.pi,
      math.pi / 2,
      false,
    );
    // top edge to the flap tangent point
    p.lineTo(w - f, 0);
    // concave flap above the tab: (w - f, 0) -> (w, -f)
    if (f > 0) {
      p.arcTo(
        Rect.fromCircle(center: Offset(w - f, -f), radius: f),
        math.pi / 2,
        -math.pi / 2,
        false,
      );
    }
    // down the screen edge
    p.lineTo(w, h + f);
    // concave flap below the tab: (w, h + f) -> (w - f, h)
    if (f > 0) {
      p.arcTo(
        Rect.fromCircle(center: Offset(w - f, h + f), radius: f),
        0,
        -math.pi / 2,
        false,
      );
    }
    // bottom edge
    p.lineTo(rr, h);
    // bottom-left rounded corner: (rr, h) -> (0, h - rr)
    p.arcTo(
      Rect.fromCircle(center: Offset(rr, h - rr), radius: rr),
      math.pi / 2,
      math.pi / 2,
      false,
    );
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(_TabShapePainter old) =>
      old.radius != radius ||
      old.flap != flap ||
      old.color != color ||
      old.dir != dir ||
      old.shadow != shadow;
}

/// Decodes a data:image/png;base64 URI to an image widget (app icons).
class AppIconImage extends StatelessWidget {
  const AppIconImage({super.key, required this.dataUri});

  final String dataUri;
  static final Map<String, Uint8List> _cache = {};

  Uint8List? get bytes {
    final c = _cache[dataUri];
    if (c != null) return c;
    final comma = dataUri.indexOf(',');
    if (!dataUri.startsWith('data:') || comma < 0) return null;
    try {
      final b = _base64Decode(dataUri.substring(comma + 1));
      _cache[dataUri] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  static Uint8List _base64Decode(String s) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final clean = s.replaceAll(RegExp(r'\s'), '');
    final out = BytesBuilder();
    var bitBuf = 0, bits = 0;
    for (final ch in clean.codeUnits) {
      if (ch == 0x3D) break; // '='
      final v = chars.indexOf(String.fromCharCode(ch));
      if (v < 0) continue;
      bitBuf = (bitBuf << 6) | v;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((bitBuf >> bits) & 0xFF);
      }
    }
    return out.toBytes();
  }

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    if (b == null) {
      return const Text(
        '🚀',
        style: TextStyle(fontFamily: 'Segoe UI Emoji', fontSize: 19),
      );
    }
    return Image.memory(
      b,
      width: 26,
      height: 26,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

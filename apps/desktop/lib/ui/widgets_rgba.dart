// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the shared widget library split (see widgets.dart); do not import
// this file directly.
part of 'widgets.dart';

/// Renders raw RGBA bytes (clipboard images) scaled to fit [maxExtent].
class RgbaImage extends StatefulWidget {
  const RgbaImage({
    super.key,
    required this.rgba,
    required this.w,
    required this.h,
    this.maxExtent = 240,
  });

  final Uint8List rgba;
  final int w;
  final int h;
  final double maxExtent;

  @override
  State<RgbaImage> createState() => _RgbaImageState();
}

class _RgbaImageState extends State<RgbaImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(RgbaImage old) {
    super.didUpdateWidget(old);
    if (!identical(old.rgba, widget.rgba)) _decode();
  }

  Future<void> _decode() async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(widget.rgba);
      final desc = ui.ImageDescriptor.raw(
        buffer,
        width: widget.w,
        height: widget.h,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _image = frame.image);
    } catch (_) {}
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) {
      return SizedBox(
        width: widget.maxExtent / 3,
        height: widget.maxExtent / 3,
      );
    }
    final s = widget.maxExtent / math.max(img.width, img.height);
    final size = Size(img.width * s, img.height * s);
    return CustomPaint(size: size, painter: _RgbaPainter(img, size));
  }
}

class _RgbaPainter extends CustomPainter {
  _RgbaPainter(this.image, this.size);

  final ui.Image image;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_RgbaPainter old) => old.image != image;
}

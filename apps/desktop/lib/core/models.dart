import 'dart:typed_data';

/// A pinned app / shortcut / folder, persisted in settings.json.
class AppItem {
  AppItem({
    required this.id,
    required this.name,
    required this.path,
    this.icon,
  });

  final String id;
  String name;
  final String path;

  /// PNG data URI produced by the native icon extractor (may arrive later).
  String? icon;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    if (icon != null) 'icon': icon,
  };

  static AppItem fromJson(Map<String, dynamic> j) => AppItem(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    path: j['path'] as String? ?? '',
    icon: j['icon'] as String?,
  );
}

/// A clipboard history entry: either plain text or an image.
class ClipEntry {
  ClipEntry.text(this.text, {required this.time})
    : image = null,
      pinned = false;

  ClipEntry.image(this.image, {required this.time, this.pinned = false})
    : text = null;

  final String? text;
  final ClipImage? image;
  final DateTime time;
  bool pinned;

  bool get isImage => image != null;
}

/// An image on the clipboard history. [rgba] holds the (downscaled) pixels;
/// the id matches the original's content hash so pinned files stay
/// compatible between the two apps.
class ClipImage {
  ClipImage({
    required this.id,
    required this.w,
    required this.h,
    required this.rgba,
  });

  final String id;
  final int w;
  final int h;
  final Uint8List rgba;
}

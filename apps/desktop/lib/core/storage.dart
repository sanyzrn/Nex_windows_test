import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/models.dart';

/// Shell preferences and pinned clipboard previews in NexDesktopShell.
/// Domain notes are exclusively stored through nex_data.
class Storage {
  Storage();

  Directory get dir {
    final base =
        Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? '.';
    final d = Directory('$base${Platform.pathSeparator}NexDesktopShell');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  File get _settingsFile =>
      File('${dir.path}${Platform.pathSeparator}settings.json');
  Directory get _pinsDir {
    final d = Directory('${dir.path}${Platform.pathSeparator}pinned');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Map<String, dynamic> loadSettings() {
    try {
      final text = _settingsFile.readAsStringSync();
      final v = jsonDecode(text);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return <String, dynamic>{};
  }

  void saveSettings(Map<String, dynamic> settings) {
    try {
      _settingsFile.writeAsStringSync(jsonEncode(settings));
    } catch (_) {}
  }

  /// Restores pinned clipboard images (same .bin format as the original:
  /// 4-byte LE width, 4-byte LE height, then RGBA pixels).
  List<ClipEntry> loadPinnedImages() {
    final out = <ClipEntry>[];
    final entries = _pinsDir.listSync().take(12).toList();
    for (final entry in entries) {
      if (entry is! File) continue;
      final id = entry.uri.pathSegments.last.split('.').first;
      try {
        final body = entry.readAsBytesSync();
        if (body.length < 8) continue;
        final view = ByteData.sublistView(body);
        final w = view.getUint32(0, Endian.little);
        final h = view.getUint32(4, Endian.little);
        final px = body.sublist(8);
        if (w == 0 || h == 0 || px.length != w * h * 4) continue;
        out.add(
          ClipEntry.image(
            ClipImage(id: id, w: w, h: h, rgba: px),
            time: DateTime.now(),
            pinned: true,
          ),
        );
      } catch (_) {}
    }
    return out;
  }

  void pinImage(ClipImage img) {
    final body = BytesBuilder();
    final head = ByteData(8);
    head.setUint32(0, img.w, Endian.little);
    head.setUint32(4, img.h, Endian.little);
    body.add(head.buffer.asUint8List());
    body.add(img.rgba);
    try {
      File(
        '${_pinsDir.path}${Platform.pathSeparator}${img.id}.bin',
      ).writeAsBytesSync(body.toBytes());
    } catch (_) {}
  }

  void unpinImage(String id) {
    try {
      File('${_pinsDir.path}${Platform.pathSeparator}$id.bin').deleteSync();
    } catch (_) {}
  }

  /// Human-visible name for a file path, port of `display_name()`.
  static String displayName(String path) {
    var p = path;
    while (p.endsWith('/') || p.endsWith('\\')) {
      p = p.substring(0, p.length - 1);
    }
    final slash = p.lastIndexOf(RegExp(r'[/\\]'));
    var stem = slash >= 0 ? p.substring(slash + 1) : p;
    final dot = stem.lastIndexOf('.');
    if (dot > 0) stem = stem.substring(0, dot);
    return stem.isEmpty ? path : stem;
  }
}

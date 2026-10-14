import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'clipboard_store.dart';
import 'models.dart';

class ClipboardState extends ChangeNotifier {
  List<ClipEntry> _recent = [], _favorites = [];
  final _known = <String>{};
  final _removed = <String>{}, _unpinned = <String>{};
  List<ClipEntry> _legacy = [];
  bool _loaded = false, _clearOnRecovery = false;
  ClipboardStore? _store;
  String? _path;
  Future<void> _tail = Future.value();
  bool _disposed = false, _closed = false;
  int _saving = 0;
  bool get saving => _saving > 0;
  String? error;
  List<ClipEntry> get recent => List.unmodifiable(_recent);
  List<ClipEntry> get favorites => List.unmodifiable(_favorites);
  List<ClipEntry> get entries {
    final keys = _recent.map(clipIdentity).toSet();
    return [
      ..._recent,
      ..._favorites.where((e) => !keys.contains(clipIdentity(e))),
    ];
  }

  List<String> get pinnedTexts =>
      _favorites.where((e) => !e.isImage).map((e) => e.text!).toList();

  Future<void> initialize(Directory directory, List<ClipEntry> legacy) async {
    await directory.create(recursive: true);
    _path = '${directory.path}${Platform.pathSeparator}clipboard.sqlite';
    _legacy = legacy;
    try {
      _store = await ClipboardStore.open(_path!);
      final snapshot = await _store!.load(legacy);
      _recent = snapshot.recent.take(50).toList();
      _favorites = snapshot.favorites;
      _known.addAll(entries.map(clipIdentity));
      _loaded = true;
      error = null;
    } catch (failure) {
      _favorites = legacy;
      error = '$failure';
      await _store?.close().catchError((Object _) {});
      _store = null;
    }
    _notify();
  }

  /// Fixtures can seed without enabling filesystem persistence.
  void seed(List<ClipEntry> entries) {
    _recent = entries.take(50).toList();
    _favorites = entries.where((e) => e.pinned).toList();
    _markPins();
  }

  void add(ClipEntry entry) {
    if (_closed) return;
    if (!entry.isImage && entry.text!.trim().isEmpty) return;
    final key = clipIdentity(entry);
    if (!_loaded) _removed.remove(key);
    _recent = [
      entry,
      ..._recent.where((e) => clipIdentity(e) != key),
    ].take(50).toList();
    final pin = _favorites.indexWhere((e) => clipIdentity(e) == key);
    if (pin >= 0) _favorites[pin] = entry;
    _markPins();
    _persist();
    _notify();
  }

  void togglePin(ClipEntry entry) {
    final key = clipIdentity(entry);
    final existed = _favorites.any((e) => clipIdentity(e) == key);
    if (!_loaded) {
      existed ? _unpinned.add(key) : _unpinned.remove(key);
    }
    _favorites.removeWhere((e) => clipIdentity(e) == key);
    if (!existed) _favorites.insert(0, entry);
    // Preserve the existing 30-text favorites limit; image pins are separate.
    var count = 0;
    _favorites.removeWhere((e) => !e.isImage && ++count > 30);
    _markPins();
    _persist();
    _notify();
  }

  void remove(ClipEntry entry) {
    final key = clipIdentity(entry);
    if (!_loaded) {
      _removed.add(key);
      _unpinned.add(key);
    }
    _recent.removeWhere((e) => clipIdentity(e) == key);
    _favorites.removeWhere((e) => clipIdentity(e) == key);
    _markPins();
    _persist();
    _notify();
  }

  void clear() {
    if (!_loaded) _clearOnRecovery = true;
    _recent.removeWhere((e) => !e.pinned);
    _persist();
    _notify();
  }

  void _markPins() {
    final keys = _favorites.map(clipIdentity).toSet();
    for (final e in entries) {
      e.pinned = keys.contains(clipIdentity(e));
    }
  }

  void _persist() {
    if (_path == null || _closed) return;
    final snapshot = ClipboardSnapshot(List.of(_recent), List.of(_favorites));
    _saving++;
    _tail = _tail.then((_) async {
      try {
        if (!_loaded) {
          throw StateError('Unreadable clipboard history; retry loading first');
        }
        await _store!.save(snapshot, _known);
        _known
          ..clear()
          ..addAll(
            [...snapshot.recent, ...snapshot.favorites].map(clipIdentity),
          );
        error = null;
      } catch (failure) {
        error = '$failure';
        _known.clear();
      } finally {
        _saving--;
        _notify();
      }
    });
  }

  Future<void> retry() async {
    await _tail;
    if (!_loaded && _path != null) {
      try {
        _store ??= await ClipboardStore.open(_path!);
        final restored = await _store!.load(_legacy);
        List<ClipEntry> unique(Iterable<ClipEntry> entries) {
          final seen = <String>{};
          return entries.where((e) => seen.add(clipIdentity(e))).toList();
        }

        _recent = unique([
          ..._recent,
          ...restored.recent.where(
            (e) =>
                !_removed.contains(clipIdentity(e)) &&
                (!_clearOnRecovery || e.pinned),
          ),
        ]).take(50).toList();
        _favorites = unique([
          ..._favorites,
          ...restored.favorites.where(
            (e) => !_unpinned.contains(clipIdentity(e)),
          ),
        ]);
        _known.addAll(
          [...restored.recent, ...restored.favorites].map(clipIdentity),
        );
        _loaded = true;
        error = null;
        _markPins();
      } catch (failure) {
        error = '$failure';
        _notify();
        return;
      }
    }
    _persist();
    _notify();
    await _tail;
  }

  Future<void> get flushed => _tail;

  Future<void> close({bool requireSaved = false}) async {
    if (_closed) return;
    if (requireSaved && error != null) await retry();
    while (_saving > 0) {
      await _tail;
    }
    if (requireSaved && error != null) {
      throw StateError('Clipboard not persisted');
    }
    _closed = true;
    await _store?.close();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}

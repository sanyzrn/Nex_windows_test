import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/core/clipboard_state.dart';
import 'package:nex_desktop/core/clipboard_store.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/models.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/core/storage.dart';

ClipEntry text(int i) => ClipEntry.text(
  'متن $i\nExact whitespace  🥑',
  time: DateTime.fromMillisecondsSinceEpoch(1791970000000 + i),
);
ClipEntry image(int i) => ClipEntry.image(
  ClipImage(
    id: 'image-$i',
    w: 2,
    h: 2,
    rgba: Uint8List.fromList(List.generate(16, (n) => n + i)),
  ),
  time: text(i).time,
);

Future<ClipboardState> open(
  Directory root, [
  List<ClipEntry> legacy = const [],
]) async {
  final c = ClipboardState();
  await c.initialize(root, legacy);
  expect(c.error, isNull);
  return c;
}

Future<void> close(ClipboardState c) async {
  await c.close(requireSaved: true);
  c.dispose();
}

class _Native extends NativeHost {
  int quits = 0;
  @override
  Future<void> quit() async {
    quits++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('nex-clipboard-test-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'last 50 unique mixed entries persist with exact bytes, order and time',
    () async {
      final c = await open(root);
      for (var i = 0; i < 60; i++) {
        c.add(i % 10 == 0 ? image(i) : text(i));
      }
      await close(c);
      final next = await open(root);
      expect(next.recent.length, 50);
      expect(next.recent.first.text, text(59).text);
      expect(next.recent.last.image!.id, 'image-10');
      final photo = next.recent.firstWhere((e) => e.image?.id == 'image-50');
      expect(photo.image!.rgba, image(50).image!.rgba);
      expect(photo.time, image(50).time);
      next.add(text(18));
      await close(next);
      final again = await open(root);
      expect(again.recent.length, 50);
      expect(again.recent.first.text, text(18).text);
      expect(again.recent.where((e) => e.text == text(18).text).length, 1);
      await close(again);
    },
  );

  test(
    'old text/image favorites survive eviction, recopy, clear and restart',
    () async {
      final c = await open(root);
      c.add(text(0));
      c.togglePin(c.recent.first);
      c.add(image(1));
      c.togglePin(c.recent.first);
      for (var i = 2; i < 65; i++) {
        c.add(text(i));
      }
      await close(c);
      final next = await open(root);
      expect(next.recent.length, 50);
      expect(next.entries.length, 52);
      expect(next.favorites.length, 2);
      expect(next.favorites.every((e) => e.pinned), isTrue);
      next.add(image(1));
      expect(next.recent.first.pinned, isTrue);
      next.clear();
      await close(next);
      final again = await open(root);
      expect(again.entries.length, 2);
      expect(again.entries.every((e) => e.pinned), isTrue);
      again.remove(again.favorites.first);
      await close(again);
      final last = await open(root);
      expect(last.entries.length, 1);
      await close(last);
    },
  );

  test(
    'legacy pins migrate once and cannot resurrect after deletion',
    () async {
      final old = [text(0)..pinned = true, image(1)..pinned = true];
      final c = await open(root, old);
      expect(c.recent, isEmpty);
      expect(c.favorites.length, 2);
      c.remove(c.favorites.first);
      c.remove(c.favorites.first);
      await close(c);
      final next = await open(root, old);
      expect(next.entries, isEmpty);
      await close(next);
    },
  );

  test(
    'failed snapshot rolls back rather than erasing committed history',
    () async {
      final store = await ClipboardStore.open('${root.path}/clipboard.sqlite');
      await store.load([]);
      await store.save(ClipboardSnapshot([text(1)], []), {});
      await expectLater(
        store.save(ClipboardSnapshot([text(2)], []), {clipIdentity(text(2))}),
        throwsStateError,
      );
      final saved = await store.load([]);
      expect(saved.recent.single.text, text(1).text);
      await store.close();
    },
  );

  test(
    'unreadable disk history remains untouched and reports failed saving',
    () async {
      final bad = File('${root.path}/clipboard.sqlite');
      final bytes = List<int>.filled(256, 71);
      await bad.writeAsBytes(bytes);
      final c = ClipboardState();
      await c.initialize(root, []);
      expect(c.error, isNotNull);
      c.add(text(1));
      await c.flushed;
      await c.retry();
      expect(c.error, isNotNull);
      expect(await bad.readAsBytes(), bytes);
      await c.close();
      c.dispose();
    },
  );

  test(
    'controller restores history before events and drains it before quit',
    () async {
      final native = _Native();
      final c = PanelController(
        nativeHost: native,
        storage: Storage(directory: root),
      );
      await c.bootstrap(useNative: false);
      for (var i = 0; i < 55; i++) {
        c.addClip('item-$i');
      }
      c.beforeShutdown = () async => throw StateError('Other shutdown failed');
      await c.quit();
      expect(native.quits, 0);
      c.addClip('after failed shutdown');
      c.beforeShutdown = null;
      await c.quit();
      expect(native.quits, 1);
      c.dispose();
      final next = PanelController(
        nativeHost: _Native(),
        storage: Storage(directory: root),
      );
      await next.bootstrap(useNative: false);
      expect(next.clipboard.recent.length, 50);
      expect(next.clips.first.text, 'after failed shutdown');
      expect(next.lastClip, 'after failed shutdown');
      await next.quit();
      next.dispose();
    },
  );
}

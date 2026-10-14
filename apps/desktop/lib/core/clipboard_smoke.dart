import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'clipboard_state.dart';
import 'models.dart';
import 'native.dart';

/// Isolated crash/restart verification. The explicit directory contains only
/// diagnostic entries; this never reads or writes the system clipboard.
Future<void> clipboardSmoke(List<String> args) async {
  final state = ClipboardState();
  final result = <String, dynamic>{};
  try {
    await state.initialize(Directory(args[3]), []);
    if (state.error != null) throw StateError(state.error!);
    if (args[2] == 'write') {
      for (var i = 0; i < 60; i++) {
        final at = DateTime.fromMillisecondsSinceEpoch(1791970000000 + i);
        final content = 'probe-$i فارسی  🥑';
        state.add(
          i % 10 == 0
              ? ClipEntry.image(
                  ClipImage(
                    id: 'probe-$i',
                    w: 2,
                    h: 2,
                    rgba: Uint8List.fromList(List.generate(16, (n) => i + n)),
                  ),
                  time: at,
                )
              : ClipEntry.text(content, time: at),
        );
        if (i == 0) state.togglePin(state.recent.first);
      }
      await state.flushed;
      if (state.error != null) throw StateError(state.error!);
      result['committed'] = true;
    } else if (args[2] == 'read') {
      final photo = state.recent.firstWhere((e) => e.image?.id == 'probe-50');
      result['count'] = state.recent.length;
      result['latest'] = state.recent.first.text;
      result['imageBytesPreserved'] = listBytesEqual(
        photo.image!.rgba,
        Uint8List.fromList(List.generate(16, (n) => 50 + n)),
      );
      result['timePreserved'] =
          photo.time.millisecondsSinceEpoch == 1791970000050;
      result['oldPinPreserved'] = state.favorites.single.image!.id == 'probe-0';
      result['passed'] =
          result['count'] == 50 &&
          result['latest'] == 'probe-59 فارسی  🥑' &&
          result['imageBytesPreserved'] == true &&
          result['timePreserved'] == true &&
          result['oldPinPreserved'] == true;
    } else {
      throw ArgumentError('Unknown clipboard probe mode');
    }
  } catch (error) {
    result['passed'] = false;
    result['error'] = '$error';
  }
  final output = File(args[1]);
  await output.parent.create(recursive: true);
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert(result),
  );
  if (result['committed'] == true) {
    // The supervising process terminates this writer without close/checkpoint.
    await Completer<void>().future;
  }
  await state.close();
  state.dispose();
  await WinNativeHost().quit();
}

bool listBytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

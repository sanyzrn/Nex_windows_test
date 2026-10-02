import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:just_audio/just_audio.dart';
import 'package:nex_core/nex_core.dart';
import '../core/native.dart';
import 'features.dart';
import 'store.dart';

/// An opt-in CLI integration check of real Windows codecs and the Nex media
/// ingress, using only supplied QA fixtures and an isolated temporary store.
/// This is not counted as mouse/file-dialog or microphone coverage.
Future<void> mediaSmoke(List<String> arguments) async {
  final root = await Directory.systemTemp.createTemp('nex-media-smoke-');
  final store = await DesktopStore.open(root.path, 'media-smoke');
  final features = NexFeatures(store);
  final player = AudioPlayer(handleAudioSessionActivation: false);
  final result = <String, Object?>{};
  try {
    await features.importPaths(arguments.sublist(1, 3));
    if (features.error != null) throw StateError(features.error!);
    final notes = await store.call<List<Note>>('timeline');
    final photo = notes.singleWhere((n) => n.type == NoteType.photo);
    final voice = notes.singleWhere((n) => n.type == NoteType.voice);
    final codec = await ui.instantiateImageCodec(
      await File(photo.mediaUri!).readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    result['imageWidth'] = frame.image.width;
    result['imageHeight'] = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    var duration = await player
        .setFilePath(voice.mediaUri!)
        .timeout(const Duration(seconds: 10));
    // The Windows backend acknowledges load/play before Media Foundation has
    // opened the source or finished playback. Observe its asynchronous events.
    duration ??= await player.durationStream
        .firstWhere((value) => value != null && value > Duration.zero)
        .timeout(const Duration(seconds: 10));
    result['durationMs'] = duration?.inMilliseconds;
    final completed = player.processingStateStream
        .firstWhere((value) => value == ProcessingState.completed)
        .timeout(const Duration(seconds: 10));
    await player.play().timeout(const Duration(seconds: 10));
    await completed;
    result['processingState'] = player.processingState.name;
    result['positionMs'] = player.position.inMilliseconds;
    result['notesImported'] = notes.length;
    result['pass'] =
        notes.length == 2 &&
        duration != null &&
        duration.inMilliseconds > 0 &&
        player.processingState == ProcessingState.completed;
  } catch (e) {
    result['pass'] = false;
    result['error'] = e.toString();
    result['processingState'] = player.processingState.name;
    result['positionMs'] = player.position.inMilliseconds;
    result['playing'] = player.playing;
  } finally {
    await player.dispose();
    await features.close();
    await File(
      arguments[3],
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
    await root.delete(recursive: true);
    await WinNativeHost().quit();
  }
}

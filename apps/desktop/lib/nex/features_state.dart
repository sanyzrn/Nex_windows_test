// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// State management for Nex capture, library, and media sessions.
/// Owns [NexFeatures], [NexScope], [NexPanelScope], and shared note type helpers.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

import '../core/models.dart' show ClipImage;
import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import 'store.dart';

class NexFeatures extends ChangeNotifier {
  NexFeatures(this.store, {this.pickFiles}) : session = CaptureSession(store);
  final DesktopStore store;
  final Future<List<XFile>> Function(List<XTypeGroup>)? pickFiles;
  CaptureSession session;
  final composer = TextEditingController();
  final focus = FocusNode();
  bool checklist = false;
  String? error;
  int libraryRevision = 0;
  int importedCount = 0;
  bool importing = false, recordingBusy = false;
  VoidCallback? _recordingRelease;
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  DateTime? recordingAt;
  String? _recordingPath;
  final _pending = <Future<void>>{};

  void notify() => notifyListeners();
  Future<void> guard(
    Future<void> Function() action, {
    bool rethrowError = false,
  }) {
    late final Future<void> task;
    task = _guard(
      action,
      rethrowError,
    ).whenComplete(() => _pending.remove(task));
    _pending.add(task);
    return task;
  }

  Future<void> _guard(Future<void> Function() action, bool rethrowError) async {
    try {
      await action();
      error = null;
      libraryRevision++;
    } catch (e) {
      error = e.toString();
      if (rethrowError) rethrow;
    } finally {
      notifyListeners();
    }
  }

  void write(String text) {
    // No debounce. Session owns the FIFO, so disposing a panel loses nothing.
    unawaited(guard(() => session.write(text, checklist: checklist)));
  }

  Future<void> fresh() async {
    // A failed write on the previous session must not break the next one;
    // drain and move on with a visible error instead of an async crash.
    try {
      await session.flushed;
    } catch (e) {
      error = e.toString();
    }
    session = CaptureSession(store);
    composer.clear();
    notifyListeners();
    // The hotkey can arrive before the capture field's first layout. Opening
    // its input connection sooner reads an unlaid-out RenderEditable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focus.context != null) focus.requestFocus();
    });
  }

  Future<void> importPaths(
    List<String> paths, {
    bool rethrowError = false,
  }) async {
    if (paths.isEmpty || importing) return;
    importing = true;
    importedCount = 0;
    notify();
    try {
      await guard(() async {
        for (final path in paths) {
          if (!await File(path).exists()) {
            throw FileSystemException('File unavailable', path);
          }
          await store.call<Note>('media', {'path': path});
          importedCount++;
        }
      }, rethrowError: rethrowError);
    } finally {
      importing = false;
      notify();
    }
  }

  Future<void> pasteImage(ClipImage image, {bool rethrowError = false}) =>
      guard(() async {
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          image.rgba,
          image.w,
          image.h,
          ui.PixelFormat.rgba8888,
          completer.complete,
        );
        final decoded = await completer.future;
        final bytes = await decoded.toByteData(format: ui.ImageByteFormat.png);
        decoded.dispose();
        if (bytes == null) throw StateError('PNG encoding failed');
        final temp = await Directory.systemTemp.createTemp('nex-clipboard-');
        try {
          final file = File(p.join(temp.path, 'clipboard.png'));
          await file.writeAsBytes(bytes.buffer.asUint8List());
          await store.call<Note>('media', {'path': file.path});
          importedCount = 1;
        } finally {
          await temp.delete(recursive: true);
        }
      }, rethrowError: rethrowError);
  Future<void> record([PanelController? panel]) async {
    if (recordingBusy) return;
    recordingBusy = true;
    notify();
    try {
      await guard(() async {
        if (recordingAt == null) {
          if (!await recorder.hasPermission()) {
            throw StateError('Microphone permission denied');
          }
          _recordingPath = p.join(
            Directory.systemTemp.path,
            'nex-${newUuidV7()}.wav',
          );
          await recorder.start(
            const RecordConfig(encoder: AudioEncoder.wav),
            path: _recordingPath!,
          );
          recordingAt = DateTime.now();
          _recordingRelease = panel?.holdOpen();
        } else {
          final path = await recorder.stop() ?? _recordingPath;
          final duration = DateTime.now()
              .difference(recordingAt!)
              .inMilliseconds;
          recordingAt = null;
          _recordingRelease?.call();
          _recordingRelease = null;
          if (path != null) {
            var saved = false;
            try {
              await store.call<Note>('media', {
                'path': path,
                'duration': duration,
              });
              importedCount = 1;
              saved = true;
            } finally {
              if (saved) {
                try {
                  if (await File(path).exists()) await File(path).delete();
                } catch (_) {}
              }
              // On failure the recording intentionally survives at [path]
              // so it can be recovered; the error below includes the path.
            }
          }
        }
      });
    } finally {
      recordingBusy = false;
      notify();
    }
  }

  Future<void> close() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
    if (recordingAt != null) await record();
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
    // A failed attachment/permission request must not prevent graceful exit.
    await session.flushed;
    await store.close();
    await _recorder?.dispose();
    composer.dispose();
    focus.dispose();
  }
}

Future<T> withPanelHold<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final release = NexPanelScope.maybeOf(context)?.holdOpen();
  try {
    return await action();
  } finally {
    release?.call();
  }
}

class NexScope extends InheritedNotifier<NexFeatures> {
  const NexScope({
    super.key,
    required NexFeatures features,
    required super.child,
  }) : super(notifier: features);
  static NexFeatures of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexScope>()!.notifier!;
  static NexFeatures? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexScope>()?.notifier;
}

class NexPanelScope extends InheritedWidget {
  const NexPanelScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final PanelController controller;
  static PanelController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NexPanelScope>()?.controller;
  @override
  bool updateShouldNotify(NexPanelScope oldWidget) =>
      oldWidget.controller != controller;
}

String noteTypeLabel(AppLocalizations l, NoteType type) => switch (type) {
  NoteType.text => l.text,
  NoteType.voice => l.voice,
  NoteType.photo => l.photo,
  NoteType.file => l.file,
  NoteType.checklist => l.checklist,
  NoteType.link => l.link,
};

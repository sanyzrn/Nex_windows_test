// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Immediate capture view for notes, checklists, and media.
/// Owns [NexCaptureView] and capture action buttons.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nex_ui/nex_ui.dart';

import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';
part 'capture_wide.dart';

abstract class CaptureViewBase extends StatelessWidget {
  const CaptureViewBase({super.key, this.pickFiles, this.compact = true});

  final Future<List<XFile>> Function(List<XTypeGroup>)? pickFiles;

  /// Compact layout fits the 360px edge flyout; the wide layout fills the
  /// desktop window's content area with a proper editor.
  final bool compact;

  /// Desktop window layout builder; implemented in capture_wide.dart.
  Widget _buildWide(
    BuildContext context,
    NexFeatures f,
    AppLocalizations l,
    PanelController? c,
  );

  Future<void> _choose(
    BuildContext context,
    NexFeatures features, [
    List<XTypeGroup> groups = const [],
  ]) {
    features.importedCount = 0;
    features.notify();
    return withPanelHold(
      context,
      () => features.guard(() async {
        final picker = pickFiles ?? features.pickFiles;
        final files =
            await (picker?.call(groups) ??
                openFiles(acceptedTypeGroups: groups));
        await features.importPaths(
          files.map((e) => e.path).toList(),
          rethrowError: true,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = NexScope.of(context);
    final l = AppLocalizations.of(context)!;
    final c = context
        .dependOnInheritedWidgetOfExactType<NexPanelScope>()
        ?.controller;
    if (!compact) return _buildWide(context, f, l, c);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.savedLocally,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: l.newNote,
                onPressed: () => f.fresh(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): () async {
                final text = await Clipboard.getData(Clipboard.kTextPlain);
                if (text?.text?.isNotEmpty == true) {
                  final selection = f.composer.selection;
                  final value = f.composer.text;
                  final start = selection.isValid
                      ? selection.start
                      : value.length;
                  final end = selection.isValid ? selection.end : value.length;
                  f.composer.value = TextEditingValue(
                    text: value.replaceRange(start, end, text!.text!),
                    selection: TextSelection.collapsed(
                      offset: start + text.text!.length,
                    ),
                  );
                  f.write(f.composer.text);
                } else if (c != null) {
                  await f.guard(() async {
                    final image = await c.native.currentClipboardImage();
                    if (image != null) {
                      await f.pasteImage(image, rethrowError: true);
                    }
                  });
                }
              },
            },
            child: Focus(
              onFocusChange: (focused) =>
                  focused ? c?.focusGained() : c?.focusLost(),
              child: TextField(
                key: const ValueKey('capture-field'),
                controller: f.composer,
                focusNode: f.focus,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                textDirection: nexDirectionOf(f.composer.text),
                decoration: InputDecoration(
                  hintText: l.captureHint,
                  filled: true,
                ),
                onChanged: f.write,
              ),
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: f.checklist,
                onChanged: f.session.id == null
                    ? (v) {
                        f.checklist = v!;
                        f.notify();
                      }
                    : null,
              ),
              Text(l.checklist),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CaptureAction(
                label: l.pasteText,
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clip?.text?.isNotEmpty == true) {
                    await f.fresh();
                    f.composer.text = clip!.text!;
                    f.write(clip.text!);
                  }
                },
                icon: Icons.content_paste_rounded,
              ),
              _CaptureAction(
                label: l.addImage,
                onPressed: f.importing
                    ? null
                    : () => _choose(context, f, [
                        XTypeGroup(
                          label: l.photo,
                          extensions: const [
                            'png',
                            'jpg',
                            'jpeg',
                            'webp',
                            'gif',
                            'bmp',
                          ],
                        ),
                      ]),
                icon: Icons.add_photo_alternate_outlined,
              ),
              _CaptureAction(
                label: l.attach,
                onPressed: f.importing ? null : () => _choose(context, f),
                icon: Icons.attach_file_rounded,
              ),
              _CaptureAction(
                label: l.addAudio,
                onPressed: f.importing
                    ? null
                    : () => _choose(context, f, [
                        XTypeGroup(
                          label: l.voice,
                          extensions: const [
                            'wav',
                            'mp3',
                            'm4a',
                            'aac',
                            'ogg',
                            'opus',
                            'flac',
                            'wma',
                          ],
                        ),
                      ]),
                icon: Icons.audio_file_outlined,
              ),
              _CaptureAction(
                label: f.recordingAt == null ? l.record : l.stop,
                onPressed: f.recordingBusy ? null : () => f.record(c),
                icon: f.recordingAt == null
                    ? Icons.mic_none_rounded
                    : Icons.stop_circle_outlined,
              ),
              if (c != null)
                _CaptureAction(
                  label: l.pastePhoto,
                  onPressed: () => f.guard(() async {
                    final image = await c.native.currentClipboardImage();
                    if (image == null) throw StateError(l.noClipboardImage);
                    await f.pasteImage(image, rethrowError: true);
                  }),
                  icon: Icons.content_paste_go_rounded,
                ),
            ],
          ),
          if (f.importing || f.recordingBusy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (f.recordingAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l.recording,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (f.importedCount > 0 && !f.importing)
            TextButton.icon(
              onPressed: c == null ? null : () => c.openWidget('timeline'),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(l.mediaAdded(f.importedCount)),
            ),
          if (f.error != null)
            Text(
              '${l.failed}: ${f.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Future<void> _paste(NexFeatures f, PanelController? c) async {
    final text = await Clipboard.getData(Clipboard.kTextPlain);
    if (text?.text?.isNotEmpty == true) {
      final selection = f.composer.selection;
      final value = f.composer.text;
      final start = selection.isValid ? selection.start : value.length;
      final end = selection.isValid ? selection.end : value.length;
      f.composer.value = TextEditingValue(
        text: value.replaceRange(start, end, text!.text!),
        selection: TextSelection.collapsed(offset: start + text.text!.length),
      );
      f.write(f.composer.text);
    } else if (c != null) {
      await f.guard(() async {
        final image = await c.native.currentClipboardImage();
        if (image != null) {
          await f.pasteImage(image, rethrowError: true);
        }
      });
    }
  }
}

/// The composed capture view. Same library, so the mixin and this class
/// share every private member.
class NexCaptureView = CaptureViewBase with CaptureWide;

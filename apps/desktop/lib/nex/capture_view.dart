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
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';

class NexCaptureView extends StatelessWidget {
  const NexCaptureView({super.key, this.pickFiles, this.compact = true});
  final Future<List<XFile>> Function(List<XTypeGroup>)? pickFiles;

  /// Compact layout fits the 360px edge flyout; the wide layout fills the
  /// desktop window's content area with a proper editor.
  final bool compact;
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

  /// Desktop window layout: a comfortable bounded editor, a checklist
  /// switch, one action row and honest status lines.
  Widget _buildWide(
    BuildContext context,
    NexFeatures f,
    AppLocalizations l,
    PanelController? c,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final editor = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
            _paste(f, c),
      },
      child: Focus(
        onFocusChange: (focused) => focused ? c?.focusGained() : c?.focusLost(),
        child: TextField(
          key: const ValueKey('capture-field'),
          controller: f.composer,
          focusNode: f.focus,
          autofocus: true,
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          textDirection: nexDirectionOf(f.composer.text),
          decoration: InputDecoration(
            hintMaxLines: 1,
            hintText: l.captureHint,
            filled: true,
            fillColor: scheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
          onChanged: f.write,
        ),
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                offset: const Offset(0, 6),
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981), // Emerald green active dot
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.savedLocally,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(l.newNote),
                    onPressed: () => f.fresh(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 180),
                  child: editor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Switch(
                    value: f.checklist,
                    onChanged: f.session.id == null
                        ? (v) {
                            f.checklist = v;
                            f.notify();
                          }
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.checklist,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: f.composer,
                    builder: (context, _) {
                      final text = f.composer.text;
                      final words = text.trim().isEmpty
                          ? 0
                          : text.trim().split(RegExp(r'\s+')).length;
                      final chars = text.length;
                      final isFa =
                          Localizations.localeOf(context).languageCode == 'fa';
                      final countText = isFa
                          ? nexDigits('$words کلمه • $chars نویسه', persian: true)
                          : '$words words • $chars chars';
                      return Text(
                        countText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: c == null ? null : () => c.openWidget('timeline'),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(l.mediaAdded(f.importedCount)),
              ),
            ),
          ),
        if (f.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${l.failed}: ${f.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
  ),
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

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 152,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.start,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

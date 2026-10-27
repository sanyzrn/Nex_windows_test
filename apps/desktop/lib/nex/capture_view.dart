// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Immediate capture view for notes, checklists, and media.
/// Owns [NexCaptureView] and capture action buttons.
library;

import '../l10n/desktop_format.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'desktop_editing_direction.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_core/nex_core.dart' show nexDigits;

import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import '../ui/desktop_accessibility.dart';
import 'features_state.dart';
part 'capture_wide.dart';

abstract class CaptureViewBase extends StatelessWidget {
  const CaptureViewBase({
    super.key,
    this.pickFiles,
    this.compact = true,
    this.embedded = false,
  });

  final Future<List<XFile>> Function(List<XTypeGroup>)? pickFiles;

  /// Compact layout fits the 360px edge flyout; the wide layout fills the
  /// desktop window's content area with a proper editor.
  final bool compact;
  final bool embedded;

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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  f.saving ? l.saving : l.savedLocally,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: l.newNote,
                onPressed: () => f.fresh(),
                icon: const Icon(Icons.add, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyV,
                control: true,
              ): () =>
                  unawaited(_pasteIntoComposer(context, f, c)),
            },
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onFocusChange: (focused) =>
                  focused ? c?.focusGained() : c?.focusLost(),
              child: DesktopEditingDirection(
                controller: f.composer,
                multiline: true,
                builder: (context, direction) => TextField(
                  key: const ValueKey('capture-field'),
                  controller: f.composer,
                  focusNode: f.focus,
                  autofocus: true,
                  minLines: 5,
                  maxLines: 9,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
                  textDirection: direction,
                  decoration: InputDecoration(
                    hintText: l.captureHint,
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: f.write,
                ),
              ),
            ),
          ),
          Row(
            children: [
              DesktopFocusRing(
                child: Checkbox(
                  semanticLabel: l.checklist,
                  value: f.checklist,
                  onChanged: f.session.id == null && !f.saving
                      ? (v) {
                          f.checklist = v!;
                          f.notify();
                        }
                      : null,
                ),
              ),
              Text(l.checklist, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          _actions(context, f, l, c),
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
              label: Text(
                desktopDigits(context, l.mediaAdded(f.importedCount)),
              ),
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

  Widget _actions(
    BuildContext context,
    NexFeatures f,
    AppLocalizations l,
    PanelController? c, {
    bool dense = false,
  }) {
    return Wrap(
      spacing: dense ? 6 : 8,
      runSpacing: dense ? 6 : 8,
      children: [
        _CaptureAction(
          dense: dense,
          label: l.pasteText,
          onPressed: () => _pasteText(f),
          icon: Icons.content_paste_rounded,
        ),
        _CaptureAction(
          dense: dense,
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
          dense: dense,
          label: l.attach,
          onPressed: f.importing ? null : () => _choose(context, f),
          icon: Icons.attach_file_rounded,
        ),
        _CaptureAction(
          dense: dense,
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
          dense: dense,
          label: f.recordingAt == null ? l.record : l.stop,
          onPressed: f.recordingBusy ? null : () => f.record(c),
          icon: f.recordingAt == null
              ? Icons.mic_none_rounded
              : Icons.stop_circle_outlined,
        ),
        if (c != null)
          _CaptureAction(
            dense: dense,
            label: l.pastePhoto,
            onPressed: () => f.guard(() async {
              final image = await c.native.currentClipboardImage();
              if (image == null) throw StateError(l.noClipboardImage);
              await f.pasteImage(image, rethrowError: true);
            }),
            icon: Icons.content_paste_go_rounded,
          ),
      ],
    );
  }

  /// A bare URL on the clipboard (no whitespace around it).
  static final _bareUrl = RegExp(r'^https?://\S+$', caseSensitive: false);

  /// Ctrl+V edits the current note in both layouts. The separate Paste text
  /// action below deliberately starts a new capture.
  Future<void> _pasteIntoComposer(
    BuildContext context,
    NexFeatures f,
    PanelController? c,
  ) {
    final session = f.session;
    return f.guard(() async {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (!context.mounted || !identical(session, f.session)) return;
      final text = clip?.text;
      if (text != null && text.isNotEmpty) {
        final selection = f.composer.selection;
        final value = f.composer.text;
        final start = selection.isValid ? selection.start : value.length;
        final end = selection.isValid ? selection.end : value.length;
        f.composer.value = TextEditingValue(
          text: value.replaceRange(start, end, text),
          selection: TextSelection.collapsed(offset: start + text.length),
        );
        await session.write(f.composer.text, checklist: f.checklist);
      } else if (c != null) {
        final image = await c.native.currentClipboardImage();
        if (!context.mounted || !identical(session, f.session)) return;
        if (image != null) await f.pasteImage(image, rethrowError: true);
      }
    });
  }

  /// Paste text (IDEAS.md, paste-to-note intelligence): a bare URL becomes
  /// a link note immediately instead of parking the URL in the composer —
  /// the store's capture path detects URLs, and the page preview is fetched
  /// later, off the capture path. Any other text lands in the composer.
  Future<void> _pasteText(NexFeatures f) => f.guard(() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text?.isNotEmpty != true) return;
    final trimmed = clip!.text!.trim();
    if (!await f.fresh()) {
      throw StateError(f.error ?? 'Capture flush failed');
    }
    if (_bareUrl.hasMatch(trimmed)) {
      // A quick-pasted link is an independent capture. Keeping its ID in an
      // empty composer made the next typed thought overwrite that link.
      await f.store.call<dynamic>('capture', {'text': trimmed});
      return;
    }
    f.composer.text = clip.text!;
    f.write(clip.text!);
  });
}

/// The composed capture view. Same library, so the mixin and this class
/// share every private member.
class NexCaptureView = CaptureViewBase with CaptureWide;

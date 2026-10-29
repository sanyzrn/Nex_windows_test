import 'dart:ui' show BoxWidthStyle;

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import '../l10n/intelligence_strings.dart';
import 'desktop_editing_direction.dart';

/// Matches Android: one reading surface and an explicit caption editor.
/// Only Note.caption participates; titles and AI fields stay separate.
class NexNoteCaption extends StatelessWidget {
  const NexNoteCaption({super.key, required this.note, required this.onSave});
  final Note note;
  final Future<void> Function(String text) onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final text = note.caption ?? '';
    final empty = text.trim().isEmpty;
    return Column(
      key: const ValueKey('note-caption'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.caption, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        if (empty)
          Text(l.noCaption, style: Theme.of(context).textTheme.bodyMedium)
        else if (nexLooksLikeMarkdown(text))
          NexMarkdown(text, preserveLineBreaks: true)
        else
          NexTextSurface(text, selectable: true),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('edit-note-caption'),
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _CaptionEditor(initial: text, onSave: onSave),
            ),
            child: Text(empty ? l.addCaption : l.editCaption),
          ),
        ),
      ],
    );
  }
}

class _CaptionEditor extends StatefulWidget {
  const _CaptionEditor({required this.initial, required this.onSave});
  final String initial;
  final Future<void> Function(String text) onSave;
  @override
  State<_CaptionEditor> createState() => _CaptionEditorState();
}

class _CaptionEditorState extends State<_CaptionEditor> {
  late final controller = TextEditingController(text: widget.initial);
  bool saving = false, failed = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.onSave(controller.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(l.caption),
        content: SizedBox(
          width: 600,
          height: (MediaQuery.sizeOf(context).height * .45).clamp(140, 360),
          child: Column(
            children: [
              Expanded(
                child: DesktopEditingDirection(
                  controller: controller,
                  builder: (context, direction) => TextField(
                    key: const ValueKey('note-caption-field'),
                    controller: controller,
                    textDirection: direction,
                    selectionWidthStyle: BoxWidthStyle.tight,
                    autofocus: true,
                    readOnly: saving,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(hintText: l.caption),
                  ),
                ),
              ),
              if (failed)
                Text(
                  l.failed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text(AiStrings.of(context).t('cancel')),
          ),
          FilledButton(
            key: const ValueKey('save-note-caption'),
            onPressed: saving ? null : save,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

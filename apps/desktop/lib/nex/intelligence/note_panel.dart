import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_ai/cloud.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/intelligence_strings.dart';
import '../features_state.dart';
import 'settings.dart';
import 'workspace.dart';

/// Generated writing stays a preview until an explicit save or replacement.
class NoteIntelligencePanel extends StatefulWidget {
  const NoteIntelligencePanel({
    super.key,
    required this.note,
    required this.onChanged,
  });
  final Note note;
  final VoidCallback onChanged;
  @override
  State<NoteIntelligencePanel> createState() => _NoteIntelligenceState();
}

class _NoteIntelligenceState extends State<NoteIntelligencePanel> {
  String? _result, _task, _failure;
  List<String> _tags = [];
  AiOutputLanguage _language = AiOutputLanguage.english;
  NexRewriteStyle _style = NexRewriteStyle.fix;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _failure = null);
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failure = AiStrings.of(context).t('failed'));
    }
  }

  Future<void> _process(String task) async {
    final ai = NexScope.of(context).intelligence;
    final result = await ai.process(
      widget.note,
      task,
      target: _language,
      style: _style,
    );
    if (mounted) {
      setState(() {
        _result = result;
        _task = task;
        _tags = List.of(ai.suggestions);
      });
    }
  }

  Future<void> _save(String mode) async {
    if (_result == null) return;
    final features = NexScope.of(context), s = AiStrings.of(context);
    if (mode == 'replace') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.t('confirmBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.t('replaceBody')),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    await features.guard(() async {
      final store = features.store;
      // Use the latest caption/body, never the stale snapshot that started AI.
      final current = await store.call<Note?>('get', {'id': widget.note.id});
      if (current == null || current.deletedAt != null) {
        throw StateError('Note is unavailable');
      }
      switch (mode) {
        case 'new':
          await store.call<Note>('capture', {'text': _result});
        case 'append':
          await store.call<void>('caption', {
            'id': current.id,
            'text': [
              if (current.caption?.trim().isNotEmpty == true) current.caption!,
              _result!,
            ].join('\n\n'),
          });
        case 'replace':
          await store.call<void>('capture', {
            'id': current.id,
            'text': _result,
          });
        case 'derived':
          await store.call<void>('aiEnrich', {
            'id': current.id,
            'field': _task,
            'text': _result,
          });
        case 'tags':
          for (final name in _tags) {
            await store.call<void>('tag', {'id': current.id, 'name': name});
          }
      }
    }, rethrowError: true);
    widget.onChanged();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.t('applied'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = NexScope.of(context).intelligence,
        s = AiStrings.of(context),
        theme = Theme.of(context);
    return ExpansionTile(
      key: const ValueKey('note-intelligence'),
      tilePadding: EdgeInsets.zero,
      leading: Icon(
        Icons.auto_awesome_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(s.t('ai')),
      childrenPadding: const EdgeInsets.only(bottom: 16),
      children: [
        FutureBuilder<void>(
          future: ai.initialize(),
          builder: (context, snapshot) => ListenableBuilder(
            listenable: ai,
            builder: (context, _) {
              if (!ai.ready) return const LinearProgressIndicator();
              if (!ai.enabled) {
                return OutlinedButton.icon(
                  onPressed: () => showIntelligenceSettings(context),
                  icon: const Icon(Icons.tune),
                  label: Text(s.t('configure')),
                );
              }
              final text =
                  (widget.note.aiSourceText ?? widget.note.caption)
                      ?.trim()
                      .isNotEmpty ==
                  true;
              Widget tool(String task, IconData icon, bool available) =>
                  OutlinedButton.icon(
                    onPressed: ai.busy || !available
                        ? null
                        : () => _run(() => _process(task)),
                    icon: Icon(icon, size: 17),
                    label: Text(s.t(task)),
                  );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      tool(
                        'summary',
                        Icons.short_text,
                        text && ai.flag('ai.summary', true),
                      ),
                      tool(
                        'tags',
                        Icons.sell_outlined,
                        text && ai.flag('ai.tags', true),
                      ),
                      if (widget.note.type == NoteType.photo)
                        tool(
                          'ocr',
                          Icons.document_scanner_outlined,
                          ai.config.supportsImages && ai.flag('ai.ocr', true),
                        ),
                      if (widget.note.type == NoteType.voice)
                        tool(
                          'transcribe',
                          Icons.graphic_eq,
                          ai.config.supportsTranscription &&
                              ai.flag('ai.transcription', true),
                        ),
                      OutlinedButton.icon(
                        onPressed: ai.busy
                            ? null
                            : () => showNoteAssistant(context, widget.note),
                        icon: const Icon(Icons.chat_bubble_outline, size: 17),
                        label: Text(s.t('assistant')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<AiOutputLanguage>(
                    initialValue: _language,
                    decoration: InputDecoration(labelText: s.t('target')),
                    items: AiOutputLanguage.values
                        .where((l) => l != AiOutputLanguage.auto)
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(s.t(l.wireName)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                  const SizedBox(height: 8),
                  tool('translate', Icons.translate, text),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<NexRewriteStyle>(
                    initialValue: _style,
                    decoration: InputDecoration(labelText: s.t('rewriteStyle')),
                    items: NexRewriteStyle.values
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(s.t(v.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _style = v!),
                  ),
                  const SizedBox(height: 8),
                  tool('rewrite', Icons.edit_note, text),
                  if (ai.busy)
                    Row(
                      children: [
                        const Expanded(child: LinearProgressIndicator()),
                        TextButton(
                          onPressed: ai.cancel,
                          child: Text(s.t('stop')),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (_failure != null)
                    Text(
                      _failure!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  if (_result == null)
                    Text(s.t('emptyResult'), style: theme.textTheme.bodySmall)
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            s.t('result'),
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          NexSelectableLines(child: NexMarkdown(_result!)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: _result!),
                                ),
                                icon: const Icon(Icons.copy_outlined, size: 17),
                                label: Text(s.t('copy')),
                              ),
                              TextButton(
                                onPressed: () => _run(() => _save('new')),
                                child: Text(s.t('saveNote')),
                              ),
                              if (const {
                                'summary',
                                'ocr',
                                'transcribe',
                              }.contains(_task))
                                TextButton(
                                  onPressed: () => _run(() => _save('derived')),
                                  child: Text(s.t('saveDerived')),
                                ),
                              if (_task == 'tags')
                                TextButton(
                                  onPressed: () => _run(() => _save('tags')),
                                  child: Text(s.t('saveTags')),
                                )
                              else ...[
                                TextButton(
                                  onPressed: () => _run(() => _save('append')),
                                  child: Text(s.t('append')),
                                ),
                                if (widget.note.type == NoteType.text)
                                  TextButton(
                                    onPressed: () =>
                                        _run(() => _save('replace')),
                                    child: Text(s.t('replaceBody')),
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

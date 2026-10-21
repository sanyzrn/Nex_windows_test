import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_ai/cloud.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/intelligence_strings.dart';
import '../../l10n/desktop_strings.dart';
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
    return NexSoftCard(
      key: const ValueKey('note-intelligence'),
      accent: theme.colorScheme.primary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  DesktopStrings.of(context).t('noteAi'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.t('settings'),
                onPressed: () => showIntelligenceSettings(context),
                icon: const Icon(Icons.tune_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                Widget tool(
                  String task,
                  IconData icon,
                  bool available, {
                  Future<void> Function()? action,
                }) => IconButton.filledTonal(
                  tooltip: s.t(task),
                  onPressed: ai.busy || !available
                      ? null
                      : () => _run(action ?? () => _process(task)),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: Icon(icon, size: 23),
                );
                Future<void> choose(String task) async {
                  final chosen = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(s.t(task)),
                      content: SizedBox(
                        width: 340,
                        child: task == 'translate'
                            ? DropdownButtonFormField<AiOutputLanguage>(
                                borderRadius: nexDropdownRadius,
                                dropdownColor: nexDropdownColor(context),
                                initialValue: _language,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: s.t('target'),
                                ),
                                items: AiOutputLanguage.values
                                    .where((v) => v != AiOutputLanguage.auto)
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(s.t(v.wireName)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) _language = v;
                                },
                              )
                            : DropdownButtonFormField<NexRewriteStyle>(
                                borderRadius: nexDropdownRadius,
                                dropdownColor: nexDropdownColor(context),
                                initialValue: _style,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: s.t('rewriteStyle'),
                                ),
                                items: NexRewriteStyle.values
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(s.t(v.name)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) _style = v;
                                },
                              ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(s.t('cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(s.t(task)),
                        ),
                      ],
                    ),
                  );
                  if (chosen == true && mounted) await _process(task);
                }

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
                        tool(
                          'translate',
                          Icons.translate_rounded,
                          text,
                          action: () => choose('translate'),
                        ),
                        tool(
                          'rewrite',
                          Icons.auto_awesome_rounded,
                          text,
                          action: () => choose('rewrite'),
                        ),
                        tool(
                          'assistant',
                          Icons.chat_bubble_outline_rounded,
                          true,
                          action: () => showNoteAssistant(context, widget.note),
                        ),
                      ],
                    ),
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
                                  icon: const Icon(
                                    Icons.copy_outlined,
                                    size: 17,
                                  ),
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
                                    onPressed: () =>
                                        _run(() => _save('derived')),
                                    child: Text(s.t('saveDerived')),
                                  ),
                                if (_task == 'tags')
                                  TextButton(
                                    onPressed: () => _run(() => _save('tags')),
                                    child: Text(s.t('saveTags')),
                                  )
                                else ...[
                                  TextButton(
                                    onPressed: () =>
                                        _run(() => _save('append')),
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
      ),
    );
  }
}

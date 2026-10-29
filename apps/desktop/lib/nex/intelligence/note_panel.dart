import 'dart:async';
import 'package:flutter/material.dart';
import '../../ui/desktop_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:nex_ai/cloud.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/intelligence_strings.dart';
import '../../l10n/desktop_strings.dart';
import '../features_state.dart';
import 'controller.dart';
import 'settings.dart';
import 'workspace.dart';

/// Generated writing stays a preview until an explicit save or replacement.
class NoteIntelligencePanel extends StatefulWidget {
  const NoteIntelligencePanel({
    super.key,
    required this.note,
    required this.onChanged,
    required this.onAppendCaption,
  });
  final Note note;
  final Future<void> Function() onChanged;
  final Future<bool> Function(String text) onAppendCaption;
  @override
  State<NoteIntelligencePanel> createState() => _NoteIntelligenceState();
}

class _NoteIntelligenceState extends State<NoteIntelligencePanel> {
  String? _result, _task, _failure;
  List<String> _tags = [];
  AiOutputLanguage _language = AiOutputLanguage.english;
  NexRewriteStyle _style = NexRewriteStyle.fix;
  bool _started = false;
  bool _working = false;
  final _savedModes = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.note.isImageMedia && widget.note.ocrText?.isNotEmpty == true) {
      _result = widget.note.ocrText;
      _task = 'ocr';
    } else if (widget.note.isAudioMedia &&
        widget.note.transcriptText?.isNotEmpty == true) {
      _result = widget.note.transcriptText;
      _task = 'transcribe';
    }
    if (_result != null) _savedModes.add('derived');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The card only appears once a provider is set, so the settings have to
    // be read here rather than inside the card.
    unawaited(NexScope.of(context).intelligence.initialize());
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _failure = null;
      _working = true;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failure = AiStrings.of(context).t('failed'));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _process(String task) async {
    final features = NexScope.of(context);
    final ai = features.intelligence;
    final source = widget.note;
    setState(() {
      _result = null;
      _task = null;
      _tags = [];
      _savedModes.clear();
    });
    final result = await ai.process(
      source,
      task,
      target: _language,
      style: _style,
    );
    if (task == 'ocr' || task == 'transcribe') {
      await features.guard(
        () => features.store.call<void>('aiEnrich', {
          'id': source.id,
          'field': task,
          'text': result,
        }),
        rethrowError: true,
      );
      if (mounted) await widget.onChanged();
      _savedModes.add('derived');
    }
    if (mounted && widget.note.id == source.id) {
      setState(() {
        _result = result;
        _task = task;
        _tags = List.of(ai.suggestions);
      });
    }
  }

  Future<void> _save(String mode) async {
    final result = _result;
    if (result == null || _savedModes.contains(mode)) return;
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
      if (accepted != true || !mounted) return;
    }
    if (mode == 'append') {
      // The reader owns its editable caption and synchronizes it after saving.
      if (!await widget.onAppendCaption(result)) return;
    } else {
      await features.guard(() async {
        final store = features.store;
        // Use the latest caption/body, never the stale snapshot that started AI.
        final current = await store.call<Note?>('get', {'id': widget.note.id});
        if (current == null || current.deletedAt != null) {
          throw StateError('Note is unavailable');
        }
        switch (mode) {
          case 'new':
            await store.call<Note>('capture', {'text': result});
          case 'replace':
            await store.call<void>('capture', {
              'id': current.id,
              'text': result,
            });
          case 'derived':
            await store.call<void>('aiEnrich', {
              'id': current.id,
              'field': _task,
              'text': result,
            });
          case 'tags':
            for (final name in _tags) {
              await store.call<void>('tag', {'id': current.id, 'name': name});
            }
        }
      }, rethrowError: true);
      if (mounted) await widget.onChanged();
    }
    if (mounted) {
      setState(() => _savedModes.add(mode));
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
    return ListenableBuilder(
      listenable: ai,
      // Until a provider is set there is nothing to offer a note; the way in
      // is Settings and the Intelligence page, not a card on every note.
      builder: (context, child) => ai.ready && (ai.enabled || _result != null)
          ? child!
          : const SizedBox.shrink(),
      child: _card(context, ai, s, theme),
    );
  }

  Widget _card(
    BuildContext context,
    DesktopIntelligence ai,
    AiStrings s,
    ThemeData theme,
  ) {
    return NexSoftCard(
      key: const ValueKey('note-intelligence'),
      accent: theme.colorScheme.primary,
      padding: const EdgeInsets.all(14),
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
                  style: theme.textTheme.titleSmall,
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
                if (!ai.enabled && _result == null) {
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
                  onPressed: !ai.enabled || ai.busy || _working || !available
                      ? null
                      : () => _run(action ?? () => _process(task)),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.all(11),
                  ),
                  icon: Icon(icon, size: 21),
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
                                style: desktopDropdownStyle(context),
                                isDense: true,
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
                                style: desktopDropdownStyle(context),
                                isDense: true,
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
                        if (widget.note.isImageMedia)
                          tool(
                            'ocr',
                            Icons.document_scanner_outlined,
                            ai.config.supportsImages && ai.flag('ai.ocr', true),
                          ),
                        if (widget.note.isAudioMedia)
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
                    if (ai.busy || _working)
                      Row(
                        children: [
                          const Expanded(child: LinearProgressIndicator()),
                          if (ai.busy)
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
                                  onPressed:
                                      _working ||
                                          ai.busy ||
                                          _savedModes.contains('new')
                                      ? null
                                      : () => _run(() => _save('new')),
                                  child: Text(s.t('saveNote')),
                                ),
                                if (const {
                                  'summary',
                                  'ocr',
                                  'transcribe',
                                }.contains(_task))
                                  TextButton(
                                    onPressed:
                                        _working ||
                                            ai.busy ||
                                            _savedModes.contains('derived')
                                        ? null
                                        : () => _run(() => _save('derived')),
                                    child: Text(s.t('saveDerived')),
                                  ),
                                if (_task == 'tags')
                                  TextButton(
                                    onPressed:
                                        _working ||
                                            ai.busy ||
                                            _savedModes.contains('tags')
                                        ? null
                                        : () => _run(() => _save('tags')),
                                    child: Text(s.t('saveTags')),
                                  )
                                else ...[
                                  TextButton(
                                    onPressed:
                                        _working ||
                                            ai.busy ||
                                            _savedModes.contains('append')
                                        ? null
                                        : () => _run(() => _save('append')),
                                    child: Text(s.t('append')),
                                  ),
                                  if (widget.note.type == NoteType.text)
                                    TextButton(
                                      onPressed:
                                          _working ||
                                              ai.busy ||
                                              _savedModes.contains('replace')
                                          ? null
                                          : () => _run(() => _save('replace')),
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

import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_ai/cloud.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:record/record.dart';
import '../../l10n/intelligence_strings.dart';
import '../features_state.dart';
import 'controller.dart';
import 'citations.dart';
import 'settings.dart';

Future<void> showNoteAssistant(BuildContext context, Note note) {
  final features = NexScope.of(context);
  final panel = NexPanelScope.maybeOf(context);
  features.intelligence.newConversation(note: note);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => NexScope(
      features: features,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 1000,
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  tooltip: AiStrings.of(context).t('close'),
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: panel == null
                    ? const DesktopAssistant()
                    : NexPanelScope(
                        controller: panel,
                        child: const DesktopAssistant(),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DesktopAssistant extends StatefulWidget {
  const DesktopAssistant({super.key});
  @override
  State<DesktopAssistant> createState() => _AssistantState();
}

class _AssistantState extends State<DesktopAssistant> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  DesktopIntelligence? _ai;
  String? _failure;
  bool _history = false;
  List<Note>? _matches;
  AudioRecorder? _recorder;
  Directory? _voiceDir;
  bool _recording = false, _voiceBusy = false;
  static Future<void> _removeVoiceDirectory(Directory? directory) async {
    if (directory == null) return;
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      /* A closing recorder may still own its temp file. */
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ai ??= NexScope.of(context).intelligence;
    unawaited(_ai!.initialize());
  }

  @override
  void dispose() {
    final recorder = _recorder, directory = _voiceDir;
    unawaited(
      () async {
        try {
          await recorder?.dispose();
        } finally {
          await _removeVoiceDirectory(directory);
        }
      }().catchError((Object _) {}),
    );
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _voice() async {
    if (_voiceBusy) return;
    setState(() => _voiceBusy = true);
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!_recording) {
        if (NexScope.of(context).recordingAt != null ||
            !await recorder.hasPermission()) {
          throw StateError('Microphone unavailable');
        }
        _voiceDir = await Directory.systemTemp.createTemp('nex-question-');
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: '${_voiceDir!.path}/question.wav',
        );
        if (mounted) setState(() => _recording = true);
      } else {
        final path = await recorder.stop();
        if (mounted) setState(() => _recording = false);
        if (path != null) {
          final text = await _ai!.transcribeQuestion(path);
          if (mounted) {
            setState(
              () => _input.text = [
                _input.text,
                text,
              ].where((t) => t.trim().isNotEmpty).join(' '),
            );
          }
        }
      }
    } finally {
      if (!_recording) {
        final directory = _voiceDir;
        _voiceDir = null;
        await _removeVoiceDirectory(directory);
      }
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _failure = null);
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failure = AiStrings.of(context).t('failed'));
    }
  }

  void _send([String? prompt]) {
    final text = prompt ?? _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    setState(() => _matches = null);
    unawaited(
      _run(() async {
        await _ai!.send(text);
        if (mounted && _scroll.hasClients) {
          await _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }),
    );
  }

  Future<void> _attach() async {
    final s = AiStrings.of(context);
    if (_ai!.attachments.length >= 4) {
      setState(() => _failure = s.t('limitImage'));
      return;
    }
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    for (final file in files.take(4 - _ai!.attachments.length)) {
      if (await file.length() > 8 * 1024 * 1024) {
        if (mounted) setState(() => _failure = s.t('limitImage'));
        continue;
      }
      final extension = file.path.split('.').last.toLowerCase();
      _ai!.addAttachment(
        NexChatAttachment(
          bytes: await file.readAsBytes(),
          mimeType: extension == 'jpg' || extension == 'jpeg'
              ? 'image/jpeg'
              : 'image/$extension',
        ),
      );
    }
  }

  Future<void> _applySetting(AssistantAction a) async {
    final panel = NexPanelScope.maybeOf(context);
    if (a.settingKey == 'ai_language') {
      await _ai!.setValue('ai.outputLanguage', a.settingValue!);
      return;
    }
    if (panel == null) throw StateError('Window settings are unavailable');
    final v = a.settingValue!;
    switch (a.settingKey) {
      case 'theme':
        panel.S.theme = v;
      case 'language':
        panel.S.language = v;
      case 'palette':
        panel.S.preset = v;
      case 'accent':
        panel.S.accentSeed = v == 'default' ? null : v;
      case 'text_size':
        panel.S.uiScale = const {
          'small': .9,
          'default': 1.0,
          'large': 1.15,
          'larger': 1.3,
        }[v]!;
      default:
        throw ArgumentError('Unsupported setting');
    }
    panel.save();
    panel.refresh();
  }

  Future<void> _apply() async {
    final features = NexScope.of(context);
    await features.guard(() async {
      await _ai!.applyPending(applySetting: _applySetting);
    }, rethrowError: true);
    await features.synchronizeReminders?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AiStrings.of(context).t('actionsDone'))),
      );
    }
  }

  Widget _historyPane(AiStrings s) => SizedBox(
    width: 238,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            s.t('history'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: _ai!.conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(s.t('emptyHistory')),
                  ),
                )
              : ListView(
                  children: _ai!.conversations.keys.toList().reversed.map((id) {
                    final raw = _ai!.conversations[id] as Map;
                    final turns = raw['turns'] as List? ?? [];
                    final title = turns.isEmpty
                        ? s.t('newChat')
                        : '${turns.first['text']}';
                    return ListTile(
                      dense: true,
                      selected: _ai!.conversationId == id,
                      title: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: nexDirectionOf(title),
                      ),
                      onTap: _ai!.busy ? null : () => _ai!.openConversation(id),
                      trailing: IconButton(
                        tooltip: s.t('remove'),
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _ai!.busy
                            ? null
                            : () => _run(() => _ai!.deleteConversation(id)),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final ai = _ai!,
        s = AiStrings.of(context),
        theme = Theme.of(context),
        c = theme.colorScheme;
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        if (!ai.ready) return const Center(child: CircularProgressIndicator());
        final locked = ai.busy || ai.pending.isNotEmpty;
        return LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              if (_history && box.maxWidth >= 850) ...[
                _historyPane(s),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: c.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                s.t('ai'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (box.maxWidth >= 850)
                                IconButton(
                                  tooltip: s.t('history'),
                                  isSelected: _history,
                                  onPressed: () =>
                                      setState(() => _history = !_history),
                                  icon: const Icon(Icons.history),
                                ),
                              if (box.maxWidth < 850)
                                PopupMenuButton<String>(
                                  tooltip: s.t('history'),
                                  icon: const Icon(Icons.history),
                                  onSelected: ai.openConversation,
                                  itemBuilder: (_) => ai.conversations.entries
                                      .toList()
                                      .reversed
                                      .map((e) {
                                        final list =
                                            (e.value as Map)['turns'] as List;
                                        final text = list.isEmpty
                                            ? s.t('newChat')
                                            : '${list.first['text']}';
                                        return PopupMenuItem(
                                          value: e.key,
                                          child: Text(
                                            text,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      })
                                      .toList(),
                                ),
                              IconButton(
                                tooltip: s.t('newChat'),
                                onPressed: ai.busy ? null : ai.newConversation,
                                icon: const Icon(Icons.edit_square),
                              ),
                              IconButton(
                                tooltip: s.t('settings'),
                                onPressed: () =>
                                    showIntelligenceSettings(context),
                                icon: const Icon(Icons.tune),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (ai.focusedNote != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InputChip(
                          avatar: const Icon(Icons.notes_outlined, size: 16),
                          label: Text(
                            ai.focusedNote!.displayText ??
                                s.t('selectedContext'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: ai.busy
                              ? null
                              : () => ai.newConversation(),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.symmetric(
                          horizontal: box.maxWidth > 1000 ? 64 : 20,
                          vertical: 20,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (ai.turns.isEmpty) ...[
                                  const SizedBox(height: 22),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: c.primaryContainer,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        color: c.onPrimaryContainer,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    s.t('studio'),
                                    style: theme.textTheme.headlineLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -1,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    s.t('intro'),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: c.onSurfaceVariant,
                                      height: 1.8,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  for (final prompt in [
                                    'promptPlan',
                                    'promptFind',
                                    'promptTasks',
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          padding: const EdgeInsets.all(18),
                                        ),
                                        onPressed: !ai.enabled || locked
                                            ? null
                                            : () => _send(s.t(prompt)),
                                        child: Text(s.t(prompt)),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                ],
                                for (final turn in ai.turns)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: Align(
                                      alignment: turn.role == ChatRole.user
                                          ? AlignmentDirectional.centerEnd
                                          : AlignmentDirectional.centerStart,
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: turn.role == ChatRole.user
                                              ? c.primaryContainer
                                              : c.surfaceContainerLowest,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: c.outlineVariant,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            NexSelectableLines(
                                              child: NexMarkdown(
                                                turn.role == ChatRole.assistant
                                                    ? NexCitedReply.parse(
                                                        withoutActionBlock(
                                                          turn.content,
                                                        ),
                                                      ).text
                                                    : turn.content,
                                              ),
                                            ),
                                            if (turn.role == ChatRole.assistant)
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  for (final id
                                                      in NexCitedReply.parse(
                                                        withoutActionBlock(
                                                          turn.content,
                                                        ),
                                                      ).noteIds)
                                                    _Citation(id: id),
                                                ],
                                              ),
                                            if (turn.role == ChatRole.assistant)
                                              Align(
                                                alignment: AlignmentDirectional
                                                    .centerEnd,
                                                child: IconButton(
                                                  tooltip: s.t('copy'),
                                                  icon: const Icon(
                                                    Icons.copy_outlined,
                                                    size: 16,
                                                  ),
                                                  onPressed: () =>
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: NexCitedReply.parse(
                                                            withoutActionBlock(
                                                              turn.content,
                                                            ),
                                                          ).text,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (ai.pending.isNotEmpty)
                                  _ActionReview(
                                    actions: ai.pending,
                                    onApply: () => _run(_apply),
                                    onDiscard: ai.dismissPending,
                                    enabled:
                                        !ai.busy && ai.canAct && ai.canRead,
                                  ),
                                if (_matches != null) ...[
                                  if (_matches!.isEmpty) Text(s.t('noResults')),
                                  for (final note in _matches!)
                                    ListTile(
                                      leading: const Icon(Icons.notes_outlined),
                                      title: Text(
                                        note.displayText ?? '',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () {
                                        NexScope.of(context).requestNote(note);
                                        NexPanelScope.maybeOf(
                                          context,
                                        )?.selectWindowSection('library');
                                      },
                                    ),
                                ],
                                if (ai.busy)
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(s.t('thinking')),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: ai.cancel,
                                        child: Text(s.t('stop')),
                                      ),
                                    ],
                                  ),
                                if (_failure != null || ai.error != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      _failure ?? s.t('failed'),
                                      style: TextStyle(color: c.error),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_recording && !ai.enabled)
                      TextButton.icon(
                        onPressed: () => _run(_voice),
                        icon: const Icon(Icons.stop_circle),
                        label: Text(s.t('listen')),
                      ),
                    if (!ai.enabled)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: FilledButton.tonalIcon(
                          onPressed: () => showIntelligenceSettings(context),
                          icon: const Icon(Icons.tune),
                          label: Text(s.t('configure')),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (ai.attachments.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (
                                    var i = 0;
                                    i < ai.attachments.length;
                                    i++
                                  )
                                    InputChip(
                                      avatar: const Icon(Icons.image_outlined),
                                      label: Text('${i + 1}'),
                                      onDeleted: locked
                                          ? null
                                          : () => ai.removeAttachment(i),
                                    ),
                                ],
                              ),
                            CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.enter,
                                  control: true,
                                ): locked
                                    ? () {}
                                    : _send,
                              },
                              child: TextField(
                                key: const ValueKey('assistant-input'),
                                controller: _input,
                                minLines: 1,
                                maxLines: 5,
                                textDirection: nexDirectionOf(_input.text),
                                onChanged: (_) => setState(() {}),
                                enabled: !locked,
                                decoration: InputDecoration(
                                  hintText: s.t(
                                    ai.pending.isNotEmpty
                                        ? 'pendingOld'
                                        : 'ask',
                                  ),
                                  filled: true,
                                  fillColor: c.surfaceContainerLowest,
                                  suffixIcon: IconButton(
                                    tooltip: s.t('send'),
                                    onPressed:
                                        locked || _input.text.trim().isEmpty
                                        ? null
                                        : _send,
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                if (ai.config.supportsImages)
                                  IconButton(
                                    tooltip: s.t('attach'),
                                    onPressed: locked
                                        ? null
                                        : () => _run(_attach),
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 20,
                                    ),
                                  ),
                                if (ai.config.supportsTranscription &&
                                        ai.flag('ai.transcription', true) ||
                                    _recording)
                                  IconButton(
                                    tooltip: s.t(
                                      _recording ? 'listen' : 'voice',
                                    ),
                                    onPressed: locked || _voiceBusy
                                        ? null
                                        : () => _run(_voice),
                                    icon: Icon(
                                      _recording
                                          ? Icons.stop_circle
                                          : Icons.mic_none_outlined,
                                      size: 20,
                                    ),
                                  ),
                                if (ai.config.supportsEmbeddings &&
                                    ai.flag('ai.semantic', true) &&
                                    ai.canRead)
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.manage_search,
                                      size: 18,
                                    ),
                                    label: Text(s.t('semantic')),
                                    onPressed:
                                        locked || _input.text.trim().isEmpty
                                        ? null
                                        : () => _run(() async {
                                            final notes = await ai
                                                .semanticSearch(_input.text);
                                            if (mounted) {
                                              setState(() => _matches = notes);
                                            }
                                          }),
                                  ),
                                Text(
                                  '${ai.config.provider.label} · ${ai.config.resolvedModel}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: c.onSurfaceVariant,
                                  ),
                                ),
                                Icon(
                                  ai.canRead
                                      ? Icons.library_books_outlined
                                      : Icons.lock_outline,
                                  size: 14,
                                  color: c.onSurfaceVariant,
                                ),
                                Text(
                                  s.t(ai.canRead ? 'reading' : 'notesOff'),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionReview extends StatelessWidget {
  const _ActionReview({
    required this.actions,
    required this.onApply,
    required this.onDiscard,
    required this.enabled,
  });
  final List<AssistantAction> actions;
  final VoidCallback onApply, onDiscard;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final s = AiStrings.of(context), c = Theme.of(context).colorScheme;
    return Card(
      color: c.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('review'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(s.t('confirmationHint')),
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t(a.kind.name),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final text in [
                      if (a.text != null) a.text!,
                      ...a.items,
                      if (a.tagName != null) a.tagName!,
                      if (a.threadName != null) a.threadName!,
                      if (a.commitmentName != null) a.commitmentName!,
                      if (a.settingKey != null)
                        '${a.settingKey}: ${a.settingValue}',
                      if (a.at != null) a.at!.toLocal().toString(),
                      if (a.flag != null) '${a.flag}',
                      if (a.index != null) '#${a.index! + 1}',
                      if (a.addTags.isNotEmpty) '+ ${a.addTags.join(', ')}',
                      if (a.removeTags.isNotEmpty)
                        '− ${a.removeTags.join(', ')}',
                    ])
                      SelectableText(text, textDirection: nexDirectionOf(text)),
                    for (final id in {
                      if (a.noteId != null) a.noteId!,
                      ...a.noteIds,
                    })
                      _TargetPreview(id: id),
                  ],
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: enabled ? onApply : null,
                  child: Text(s.t('confirm')),
                ),
                TextButton(onPressed: onDiscard, child: Text(s.t('discard'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetPreview extends StatefulWidget {
  const _TargetPreview({required this.id});
  final String id;
  @override
  State<_TargetPreview> createState() => _TargetPreviewState();
}

class _TargetPreviewState extends State<_TargetPreview> {
  Future<Note?>? _note;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _note ??= NexScope.of(context).store.call<Note?>('get', {'id': widget.id});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Note?>(
    future: _note,
    builder: (context, snapshot) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        snapshot.data?.displayText ?? widget.id,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _Citation extends StatefulWidget {
  const _Citation({required this.id});
  final String id;
  @override
  State<_Citation> createState() => _CitationState();
}

class _CitationState extends State<_Citation> {
  Future<Note?>? _note;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _note ??= NexScope.of(context).store.call<Note?>('get', {'id': widget.id});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Note?>(
    future: _note,
    builder: (context, snapshot) {
      final note = snapshot.data;
      if (note == null || note.deletedAt != null) {
        return const SizedBox.shrink();
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: ActionChip(
          avatar: const Icon(Icons.notes_outlined, size: 15),
          label: Text(
            note.displayText ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () {
            NexScope.of(context).requestNote(note);
            NexPanelScope.maybeOf(context)?.selectWindowSection('library');
            if (ModalRoute.of(context) is DialogRoute) Navigator.pop(context);
          },
        ),
      );
    },
  );
}

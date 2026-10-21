import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../features_state.dart';
import '../desktop_editing_direction.dart';
import 'cycle_labels.dart';

/// Each observation is queued immediately in the existing database worker.
/// A blur/lock can remove this editor without throwing a pending note away.
class DesktopCycleDayEditor extends StatefulWidget {
  const DesktopCycleDayEditor({
    super.key,
    required this.features,
    required this.initial,
    required this.onBack,
  });
  final NexFeatures features;
  final CycleDayLog initial;
  final VoidCallback onBack;
  @override
  State<DesktopCycleDayEditor> createState() => _DesktopCycleDayEditorState();
}

class _DesktopCycleDayEditorState extends State<DesktopCycleDayEditor> {
  late CycleDayLog log = widget.initial;
  late final note = TextEditingController(text: log.note ?? '');
  Future<void> pending = Future.value();
  int revision = 0, saving = 0;
  bool failed = false;
  void persist(CycleDayLog value) {
    if (!widget.features.modules.privateSession.isOpen) return;
    widget.features.modules.privateSession.touch();
    final token = ++revision;
    setState(() {
      log = value;
      saving++;
    });
    pending = widget.features.store.call<void>('cycleDay', {'log': value});
    unawaited(
      pending
          .then(
            (_) {
              if (mounted && token == revision) setState(() => failed = false);
            },
            onError: (Object _) {
              if (mounted && token == revision) setState(() => failed = true);
            },
          )
          .whenComplete(() {
            if (mounted) setState(() => saving--);
          }),
    );
  }

  Future<void> finish() async {
    persist(log.copyWith(note: () => note.text));
    try {
      await pending;
      if (mounted) widget.onBack();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(NexSpacing.md),
      children: [
        Text(l.cycleLog, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: NexSpacing.md),
        Text(l.cycleFlow),
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.xs,
          children: [
            for (final flow in CycleFlow.values)
              FilterChip(
                label: Text(cycleFlowLabel(l, flow)),
                selected: log.flow == flow,
                onSelected: (yes) =>
                    persist(log.copyWith(flow: () => yes ? flow : null)),
              ),
          ],
        ),
        const SizedBox(height: NexSpacing.md),
        Text(l.cycleMood),
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.xs,
          children: [
            for (final mood in CycleMood.values)
              FilterChip(
                label: Text(cycleMoodLabel(l, mood)),
                selected: log.mood == mood,
                onSelected: (yes) =>
                    persist(log.copyWith(mood: () => yes ? mood : null)),
              ),
          ],
        ),
        const SizedBox(height: NexSpacing.md),
        Text(l.cycleSymptoms),
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.xs,
          children: [
            for (final symptom in CycleSymptom.values)
              FilterChip(
                label: Text(cycleSymptomLabel(l, symptom)),
                selected: log.symptoms.contains(symptom),
                onSelected: (yes) => persist(
                  log.copyWith(
                    symptoms: {...log.symptoms}
                      ..remove(symptom)
                      ..addAll(yes ? [symptom] : []),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: NexSpacing.md),
        DesktopEditingDirection(
          controller: note,
          builder: (context, direction) => TextField(
            controller: note,
            textDirection: direction,
            minLines: 3,
            maxLines: 8,
            enableInteractiveSelection: false,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.cycleNote),
            onChanged: (text) => persist(log.copyWith(note: () => text)),
          ),
        ),
        const SizedBox(height: NexSpacing.md),
        if (saving > 0) Text(l.saving),
        if (failed)
          Text(
            l.failed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          onPressed: finish,
          icon: const Icon(Icons.check_rounded),
          label: Text(l.save),
        ),
      ],
    );
  }
}

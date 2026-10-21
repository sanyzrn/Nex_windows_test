import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/desktop_format.dart';
import '../features_state.dart';

class DesktopPortraitView extends StatefulWidget {
  const DesktopPortraitView({super.key, required this.features, this.statsAt});
  final NexFeatures features;
  final DateTime? statsAt;
  @override
  State<DesktopPortraitView> createState() => _DesktopPortraitViewState();
}

class _DesktopPortraitViewState extends State<DesktopPortraitView> {
  NexWritingStats? stats;
  bool failed = false, generating = false;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final notes = await widget.features.store.call<List<Note>>(
        'portraitNotes',
      );
      final value = nexWritingStats(notes, now: widget.statsAt);
      await widget.features.intelligence.initialize();
      if (mounted) {
        setState(() {
          stats = value;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> write() async {
    final l = AppLocalizations.of(context)!;
    final ai = widget.features.intelligence;
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.portraitConsentTitle),
        content: SingleChildScrollView(child: Text(l.portraitConsent)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.moduleCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.portraitWrite),
          ),
        ],
      ),
    );
    if (consent != true || !mounted || ai.busy) return;
    setState(() {
      generating = true;
      failed = false;
    });
    try {
      final value = await ai.writePortrait();
      if (mounted && value == null) setState(() => failed = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  void dispose() {
    if (generating) widget.features.intelligence.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final s = stats;
    if (s == null) {
      return Center(
        child: failed
            ? TextButton(onPressed: load, child: Text(l.retry))
            : const CircularProgressIndicator(),
      );
    }
    return ListenableBuilder(
      listenable: widget.features.intelligence,
      builder: (context, _) {
        final ai = widget.features.intelligence;
        final written = ai.writtenPortrait;
        return ListView(
          padding: const EdgeInsets.all(NexSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.portraitLocal,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l.retry,
                  onPressed: generating ? null : load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: NexSpacing.md),
            Wrap(
              spacing: NexSpacing.sm,
              runSpacing: NexSpacing.sm,
              children: [
                for (final pair in [
                  (l.portraitNotes, s.notes),
                  (l.portraitDays, s.days),
                  (l.portraitRecent, s.activeLast30),
                ])
                  Container(
                    constraints: const BoxConstraints(minWidth: 130),
                    padding: const EdgeInsets.all(NexSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(NexRadius.lg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          desktopDigits(context, pair.$2),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                        Text(
                          pair.$1,
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NexSpacing.lg),
            for (final part in NexDayPart.values)
              Padding(
                padding: const EdgeInsets.only(bottom: NexSpacing.md),
                child: _PortraitMeter(
                  label: [
                    l.portraitMorning,
                    l.portraitAfternoon,
                    l.portraitEvening,
                    l.portraitNight,
                  ][part.index],
                  value: s.notes == 0 ? 0 : s.dayParts[part.index] / s.notes,
                  count: desktopDigits(context, s.dayParts[part.index]),
                ),
              ),
            const SizedBox(height: NexSpacing.sm),
            Text(
              l.portraitKinds,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: NexSpacing.sm,
              runSpacing: NexSpacing.xs,
              children: [
                for (final (type, count) in s.types)
                  Chip(
                    label: Text(
                      '${noteTypeLabel(l, type)} · ${desktopDigits(context, count)}',
                    ),
                  ),
              ],
            ),
            if (s.tags.isNotEmpty) ...[
              const SizedBox(height: NexSpacing.md),
              Text(
                l.portraitTags,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: NexSpacing.sm,
                runSpacing: NexSpacing.xs,
                children: [
                  for (final (tag, count) in s.tags)
                    Chip(
                      label: Text('$tag · ${desktopDigits(context, count)}'),
                    ),
                ],
              ),
            ],
            if (s.checklistRate case final rate?) ...[
              const SizedBox(height: NexSpacing.md),
              _PortraitMeter(
                label: l.portraitChecks,
                value: rate,
                count: '${desktopDigits(context, (rate * 100).round())}٪',
              ),
            ],
            const Divider(height: NexSpacing.xl),
            if (!s.unlocked) Text(l.portraitThreshold),
            if (!ai.enabled || !ai.canRead) Text(l.portraitAiOff),
            if (failed)
              Text(l.portraitFailed, style: TextStyle(color: scheme.error)),
            const SizedBox(height: NexSpacing.md),
            Wrap(
              spacing: NexSpacing.sm,
              runSpacing: NexSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('portrait-write'),
                  onPressed: s.unlocked && ai.enabled && ai.canRead && !ai.busy
                      ? write
                      : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    generating
                        ? l.moduleLoading
                        : written == null
                        ? l.portraitWrite
                        : l.portraitRewrite,
                  ),
                ),
                if (generating)
                  TextButton(
                    onPressed: () {
                      ai.cancel();
                      setState(() {
                        generating = false;
                        failed = false;
                      });
                    },
                    child: Text(l.moduleCancel),
                  ),
                if (written != null && !generating)
                  TextButton(
                    onPressed: () async {
                      try {
                        await ai.removeWrittenPortrait();
                      } catch (_) {
                        if (mounted) setState(() => failed = true);
                      }
                    },
                    child: Text(l.portraitRemove),
                  ),
              ],
            ),
            if (generating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: NexSpacing.sm),
                child: LinearProgressIndicator(),
              ),
            if (written != null) ...[
              const SizedBox(height: NexSpacing.lg),
              NexTextSurface(
                written.headline,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: NexSpacing.sm),
              NexTextSurface(written.portrait, selectable: true),
              const SizedBox(height: NexSpacing.lg),
              for (final trait in written.traits) ...[
                _PortraitMeter(
                  label: trait.name,
                  value: trait.score / 100,
                  count: desktopDigits(context, trait.score),
                ),
                NexTextSurface(
                  trait.line,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: NexSpacing.md),
              ],
              Text(
                l.portraitStrengths,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: NexSpacing.sm,
                runSpacing: NexSpacing.xs,
                children: [
                  for (final strength in written.strengths)
                    Chip(label: Text(strength)),
                ],
              ),
              if (written.invitation.isNotEmpty) ...[
                const SizedBox(height: NexSpacing.md),
                Text(
                  l.portraitInvitation,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                NexTextSurface(written.invitation),
              ],
              const SizedBox(height: NexSpacing.md),
              Text(
                l.portraitBasedOn(desktopDigits(context, written.basedOn)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PortraitMeter extends StatelessWidget {
  const _PortraitMeter({
    required this.label,
    required this.count,
    required this.value,
  });
  final String label, count;
  final double value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [Text(label), Text(count)],
      ),
      const SizedBox(height: NexSpacing.xs),
      LinearProgressIndicator(
        value: value,
        minHeight: 4,
        borderRadius: BorderRadius.circular(NexRadius.sm),
      ),
    ],
  );
}

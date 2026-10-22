import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/desktop_format.dart';
import '../desktop_date_picker.dart';
import '../features_state.dart';
import 'cycle_calendar.dart';
import 'cycle_ring.dart';
import 'cycle_labels.dart';
import 'cycle_day_editor.dart';

class DesktopCycleView extends StatefulWidget {
  const DesktopCycleView({
    super.key,
    required this.features,
    this.clock = DateTime.now,
  });
  final NexFeatures features;
  final DateTime Function() clock;
  @override
  State<DesktopCycleView> createState() => _DesktopCycleViewState();
}

class _DesktopCycleViewState extends State<DesktopCycleView> {
  late DateTime selected = DateUtils.dateOnly(widget.clock()),
      month = DateUtils.dateOnly(widget.clock());
  List<CyclePeriod> periods = [];
  List<CycleDayLog> logs = [];
  CycleDayLog? log;
  bool loaded = false,
      busy = false,
      loading = false,
      failed = false,
      editingDay = false;
  int generation = 0;
  bool get solar =>
      NexPanelScope.maybeOf(context)?.S.solarCalendar ??
      (AppLocalizations.of(context)!.localeName == 'fa');
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final token = ++generation;
    setState(() => loading = true);
    try {
      final value = await widget.features.store
          .call<Map<String, dynamic>>('cycleSnapshot', {
            'day': selected,
            'from': month.subtract(const Duration(days: 40)),
            'to': month.add(const Duration(days: 40)),
          });
      if (mounted && token == generation) {
        setState(() {
          periods = (value['periods'] as List).cast<CyclePeriod>();
          logs = (value['days'] as List).cast<CycleDayLog>();
          log = value['log'] as CycleDayLog?;
          loaded = true;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && token == generation) setState(() => failed = true);
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  Future<void> change(String command, Map<String, dynamic> args) async {
    if (!widget.features.modules.privateSession.isOpen || busy) return;
    widget.features.modules.privateSession.touch();
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.features.store.call<dynamic>(command, args);
      if (mounted) await load();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(DateTime value) => nexDisplayDate(
    value,
    solar: solar,
    persian: AppLocalizations.of(context)!.localeName == 'fa',
  );
  Future<DateTime?> pick(DateTime initial) => showDesktopDatePicker(
    context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateUtils.dateOnly(widget.clock()),
    solar: solar,
    useRootNavigator: false,
  );
  Future<void> edit(CyclePeriod period) async {
    final l = AppLocalizations.of(context)!;
    var start = period.start.local, end = period.end?.local;
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: Text(l.cycleEdit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    final d = await pick(start);
                    if (d != null && dialog.mounted) update(() => start = d);
                  },
                  child: Text('${l.cycleStartDate}: ${date(start)}'),
                ),
                SwitchListTile.adaptive(
                  title: Text(l.cycleOngoing),
                  value: end == null,
                  onChanged: (value) => update(
                    () =>
                        end = value ? null : DateUtils.dateOnly(widget.clock()),
                  ),
                ),
                if (end != null)
                  TextButton(
                    onPressed: () async {
                      final d = await pick(end!);
                      if (d != null && dialog.mounted) update(() => end = d);
                    },
                    child: Text('${l.cycleEndDate}: ${date(end!)}'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l.moduleCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    if (end != null && end!.isBefore(start) ||
        CyclePeriod.clash(
              periods,
              period.id,
              CycleDate.of(start),
              end == null ? null : CycleDate.of(end!),
            ) !=
            null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l.cycleOverlap)));
      return;
    }
    await change('cycleUpdate', {'id': period.id, 'start': start, 'end': end});
  }

  Future<void> remove(CyclePeriod period) async {
    final l = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(l.cycleDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.moduleCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await change('cycleDelete', {'id': period.id});
  }

  Future<void> typical() async {
    final l = AppLocalizations.of(context)!;
    final modules = widget.features.modules;
    var cycle = modules.typicalCycle, period = modules.typicalPeriod;
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l.cycleTypical),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  borderRadius: nexDropdownRadius,
                  dropdownColor: nexDropdownColor(context),
                  initialValue: cycle,
                  decoration: InputDecoration(labelText: l.cycleLength),
                  items: [
                    for (var i = 15; i <= 60; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(desktopDigits(context, i)),
                      ),
                  ],
                  onChanged: (v) => update(() => cycle = v!),
                ),
                const SizedBox(height: NexSpacing.md),
                DropdownButtonFormField<int>(
                  borderRadius: nexDropdownRadius,
                  dropdownColor: nexDropdownColor(context),
                  initialValue: period,
                  decoration: InputDecoration(labelText: l.cyclePeriodLength),
                  items: [
                    for (var i = 1; i <= 15; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(desktopDigits(context, i)),
                      ),
                  ],
                  onChanged: (v) => update(() => period = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.moduleCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (yes != true || !mounted || !modules.privateSession.isOpen) return;
    try {
      await modules.setTypical(cycle: cycle, period: period);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final modules = widget.features.modules;
    if (editingDay) {
      return DesktopCycleDayEditor(
        features: widget.features,
        initial: log ?? CycleDayLog(day: CycleDate.of(selected)),
        onBack: () {
          setState(() => editingDay = false);
          unawaited(load());
        },
      );
    }
    if (!loaded && !failed) {
      return const Center(child: CircularProgressIndicator());
    }
    final prediction = CyclePredictor.predict(
      periods: periods,
      today: CycleDate.of(widget.clock()),
      typicalCycle: modules.typicalCycle,
      typicalPeriod: modules.typicalPeriod,
    );
    final open = periods.where((p) => p.isOpen).lastOrNull;
    final overview = Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(NexSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prediction == null)
              Text(l.cycleNoHistory)
            else
              DesktopCycleRing(prediction: prediction),
            if (prediction != null) ...[
              const SizedBox(height: NexSpacing.md),
              Text(l.cycleNext, style: Theme.of(context).textTheme.titleSmall),
              Text(
                '${date(prediction.nextEarliest.local)} – ${date(prediction.nextLatest.local)}',
              ),
              if (prediction.confidence != CycleConfidence.high)
                Text(
                  l.cycleUncertain,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: NexSpacing.md),
            Text(l.cycleEstimate, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: NexSpacing.md),
          ],
        ),
      ),
    );
    final calendar = Card(
      child: Padding(
        padding: const EdgeInsets.all(NexSpacing.sm),
        child: DesktopCycleCalendar(
          today: widget.clock(),
          selected: selected,
          month: month,
          solar: solar,
          periods: periods,
          logs: logs,
          onSelect: busy || loading
              ? (_) {}
              : (day) {
                  setState(() {
                    selected = day;
                    log = null;
                  });
                  unawaited(load());
                },
          onMonth: (value) {
            setState(() => month = value);
            unawaited(load());
          },
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(NexSpacing.md),
      children: [
        Text(l.cyclePrivacy, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: NexSpacing.md),
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 760) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 340, child: overview),
                  const SizedBox(width: NexSpacing.md),
                  Expanded(child: calendar),
                ],
              );
            }
            return Column(
              children: [
                overview,
                const SizedBox(height: NexSpacing.md),
                calendar,
              ],
            );
          },
        ),
        const SizedBox(height: NexSpacing.md),
        Text(date(selected), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: NexSpacing.sm),
        Text(l.cycleMood, style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: NexSpacing.xs,
          runSpacing: NexSpacing.xs,
          children: [
            for (final mood in CycleMood.values)
              ChoiceChip(
                label: Text(cycleMoodLabel(l, mood)),
                selected: log?.mood == mood,
                onSelected: busy || loading
                    ? null
                    : (yes) => change('cycleDay', {
                        'log': (log ?? CycleDayLog(day: CycleDate.of(selected)))
                            .copyWith(mood: () => yes ? mood : null),
                      }),
              ),
          ],
        ),
        const SizedBox(height: NexSpacing.sm),
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.sm,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('cycle-start'),
              onPressed: busy
                  ? null
                  : () => change('cycleStart', {
                      'day': selected,
                      'typicalPeriod': modules.typicalPeriod,
                    }),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(l.cycleStart),
            ),
            if (open != null && !CycleDate.of(selected).isBefore(open.start))
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () =>
                          change('cycleEnd', {'id': open.id, 'day': selected}),
                child: Text(l.cycleEnd),
              ),
            OutlinedButton.icon(
              onPressed: busy || loading
                  ? null
                  : () => setState(() => editingDay = true),
              icon: const Icon(Icons.edit_note),
              label: Text(l.cycleLog),
            ),
            TextButton(
              onPressed: busy ? null : typical,
              child: Text(l.cycleTypical),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (failed) ...[
          Text(
            l.failed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: load, child: Text(l.retry)),
        ],
        const SizedBox(height: NexSpacing.lg),
        Text(l.cycleHistory, style: Theme.of(context).textTheme.titleMedium),
        for (final period in periods.reversed)
          Card(
            child: ListTile(
              title: Text(
                '${date(period.start.local)} – ${period.end == null ? l.cycleOngoing : date(period.end!.local)}',
              ),
              onTap: busy ? null : () => edit(period),
              trailing: IconButton(
                tooltip: l.delete,
                onPressed: busy ? null : () => remove(period),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
      ],
    );
  }
}

// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/desktop_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';
import 'desktop_date_picker.dart';

/// Localized cadence label.
String commitmentCadenceLabel(
  BuildContext context,
  NexCadence cadence,
  int every,
) {
  final l = AppLocalizations.of(context)!;
  final label = every == 1
      ? switch (cadence) {
          NexCadence.hours => l.cadenceHourly,
          NexCadence.days => l.cadenceDaily,
          NexCadence.weeks => l.cadenceWeekly,
          NexCadence.months => l.cadenceMonthly,
          NexCadence.years => l.cadenceYearly,
        }
      : switch (cadence) {
          NexCadence.hours => l.cadenceEveryHours(every),
          NexCadence.days => l.cadenceEveryDays(every),
          NexCadence.weeks => l.cadenceEveryWeeks(every),
          NexCadence.months => l.cadenceEveryMonths(every),
          NexCadence.years => l.cadenceEveryYears(every),
        };
  return nexDigits(label, persian: l.localeName == 'fa');
}

/// Localized weekday metadata; Persian weeks start on Saturday.
List<({int day, String name, String shortName})> commitmentWeekdays(
  bool isPersian,
) {
  final l = lookupAppLocalizations(Locale(isPersian ? 'fa' : 'en'));
  final days = [
    (day: 1, name: l.weekdayMonday, shortName: l.weekdayMondayShort),
    (day: 2, name: l.weekdayTuesday, shortName: l.weekdayTuesdayShort),
    (day: 3, name: l.weekdayWednesday, shortName: l.weekdayWednesdayShort),
    (day: 4, name: l.weekdayThursday, shortName: l.weekdayThursdayShort),
    (day: 5, name: l.weekdayFriday, shortName: l.weekdayFridayShort),
    (day: 6, name: l.weekdaySaturday, shortName: l.weekdaySaturdayShort),
    (day: 7, name: l.weekdaySunday, shortName: l.weekdaySundayShort),
  ];
  return isPersian ? [...days.skip(5), ...days.take(5)] : days;
}

/// List and editor view for recurring commitments.
class NexCommitmentsView extends StatefulWidget {
  const NexCommitmentsView({super.key});

  @override
  State<NexCommitmentsView> createState() => _NexCommitmentsViewState();
}

class _NexCommitmentsViewState extends State<NexCommitmentsView> {
  List<NexCommitment> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  bool _started = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final store = NexScope.of(context).store;
      final list = await store.call<List<NexCommitment>>('commitments');
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markMet(NexCommitment item) async {
    try {
      final store = NexScope.of(context).store;
      await store.call<dynamic>('commitmentMet', {'id': item.id});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _delete(NexCommitment item) async {
    try {
      final store = NexScope.of(context).store;
      await store.call<dynamic>('commitmentDelete', {'id': item.id});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openEditor([NexCommitment? item]) async {
    final panel = NexPanelScope.maybeOf(context);
    final result = await showDialog<NexCommitment>(
      context: context,
      builder: (ctx) {
        final editor = NexCommitmentEditorDialog(existing: item);
        return panel == null
            ? editor
            : NexPanelScope(controller: panel, child: editor);
      },
    );
    if (result != null && mounted) {
      final store = NexScope.of(context).store;
      await store.call<dynamic>('commitmentSave', {'commitment': result});
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // The dialog around this view already carries the title.
              const Spacer(),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.commitmentNew),
                onPressed: () => _openEditor(),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '${l.failed}: $_error',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
        if (_loading && _items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: NexEmptyState(
                icon: Icons.event_repeat_rounded,
                message: l.commitmentEmpty,
                action: TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l.commitmentFirst),
                  onPressed: () => _openEditor(),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final cadenceStr = commitmentCadenceLabel(
                  context,
                  item.cadence,
                  item.every,
                );
                final dueStr = nexDisplayDate(
                  item.dueAt,
                  solar:
                      NexPanelScope.maybeOf(context)?.S.solarCalendar ?? isFa,
                  persian: isFa,
                  time: true,
                );

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        tooltip: l.commitmentCompleted,
                        color: scheme.primary,
                        onPressed: () => _markMet(item),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              textDirection: nexDirectionOf(item.title),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.repeat_rounded,
                                        size: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        cadenceStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dueStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: l.edit,
                        onPressed: () => _openEditor(item),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        tooltip: l.delete,
                        color: scheme.error.withValues(alpha: 0.8),
                        onPressed: () => _delete(item),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Dialog editor for creating or editing a [NexCommitment].
class NexCommitmentEditorDialog extends StatefulWidget {
  const NexCommitmentEditorDialog({super.key, this.existing});
  final NexCommitment? existing;

  @override
  State<NexCommitmentEditorDialog> createState() =>
      _NexCommitmentEditorDialogState();
}

class _NexCommitmentEditorDialogState extends State<NexCommitmentEditorDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late NexCadence _cadence = widget.existing?.cadence ?? NexCadence.days;
  late int _every = widget.existing?.every ?? 1;
  late DateTime _dueAt =
      widget.existing?.dueAt ?? DateTime.now().add(const Duration(hours: 1));
  late final Set<int> _selectedWeekdays =
      widget.existing?.weekdays.toSet() ?? {};
  late bool _notify = widget.existing?.notify ?? true;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now().toUtc();
    final details = <String, dynamic>{
      ...?widget.existing?.details,
      if (_cadence == NexCadence.weeks) 'weekdays': _selectedWeekdays.toList(),
    };

    final base =
        widget.existing ??
        NexCommitment(
          id: widget.existing?.id ?? newUuidV7(),
          title: title,
          cadence: _cadence,
          every: _every,
          dueAt: _dueAt,
          createdAt: widget.existing?.createdAt ?? now,
          updatedAt: now,
          notify: _notify,
          rev: (widget.existing?.rev ?? 0) + 1,
          details: details,
        );
    final commitment = widget.existing == null
        ? base
        : base.copyWith(
            title: title,
            cadence: _cadence,
            every: _every,
            dueAt: _dueAt,
            updatedAt: now,
            notify: _notify,
            details: details,
          );

    Navigator.pop(context, commitment);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final weekdays = commitmentWeekdays(isFa);

    return NexAlertDialog(
      title: Text(
        widget.existing == null ? l.commitmentNew : l.commitmentEdit,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              textDirection: nexDirectionOf(_titleController.text),
              decoration: InputDecoration(
                labelText: l.commitmentTitle,
                hintText: l.commitmentTitleHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.customDateTime),
              subtitle: Text(
                nexDisplayDate(
                  _dueAt,
                  solar:
                      NexPanelScope.maybeOf(context)?.S.solarCalendar ?? isFa,
                  persian: isFa,
                  time: true,
                ),
              ),
              onTap: () async {
                final day = await showDesktopDatePicker(
                  context,
                  initialDate: _dueAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  solar:
                      NexPanelScope.maybeOf(context)?.S.solarCalendar ?? isFa,
                );
                if (day == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_dueAt),
                );
                if (time == null || !mounted) return;
                setState(
                  () => _dueAt = DateTime(
                    day.year,
                    day.month,
                    day.day,
                    time.hour,
                    time.minute,
                  ),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<NexCadence>(
                    style: desktopDropdownStyle(context),
                    isDense: true,
                    borderRadius: nexDropdownRadius,
                    dropdownColor: nexDropdownColor(context),
                    initialValue: _cadence,
                    decoration: InputDecoration(
                      labelText: l.commitmentCadence,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: NexCadence.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(commitmentCadenceLabel(context, c, 1)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _cadence = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: '$_every',
                    decoration: InputDecoration(
                      labelText: l.commitmentEvery,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) _every = n;
                    },
                  ),
                ),
              ],
            ),
            if (_cadence == NexCadence.weeks) ...[
              const SizedBox(height: 14),
              Text(
                l.commitmentWeekdays,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: weekdays.map((w) {
                  final isSelected = _selectedWeekdays.contains(w.day);
                  return FilterChip(
                    label: Text(w.shortName),
                    selected: isSelected,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedWeekdays.add(w.day);
                        } else {
                          _selectedWeekdays.remove(w.day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            NexSwitchTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.commitmentNotification),
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.discard),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

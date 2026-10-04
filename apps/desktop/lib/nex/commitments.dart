// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';

/// Localized cadence label.
String commitmentCadenceLabel(BuildContext context, NexCadence cadence, int every) {
  final isFa = Localizations.localeOf(context).languageCode == 'fa';
  if (isFa) {
    if (every == 1) {
      return switch (cadence) {
        NexCadence.hours => 'هر ساعت',
        NexCadence.days => 'روزانه',
        NexCadence.weeks => 'هفتگی',
        NexCadence.months => 'ماهانه',
        NexCadence.years => 'سالانه',
      };
    }
    final unit = switch (cadence) {
      NexCadence.hours => 'ساعت',
      NexCadence.days => 'روز',
      NexCadence.weeks => 'هفته',
      NexCadence.months => 'ماه',
      NexCadence.years => 'سال',
    };
    return nexDigits('هر $every $unit', persian: true);
  } else {
    if (every == 1) {
      return switch (cadence) {
        NexCadence.hours => 'Hourly',
        NexCadence.days => 'Daily',
        NexCadence.weeks => 'Weekly',
        NexCadence.months => 'Monthly',
        NexCadence.years => 'Yearly',
      };
    }
    final unit = switch (cadence) {
      NexCadence.hours => 'hours',
      NexCadence.days => 'days',
      NexCadence.weeks => 'weeks',
      NexCadence.months => 'months',
      NexCadence.years => 'years',
    };
    return 'Every $every $unit';
  }
}

/// Weekday metadata for the weekday selector.
/// In Persian, Saturday is the first day of the week.
List<({int day, String name, String shortName})> commitmentWeekdays(bool isPersian) {
  if (isPersian) {
    return const [
      (day: 6, name: 'شنبه', shortName: 'ش'),
      (day: 7, name: 'یکشنبه', shortName: 'ی'),
      (day: 1, name: 'دوشنبه', shortName: 'د'),
      (day: 2, name: 'سه‌شنبه', shortName: 'س'),
      (day: 3, name: 'چهارشنبه', shortName: 'چ'),
      (day: 4, name: 'پنج‌شنبه', shortName: 'پ'),
      (day: 5, name: 'جمعه', shortName: 'ج'),
    ];
  } else {
    return const [
      (day: 1, name: 'Monday', shortName: 'M'),
      (day: 2, name: 'Tuesday', shortName: 'T'),
      (day: 3, name: 'Wednesday', shortName: 'W'),
      (day: 4, name: 'Thursday', shortName: 'T'),
      (day: 5, name: 'Friday', shortName: 'F'),
      (day: 6, name: 'Saturday', shortName: 'S'),
      (day: 7, name: 'Sunday', shortName: 'S'),
    ];
  }
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
  void initState() {
    super.initState();
    _load();
  }

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
    final result = await showDialog<NexCommitment>(
      context: context,
      builder: (ctx) => NexCommitmentEditorDialog(existing: item),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.event_repeat_rounded, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFa ? 'تعهدات و موارد تکرارشونده' : 'Commitments & Cadences',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(isFa ? 'تعهد جدید' : 'New Commitment'),
                onPressed: () => _openEditor(),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('${l.failed}: $_error', style: TextStyle(color: scheme.error, fontSize: 12)),
          ),
        if (_loading && _items.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: NexEmptyState(
                icon: Icons.event_repeat_rounded,
                message: isFa ? 'هیچ تعهد یا وظیفه تکرارشونده‌ای ثبت نشده است.' : 'No commitments recorded yet.',
                action: TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(isFa ? 'افزودن اولین تعهد' : 'Add First Commitment'),
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
                final cadenceStr = commitmentCadenceLabel(context, item.cadence, item.every);
                final dueStr = nexDisplayDate(item.dueAt, solar: isFa, persian: isFa, time: true);

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
                        tooltip: isFa ? 'انجام شد' : 'Mark completed',
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
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.repeat_rounded, size: 12, color: scheme.onSurfaceVariant),
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
                                Icon(Icons.schedule_rounded, size: 12, color: scheme.onSurfaceVariant),
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
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
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
  State<NexCommitmentEditorDialog> createState() => _NexCommitmentEditorDialogState();
}

class _NexCommitmentEditorDialogState extends State<NexCommitmentEditorDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late NexCadence _cadence = widget.existing?.cadence ?? NexCadence.days;
  late int _every = widget.existing?.every ?? 1;
  late final DateTime _dueAt = widget.existing?.dueAt ?? DateTime.now().add(const Duration(hours: 1));
  late final Set<int> _selectedWeekdays = widget.existing?.weekdays.toSet() ?? {};
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
      if (_cadence == NexCadence.weeks && _selectedWeekdays.isNotEmpty)
        'weekdays': _selectedWeekdays.toList(),
    };

    final commitment = NexCommitment(
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

    Navigator.pop(context, commitment);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFa = Localizations.localeOf(context).languageCode == 'fa';
    final weekdays = commitmentWeekdays(isFa);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existing == null
            ? (isFa ? 'تعهد جدید' : 'New Commitment')
            : (isFa ? 'ویرایش تعهد' : 'Edit Commitment'),
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
                labelText: isFa ? 'عنوان تعهد' : 'Title',
                hintText: isFa ? 'مثال: پرداخت قبض، مصرف دارو...' : 'e.g., Pay rent, Take medicine...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<NexCadence>(
                    initialValue: _cadence,
                    decoration: InputDecoration(
                      labelText: isFa ? 'بازه زمانی' : 'Cadence',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: NexCadence.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(commitmentCadenceLabel(context, c, 1)),
                            ))
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
                      labelText: isFa ? 'هر' : 'Every',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                isFa ? 'روزهای هفته:' : 'Weekdays:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(isFa ? 'اعلان یادآوری' : 'Notification'),
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
        FilledButton(
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}

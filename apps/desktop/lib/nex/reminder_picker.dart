// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Reminder picker dialog with Android parity quick choices and repeat options.
library;

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';

import '../l10n/app_localizations.dart';

/// Shows a dialog to pick or clear a note reminder.
Future<void> showReminderPicker(
  BuildContext context, {
  required Note note,
  required Future<void> Function(DateTime? dueAt, NoteRepeat repeat) onSave,
}) {
  return showDialog(
    context: context,
    builder: (context) => _ReminderPickerDialog(note: note, onSave: onSave),
  );
}

class _ReminderPickerDialog extends StatefulWidget {
  const _ReminderPickerDialog({required this.note, required this.onSave});

  final Note note;
  final Future<void> Function(DateTime? dueAt, NoteRepeat repeat) onSave;

  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  DateTime? _selectedDue;
  late NoteRepeat _repeat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDue = widget.note.dueAt;
    _repeat = widget.note.dueRepeat;
  }

  void _pickLaterToday() {
    final now = DateTime.now();
    // Later today: at least 3 hours from now, or 18:00 / 21:00
    DateTime candidate;
    if (now.hour < 15) {
      candidate = DateTime(now.year, now.month, now.day, 18, 0);
    } else if (now.hour < 19) {
      candidate = DateTime(now.year, now.month, now.day, 21, 0);
    } else {
      candidate = now.add(const Duration(hours: 3));
    }
    setState(() => _selectedDue = candidate);
  }

  void _pickTomorrowMorning() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    setState(() {
      _selectedDue = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    });
  }

  Future<void> _pickCustomDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedDue ?? now.add(const Duration(hours: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDue = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _apply(DateTime? due, NoteRepeat repeat) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(due, repeat);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final theme = Theme.of(context);

    String formatDue(DateTime dt) {
      final dateStr = nexDisplayDate(dt, solar: fa, persian: fa);
      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      final formattedTime = fa ? nexDigits(timeStr, persian: true) : timeStr;
      return '$dateStr $formattedTime';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l.remind,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedDue != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        formatDue(_selectedDue!),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Quick choice chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wb_twilight, size: 16),
                  label: Text(l.laterToday),
                  onPressed: _pickLaterToday,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                  label: Text(l.tomorrowMorning),
                  onPressed: _pickTomorrowMorning,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(l.customDateTime),
                  onPressed: _pickCustomDateTime,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Repeat cadence selector
            Text(
              l.repeat,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NoteRepeat>(
              initialValue: _repeat,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: NoteRepeat.once,
                  child: Text(l.noRepeat),
                ),
                DropdownMenuItem(
                  value: NoteRepeat.daily,
                  child: Text(l.repeatDaily),
                ),
                DropdownMenuItem(
                  value: NoteRepeat.weekly,
                  child: Text(l.repeatWeekly),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _repeat = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.note.dueAt != null)
          TextButton(
            onPressed: _saving ? null : () => _apply(null, NoteRepeat.once),
            child: Text(
              l.clearReminder,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
        FilledButton(
          onPressed: _saving || _selectedDue == null
              ? null
              : () => _apply(_selectedDue, _repeat),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(l.reminderSet),
        ),
      ],
    );
  }
}

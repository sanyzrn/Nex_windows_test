import 'package:nex_ui/nex_ui.dart';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import '../l10n/app_localizations.dart';
import '../l10n/desktop_format.dart';

/// Return a local civil date in either calendar; stored reminder UTC is unchanged.
Future<DateTime?> showDesktopDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required bool solar,
  bool useRootNavigator = true,
}) {
  if (!solar) {
    return showDatePicker(
      context: context,
      useRootNavigator: useRootNavigator,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  return showDialog<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (_) => _SolarDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _SolarDatePicker extends StatefulWidget {
  const _SolarDatePicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime initialDate, firstDate, lastDate;
  @override
  State<_SolarDatePicker> createState() => _SolarDatePickerState();
}

class _SolarDatePickerState extends State<_SolarDatePicker> {
  late DateTime selected = DateUtils.dateOnly(widget.initialDate);
  late final first = DateUtils.dateOnly(widget.firstDate);
  late final last = DateUtils.dateOnly(widget.lastDate);

  void select(int year, int month, int day) {
    var value = nexGregorianDate(
      year,
      month,
      day.clamp(1, nexPersianMonthDays(year, month)),
    );
    if (value.isBefore(first)) value = first;
    if (value.isAfter(last)) value = last;
    setState(() => selected = value);
  }

  bool inRange(int year, int month, int day) {
    final date = nexGregorianDate(year, month, day);
    return !date.isBefore(first) && !date.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final date = nexPersianDate(selected);
    final firstYear = nexPersianDate(first).year;
    final lastYear = nexPersianDate(last).year;
    final months = fa ? nexPersianMonthNames : nexPersianMonthNamesLatin;
    Widget field(
      String id,
      String label,
      int value,
      List<int> values,
      String Function(int) text,
    ) => SizedBox(
      width:
          (id == 'month'
              ? 160
              : id == 'year'
              ? 120
              : 90) *
          MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
      child: DropdownButtonFormField<int>(
        borderRadius: nexDropdownRadius,
        dropdownColor: nexDropdownColor(context),
        key: ValueKey('solar-$id-$value'),
        initialValue: value,
        isExpanded: true,
        itemHeight: null,
        isDense: false,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(text(v))),
        ],
        onChanged: (v) {
          if (v == null) return;
          select(
            id == 'year' ? v : date.year,
            id == 'month' ? v : date.month,
            id == 'day' ? v : date.day,
          );
        },
      ),
    );
    return AlertDialog(
      key: const ValueKey('solar-date-picker'),
      title: Text(material.datePickerHelpText),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nexDisplayDate(selected, solar: true, persian: fa),
                key: const ValueKey('solar-selected-date'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  field('year', l.calendarYear, date.year, [
                    for (var y = firstYear; y <= lastYear; y++) y,
                  ], (v) => desktopDigits(context, v)),
                  field('month', l.calendarMonth, date.month, [
                    for (var m = 1; m <= 12; m++)
                      if (inRange(date.year, m, 1) ||
                          inRange(
                            date.year,
                            m,
                            nexPersianMonthDays(date.year, m),
                          ) ||
                          (m == date.month))
                        m,
                  ], (v) => months[v - 1]),
                  field('day', l.calendarDay, date.day, [
                    for (
                      var d = 1;
                      d <= nexPersianMonthDays(date.year, date.month);
                      d++
                    )
                      if (inRange(date.year, date.month, d)) d,
                  ], (v) => desktopDigits(context, v)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}

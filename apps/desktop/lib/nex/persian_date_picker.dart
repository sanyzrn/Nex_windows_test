import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';

/// A Solar Hijri date picker with real Persian months and Saturday-first weeks.
/// Returns a normal local Gregorian DateTime for storage and interoperability.
Future<DateTime?> showNexSolarDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showDialog<DateTime>(
  context: context,
  builder: (context) => NexSolarDatePickerDialog(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

class NexSolarDatePickerDialog extends StatefulWidget {
  const NexSolarDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<NexSolarDatePickerDialog> createState() => _NexSolarDatePickerState();
}

class _NexSolarDatePickerState extends State<NexSolarDatePickerDialog> {
  late DateTime selected;
  late int year;
  late int month;

  @override
  void initState() {
    super.initState();
    selected = DateUtils.dateOnly(widget.initialDate);
    final solar = nexPersianDate(selected);
    year = solar.year;
    month = solar.month;
  }

  DateTime _first(int y, int m) => nexGregorianDate(y, m, 1);
  bool _inRange(DateTime day) {
    final value = DateUtils.dateOnly(day);
    return !value.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
        !value.isAfter(DateUtils.dateOnly(widget.lastDate));
  }

  bool _canShow(int y, int m) {
    final start = _first(y, m);
    final end = nexGregorianDate(y, m, nexPersianMonthDays(y, m));
    return !end.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
        !start.isAfter(DateUtils.dateOnly(widget.lastDate));
  }

  void _move(int step) {
    var nextYear = year;
    var nextMonth = month + step;
    if (nextMonth == 0) {
      nextYear--;
      nextMonth = 12;
    } else if (nextMonth == 13) {
      nextYear++;
      nextMonth = 1;
    }
    if (_canShow(nextYear, nextMonth)) {
      setState(() {
        year = nextYear;
        month = nextMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final material = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final names = fa ? nexPersianMonthNames : nexPersianMonthNamesLatin;
    final days = nexPersianMonthDays(year, month);
    final first = _first(year, month);
    // Dart Monday=1…Sunday=7. Persian weeks start on Saturday.
    final offset = (first.weekday + 1) % 7;
    final minimum = nexPersianDate(widget.firstDate).year;
    final maximum = nexPersianDate(widget.lastDate).year;
    String numerals(int number) => nexDigits('$number', persian: fa);
    const weekdaysFa = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    const weekdaysEn = ['Sa', 'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr'];

    return AlertDialog(
      title: Text(fa ? 'انتخاب تاریخ شمسی' : 'Solar calendar'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: fa ? 'ماه قبل' : 'Previous month',
                  onPressed: _canShow(month == 1 ? year - 1 : year,
                          month == 1 ? 12 : month - 1)
                      ? () => _move(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    names[month - 1],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButton<int>(
                  value: year,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (var y = minimum; y <= maximum; y++)
                      DropdownMenuItem(value: y, child: Text(numerals(y))),
                  ],
                  onChanged: (y) {
                    if (y == null) return;
                    var m = month;
                    if (!_canShow(y, m)) {
                      m = y == minimum
                          ? nexPersianDate(widget.firstDate).month
                          : nexPersianDate(widget.lastDate).month;
                    }
                    setState(() { year = y; month = m; });
                  },
                ),
                IconButton(
                  tooltip: fa ? 'ماه بعد' : 'Next month',
                  onPressed: _canShow(month == 12 ? year + 1 : year,
                          month == 12 ? 1 : month + 1)
                      ? () => _move(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    for (final day in fa ? weekdaysFa : weekdaysEn)
                      Expanded(child: Center(
                        child: Text(day, style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12,
                        )),
                      )),
                  ]),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 7,
                    childAspectRatio: 1.08,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < offset; i++)
                        const SizedBox.shrink(),
                      for (var d = 1; d <= days; d++)
                        Builder(builder: (context) {
                          final date = nexGregorianDate(year, month, d);
                          final active = DateUtils.isSameDay(selected, date);
                          return Padding(
                            padding: const EdgeInsets.all(1),
                            child: TextButton(
                              onPressed: _inRange(date)
                                  ? () => setState(() => selected = date)
                                  : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: active
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                                backgroundColor: active
                                    ? scheme.primary
                                    : null,
                                shape: const CircleBorder(),
                              ),
                              child: Text(numerals(d)),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(selected),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/desktop_format.dart';

class DesktopCycleCalendar extends StatelessWidget {
  const DesktopCycleCalendar({
    super.key,
    required this.today,
    required this.selected,
    required this.month,
    required this.solar,
    required this.periods,
    required this.logs,
    required this.onSelect,
    required this.onMonth,
  });
  final DateTime selected, month, today;
  final bool solar;
  final List<CyclePeriod> periods;
  final List<CycleDayLog> logs;
  final ValueChanged<DateTime> onSelect, onMonth;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fa = l.localeName == 'fa';
    final scheme = Theme.of(context).colorScheme;
    final j = nexPersianDate(month);
    final first = solar
        ? nexGregorianDate(j.year, j.month, 1)
        : DateTime(month.year, month.month);
    final days = solar
        ? nexPersianMonthDays(j.year, j.month)
        : DateUtils.getDaysInMonth(month.year, month.month);
    final offset =
        (first.weekday - (fa ? DateTime.saturday : DateTime.monday) + 7) % 7;
    final title = solar
        ? '${(fa ? nexPersianMonthNames : nexPersianMonthNamesLatin)[j.month - 1]} ${desktopDigits(context, j.year)}'
        : desktopDigits(
            context,
            MaterialLocalizations.of(context).formatMonthYear(first),
          );
    void move(int delta) {
      if (solar) {
        final shifted = j.year * 12 + j.month - 1 + delta;
        onMonth(nexGregorianDate(shifted ~/ 12, shifted % 12 + 1, 1));
      } else {
        onMonth(DateTime(month.year, month.month + delta));
      }
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l.previousPage,
              onPressed: () => move(-1),
              icon: const Icon(Icons.navigate_before),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: l.nextPage,
              onPressed: () => move(1),
              icon: const Icon(Icons.navigate_next),
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    MaterialLocalizations.of(
                      context,
                    ).narrowWeekdays[(i + (fa ? 6 : 1)) % 7],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: NexSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 52,
          ),
          itemCount: offset + days,
          itemBuilder: (context, index) {
            final day = index - offset + 1;
            if (day < 1) return const SizedBox.shrink();
            final date = first.add(Duration(days: day - 1));
            final civil = CycleDate.of(date);
            final bleeding = periods.any(
              (p) =>
                  p.contains(civil) &&
                  (!p.isOpen || !civil.isAfter(CycleDate.of(today))),
            );
            final logged = logs.any((log) => log.day == civil);
            final active = DateUtils.isSameDay(date, selected);
            return Padding(
              padding: const EdgeInsets.all(2),
              child: Semantics(
                selected: active,
                label: nexDisplayDate(date, solar: solar, persian: fa),
                child: Material(
                  color: active
                      ? scheme.primaryContainer
                      : bleeding
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(NexRadius.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(NexRadius.sm),
                    onTap: date.isAfter(DateUtils.dateOnly(today))
                        ? null
                        : () => onSelect(date),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          desktopDigits(context, day),
                          style: TextStyle(
                            color: active
                                ? scheme.onPrimaryContainer
                                : bleeding
                                ? scheme.onSecondaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                        if (logged)
                          Icon(Icons.circle, size: 4, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

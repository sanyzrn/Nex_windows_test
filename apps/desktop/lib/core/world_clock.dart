import 'package:timezone/timezone.dart' as tz;

/// Offsets compare wall-clock zones at one instant, never epoch timestamps.
({String time, Duration offset, int day}) worldClock(
  DateTime instant,
  tz.Location target, {
  tz.Location? localZone,
}) {
  final there = tz.TZDateTime.from(instant, target);
  final DateTime here = localZone == null
      ? instant.toLocal()
      : tz.TZDateTime.from(instant, localZone);
  final day = DateTime.utc(
    there.year,
    there.month,
    there.day,
  ).difference(DateTime.utc(here.year, here.month, here.day)).inDays;
  return (
    time:
        '${there.hour.toString().padLeft(2, '0')}:${there.minute.toString().padLeft(2, '0')}',
    offset: there.timeZoneOffset - here.timeZoneOffset,
    day: day,
  );
}

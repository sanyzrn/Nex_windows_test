/// Calendar-day windows for Library search, in the machine's local timezone.
enum LibraryDatePreset {
  any,
  today,
  last7Days,
  last30Days;

  /// SQL uses inclusive bounds. Build both local midnights before converting
  /// to UTC, so a daylight-saving change cannot shift the calendar window.
  ({DateTime? from, DateTime? to}) bounds(DateTime now) {
    if (this == any) return (from: null, to: null);
    final local = now.toLocal();
    final days = switch (this) {
      last7Days => 7,
      last30Days => 30,
      _ => 1,
    };
    return (
      from: DateTime(local.year, local.month, local.day - days + 1).toUtc(),
      to: DateTime(
        local.year,
        local.month,
        local.day + 1,
      ).toUtc().subtract(const Duration(microseconds: 1)),
    );
  }
}

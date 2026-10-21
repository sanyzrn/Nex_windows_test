import 'package:flutter_test/flutter_test.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/core/backup_shell.dart';

void main() {
  test('backup preflight accepts compatible settings and future fields', () {
    validateBackupShell(null);
    validateBackupShell({
      'theme': 'dark',
      'language': 'fa',
      'startup': true,
      'solarCalendar': true,
      'uiScale': 1.5,
      'monitor': 0,
      'accent': '#123456',
      'accentSeed': '#FF123456',
      'recentColors': ['#123456', '#FF123456'],
      'apps': [
        {'id': 'app-1', 'name': 'Example', 'path': 'example.exe', 'icon': null},
      ],
      'windowBounds': {'x': -100, 'y': 10, 'w': 900, 'h': 700},
      'dock': ['library'],
      'more': [],
      'futureSetting': {'version': 2},
      'paste': null,
    });
    validateBackupShell({
      'windowBounds': [-100, 10, 900, 700],
    });
  });

  test(
    'backup preflight rejects invalid scalar types and non-finite numbers',
    () {
      final invalid = <Object>[
        [],
        'not a settings map',
        {'theme': false},
        {'startup': 'true'},
        {'uiScale': 'large'},
        {'monitor': double.nan},
        {'lastCheck': double.infinity},
        {'dock': 'library'},
        {'accent': '#12345'},
        {'accentSeed': 123456},
      ];
      for (final value in invalid) {
        expect(
          () => validateBackupShell(value),
          throwsFormatException,
          reason: 'Reject malformed settings before installing a library',
        );
      }
    },
  );

  test(
    'backup preflight checks nested colors, launchers and window geometry',
    () {
      final invalid = [
        {
          'recentColors': ['#123456', 'blue'],
        },
        {
          'apps': ['not a launcher'],
        },
        {
          'apps': [
            {'name': 123},
          ],
        },
        {'windowBounds': '900x700'},
        {
          'windowBounds': [0, 0, 900],
        },
        {
          'windowBounds': [0, 0, 900, double.infinity],
        },
        {
          'windowBounds': {'w': '900'},
        },
      ];
      for (final value in invalid) {
        expect(() => validateBackupShell(value), throwsFormatException);
      }
    },
  );

  test('Solar Hijri conversions agree at Nowruz and six-month boundaries', () {
    const anchors = [
      (1399, 1, 1, 2020, 3, 20),
      (1403, 1, 1, 2024, 3, 20),
      (1403, 6, 31, 2024, 9, 21),
      (1403, 7, 1, 2024, 9, 22),
      (1403, 12, 30, 2025, 3, 20),
      (1404, 1, 1, 2025, 3, 21),
    ];
    for (final (year, month, day, gy, gm, gd) in anchors) {
      final civil = DateTime(gy, gm, gd);
      expect(nexGregorianDate(year, month, day), civil);
      expect(nexPersianDate(civil), (year: year, month: month, day: day));
    }
  });

  test(
    'calendar validation distinguishes leap Esfand and invalid month ends',
    () {
      expect(nexPersianMonthDays(1403, 12), 30);
      expect(nexPersianMonthDays(1404, 12), 29);
      expect(nexPersianMonthDays(1404, 6), 31);
      expect(nexPersianMonthDays(1404, 7), 30);
      for (final (month, day) in [(0, 1), (13, 1), (1, 0), (7, 31), (12, 30)]) {
        expect(() => nexGregorianDate(1404, month, day), throwsRangeError);
      }
    },
  );

  test(
    'date display keeps local time and independently selects digits/calendar',
    () {
      final civil = DateTime(2025, 3, 21, 9, 7, 8);
      expect(nexDisplayDate(civil), '2025/03/21');
      expect(nexDisplayDate(civil, persian: true), '۲۰۲۵/۰۳/۲۱');
      expect(nexDisplayDate(civil, solar: true), '1404/01/01');
      expect(
        nexDisplayDate(
          civil,
          solar: true,
          persian: true,
          time: true,
          seconds: true,
        ),
        '۱۴۰۴/۰۱/۰۱  ۰۹:۰۷:۰۸',
      );
    },
  );
}

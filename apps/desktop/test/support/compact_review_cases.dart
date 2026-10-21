import 'package:flutter/material.dart';
import 'review_fixture.dart';

/// A4: all compact flows, both languages and themes, deterministic seeded media.
const compactReviewTargets = [
  'note',
  'timeline',
  'readerText',
  'readerChecklist',
  'readerLink',
  'readerPhoto',
  'more',
  'assistant',
  'settings',
  'displaySettings',
  'appearance',
  'shortcutSettings',
  'backup',
  'toolsSettings',
  'aboutSettings',
  'aiSettings',
  'providerSettings',
  'releaseNotes',
  'solarCalendar',
];
final compactReviewShots = [
  for (final target in compactReviewTargets)
    for (final locale in ['en', 'fa'])
      for (final theme in ['light', 'dark'])
        ReviewShot(
          'compact_${target}_460_760_${locale}_$theme',
          mode: 'window',
          size: const Size(460, 760),
          target: target,
          locale: locale,
          theme: theme,
        ),
];

import 'package:flutter/material.dart';
import 'review_fixture.dart';

/// Full A3 layout contract; pixel references are limited to reproduced failures
/// and representative scaled controls so the review suite stays manageable.
final textScaleShots = <ReviewShot>[
  for (final size in [
    const Size(380, 520),
    const Size(460, 760),
    const Size(700, 900),
    const Size(1200, 800),
  ])
    for (final scale in [1.0, 1.5, 2.0])
      for (final locale in ['en', 'fa'])
        for (final theme in ['light', 'dark'])
          for (final target in [
            'note',
            'timeline',
            'timelineEmpty',
            'reader',
            'assistant',
            'more',
            'settings',
          ])
            ReviewShot(
              '${target}_${size.width.toInt()}_${size.height.toInt()}_${locale}_${theme}_scale$scale',
              mode: 'window',
              size: size,
              textScale: scale,
              locale: locale,
              theme: theme,
              target: target == 'timelineEmpty' ? 'timeline' : target,
              notes: target == 'timelineEmpty' ? 0 : 8,
            ),
];

final textScaleReviewShots = textScaleShots.where(
  (shot) =>
      (shot.notes == 0 && shot.size.width == 380) ||
      (shot.textScale == 2 &&
          (shot.size.width == 380 ||
              ((shot.size.width == 460 || shot.size.width == 1200) &&
                  (shot.target == 'note' || shot.target == 'reader')))),
);

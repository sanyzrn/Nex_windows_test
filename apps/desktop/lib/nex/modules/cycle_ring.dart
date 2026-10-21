import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/desktop_format.dart';
import 'cycle_labels.dart';

/// Android's inspectable phase ring, adapted to pointer and keyboard input.
/// Estimates use the same predictor; inspecting a day never writes a log.
class DesktopCycleRing extends StatefulWidget {
  const DesktopCycleRing({super.key, required this.prediction});
  final CyclePrediction prediction;
  @override
  State<DesktopCycleRing> createState() => _DesktopCycleRingState();
}

class _DesktopCycleRingState extends State<DesktopCycleRing> {
  int? picked;
  @override
  void didUpdateWidget(DesktopCycleRing old) {
    super.didUpdateWidget(old);
    if (old.prediction.lastStart != widget.prediction.lastStart) picked = null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prediction;
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final length = math.max(p.averageCycle, p.cycleDay);
    final index = picked ?? p.cycleDay - 1;
    final day = p.lastStart.addDays(index);
    final stage = p.stageOn(day);
    final size = (200 * MediaQuery.textScalerOf(context).scale(1)).clamp(
      200.0,
      300.0,
    );
    final label = l.cycleDay(desktopDigits(context, index + 1));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$label · ${cycleStageLabel(l, stage)}',
          child: SizedBox.square(
            dimension: size,
            child: GestureDetector(
              onTapUp: (event) {
                final offset = event.localPosition - Offset(size / 2, size / 2);
                if (offset.distance < size * .28) {
                  setState(() => picked = null);
                  return;
                }
                final angle =
                    (math.atan2(offset.dy, offset.dx) + math.pi * 2.5) %
                    (math.pi * 2);
                setState(
                  () => picked = (angle / (math.pi * 2) * length).floor().clamp(
                    0,
                    length - 1,
                  ),
                );
              },
              child: CustomPaint(
                painter: _PhaseRing(p, length, index, scheme),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NexSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: NexSpacing.xs),
                        Text(
                          cycleStageLabel(l, stage),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: size,
          child: Slider(
            key: const ValueKey('cycle-inspect-day'),
            min: 0,
            max: (length - 1).toDouble(),
            divisions: length - 1,
            value: index.toDouble(),
            label: label,
            semanticFormatterCallback: (value) =>
                l.cycleDay(desktopDigits(context, value.round() + 1)),
            onChanged: (value) => setState(() => picked = value.round()),
          ),
        ),
        if (picked != null)
          TextButton(
            onPressed: () => setState(() => picked = null),
            child: Text(l.todayTitle),
          ),
      ],
    );
  }
}

class _PhaseRing extends CustomPainter {
  _PhaseRing(this.prediction, this.length, this.selected, this.scheme);
  final CyclePrediction prediction;
  final int length, selected;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final step = math.pi * 2 / length;
    for (var i = 0; i < length; i++) {
      paint.color = switch (prediction.stageOn(
        prediction.lastStart.addDays(i),
      )) {
        CycleStage.period => scheme.error,
        CycleStage.fertile => scheme.tertiary,
        CycleStage.follicular || CycleStage.luteal => scheme.secondary,
      };
      canvas.drawArc(rect, -math.pi / 2 + i * step, step * .65, false, paint);
    }
    final angle = -math.pi / 2 + (selected + .325) * step;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(point, 9, Paint()..color = scheme.surface);
    canvas.drawCircle(point, 5, Paint()..color = scheme.onSurface);
  }

  @override
  bool shouldRepaint(_PhaseRing old) =>
      old.prediction != prediction ||
      old.selected != selected ||
      old.scheme != scheme;
}

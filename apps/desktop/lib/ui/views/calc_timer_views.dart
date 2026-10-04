import '../../l10n/utility_strings.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../flyout.dart';
import '../widgets.dart';

// ================= Calculator =================

class CalcView extends StatefulWidget {
  const CalcView({super.key});

  @override
  State<CalcView> createState() => _CalcViewState();
}

class _CalcViewState extends State<CalcView> {
  final _input = TextEditingController();
  String _out = '0';

  void _eval() {
    final v = calcEval(_input.text);
    setState(() {
      _out = v == null ? (_input.text.isEmpty ? '0' : '…') : fmtCalc(v);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          onBack: () => _backToMore(c),
        ),
        Field(
          controller: _input,
          hint: utilityLabel(context, 'utility20'),
          autofocusDelayed: true,
          onChanged: (_) => _eval(),
          onSubmit: (_) {
            final v = calcEval(_input.text);
            if (v != null) {
              setState(() {
                _input.text = fmtCalcRaw(v);
                _out = fmtCalc(v);
              });
              c.copy(fmtCalcRaw(v));
            }
          },
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              final v = calcEval(_input.text);
              if (v != null) c.copy(fmtCalcRaw(v));
            },
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              constraints: const BoxConstraints(minHeight: 40),
              child: Text(
                _out,
                style: TextStyle(
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                  fontFamilyFallback: const ['Segoe UI'],
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: p.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _backToMore(PanelController c) {
    c.backToTools();
  }
}

/// Tiny recursive-descent evaluator, faithful to the original's
/// `Function("return (...)")` semantics (with ^ meaning power).
double? calcEval(String src) {
  var s = src.trim().replaceAll(',', '');
  if (s.isEmpty) return null;
  if (!RegExp(r'^[\d\s+\-*/().%^eE]+$').hasMatch(s)) return null;
  try {
    final p = _CalcParser(s);
    final v = p.expression();
    if (!p.atEnd) return null;
    if (v.isNaN || v.isInfinite) return null;
    return double.parse(v.toStringAsPrecision(12));
  } catch (_) {
    return null;
  }
}

class _CalcParser {
  _CalcParser(this.s);

  final String s;
  int _i = 0;

  bool get atEnd => _i >= s.length;

  double expression() {
    var v = term();
    while (true) {
      _ws();
      if (_peek == '+' || _peek == '-') {
        final op = s[_i++];
        final r = term();
        v = op == '+' ? v + r : v - r;
      } else {
        return v;
      }
    }
  }

  double term() {
    var v = unary();
    while (true) {
      _ws();
      if (_peek == '*' || _peek == '/' || _peek == '%') {
        final op = s[_i++];
        final r = unary();
        if (op == '*') {
          v *= r;
        } else if (op == '/') {
          v /= r;
        } else {
          v = v.remainder(r);
        }
      } else {
        return v;
      }
    }
  }

  double unary() {
    _ws();
    if (_peek == '-' || _peek == '+') {
      final op = s[_i++];
      final v = unary();
      return op == '-' ? -v : v;
    }
    return power();
  }

  double power() {
    final base = atom();
    _ws();
    if (_peek == '^') {
      _i++;
      final exp = unary(); // right associative
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  double atom() {
    _ws();
    if (_peek == '(') {
      _i++;
      final v = expression();
      _ws();
      if (_peek != ')') throw const FormatException('missing )');
      _i++;
      return v;
    }
    final start = _i;
    while (_i < s.length &&
        (RegExp(r'[\d.eE]').hasMatch(s[_i]) ||
            (s[_i] == '+' || s[_i] == '-') &&
                _i > start &&
                (s[_i - 1] == 'e' || s[_i - 1] == 'E'))) {
      _i++;
    }
    if (_i == start) throw const FormatException('number expected');
    final v = double.parse(s.substring(start, _i));
    if (v.isNaN) throw const FormatException('nan');
    return v;
  }

  void _ws() {
    while (_i < s.length && s[_i] == ' ') {
      _i++;
    }
  }

  String? get _peek => _i < s.length ? s[_i] : null;
}

String fmtCalcRaw(double v) {
  final p = double.parse(v.toStringAsPrecision(12));
  if (p == p.roundToDouble() && p.abs() < 1e15) {
    return p.toInt().toString();
  }
  return p.toString();
}

String fmtCalc(double v) {
  final raw = fmtCalcRaw(v);
  if (raw.contains('e') || raw.contains('E')) return raw;
  final neg = raw.startsWith('-');
  final body = neg ? raw.substring(1) : raw;
  final dot = body.indexOf('.');
  final intPart = dot < 0 ? body : body.substring(0, dot);
  final frac = dot < 0 ? '' : body.substring(dot);
  final grouped = _group(intPart);
  final fracTrimmed = dot < 0
      ? ''
      : (frac.length > 11 ? frac.substring(0, 11) : frac);
  return '${neg ? '-' : ''}$grouped$fracTrimmed';
}

String _group(String digits) {
  final sb = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) sb.write(',');
    sb.write(digits[i]);
  }
  return sb.toString();
}

// ================= Timer =================

class TimerView extends StatelessWidget {
  const TimerView({super.key});

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          onBack: () => _backToMore(c),
        ),
        Text(
          fmtTimer(c.tLeft),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontFamilyFallback: const ['Segoe UI'],
            fontSize: 44,
            fontWeight: FontWeight.w300,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: p.ink,
          ),
        ),
        Row(
          children: [
            for (final m in [1, 5, 10, 25])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: m == 25 ? 0 : 6),
                  child: Btn(
                    onPressed: () => c.timerPreset(m),
                    child: Text('$m ${utilityLabelForText(context, 'minute')}'),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Btn(
                primary: true,
                onPressed: () => c.timerToggle(),
                child: Text(
                  utilityLabelForText(
                    context,
                    c.tRun != null ? 'Pause' : 'Start',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Btn(
                onPressed: () => c.timerReset(),
                child: Text(utilityLabel(context, 'utility16')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _backToMore(PanelController c) {
    c.backToTools();
  }
}

String fmtTimer(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

// ================= Stopwatch =================

class StopwatchView extends StatelessWidget {
  const StopwatchView({super.key});

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          onBack: () => _backToMore(c),
        ),
        ValueListenableBuilder<String>(
          valueListenable: c.swDisplay,
          builder: (context, txt, _) => Text(
            txt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontFamilyFallback: const ['Segoe UI'],
              fontSize: 44,
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: p.ink,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Btn(
                primary: true,
                onPressed: () => c.swToggle(),
                child: Text(
                  utilityLabelForText(
                    context,
                    c.swTimer != null ? 'Stop' : 'Start',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Btn(
                onPressed: () => c.swLapOrReset(),
                child: Text(
                  utilityLabelForText(
                    context,
                    c.swTimer != null ? 'Lap' : 'Reset',
                  ),
                ),
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: c.swLaps.isEmpty
              ? const SizedBox(height: 6)
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < c.swLaps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ItemRow(
                            plain: true,
                            onTap: () => c.copy(fmtSw(c.swLaps[i])),
                            sub: Text(fmtSw(c.swLaps[i])),
                            child: Text(
                              '${utilityLabelForText(context, 'Lap')} ${c.swLaps.length - i}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _backToMore(PanelController c) {
    c.backToTools();
  }
}

String fmtSw(int ms) =>
    '${(ms ~/ 60000).toString().padLeft(2, '0')}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${((ms ~/ 10) % 100).toString().padLeft(2, '0')}';


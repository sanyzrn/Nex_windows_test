import '../../l10n/app_localizations.dart';
import '../../l10n/utility_strings.dart';
import 'dart:convert';
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
          title: utilityLabel(context, 'utility19'),
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
          title: utilityLabel(context, 'utility21'),
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
          title: utilityLabel(context, 'utility22'),
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

// ================= Text tools =================

class TextToolsView extends StatelessWidget {
  const TextToolsView({super.key});

  static final Map<String, String> _ops = {
    'UPPER': 'upper',
    'lower': 'lower',
    'Title Case': 'title',
    'Sentence': 'sentence',
    'Trim spaces': 'trim',
    'One line': 'oneline',
    'Reverse': 'reverse',
    'Slug': 'slug',
    'Base64 enc': 'b64e',
    'Base64 dec': 'b64d',
    'URL encode': 'urle',
    'URL decode': 'urld',
    'Count': 'count',
  };

  @override
  Widget build(BuildContext context) {
    final (_, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          title: utilityLabel(context, 'utility23'),
          onBack: () => _backToMore(c),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _ops.entries)
              SizedBox(
                width: 84,
                child: _TextToolButton(
                  controller: c,
                  label: e.key,
                  op: e.value,
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

class _TextToolButton extends StatefulWidget {
  const _TextToolButton({
    required this.controller,
    required this.label,
    required this.op,
  });

  final PanelController controller;
  final String label;
  final String op;

  @override
  State<_TextToolButton> createState() => _TextToolButtonState();
}

class _TextToolButtonState extends State<_TextToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final glyph = widget.op == 'count'
        ? '#'
        : (widget.op.startsWith('b64') || widget.op.startsWith('url'))
        ? '⇄'
        : 'Aa';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => _run(widget.controller, widget.op),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: kPop,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(_hover ? 18 : 14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    glyph,
                    style: TextStyle(
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontFamily,
                      fontFamilyFallback: const ['Segoe UI'],
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                utilityLabelForText(context, widget.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                  fontFamilyFallback: const ['Segoe UI'],
                  fontSize: 11,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _run(PanelController c, String op) {
    final t = c.lastClip;
    if (['b64e', 'b64d', 'urle', 'urld', 'count'].contains(op)) {
      if (t.isEmpty) {
        c.toast('Copy some text first');
        return;
      }
      switch (op) {
        case 'count':
          final words = RegExp(r'\S+').allMatches(t.trim()).length;
          c.toast(
            c.message('{words} words · {chars} chars · {lines} lines', {
              'words': '$words',
              'chars': '${t.length}',
              'lines': '${t.split('\n').length}',
            }),
          );
          return;
        case 'b64e':
          c.deliver(base64Encode(utf8.encode(t)));
          return;
        case 'b64d':
          try {
            c.deliver(utf8.decode(base64Decode(t.trim())));
          } catch (_) {
            c.toast('That text can’t be decoded');
          }
          return;
        case 'urle':
          c.deliver(Uri.encodeComponent(t));
          return;
        case 'urld':
          c.deliver(Uri.decodeComponent(t));
          return;
      }
      return;
    }
    final transformed = transformText(t, op);
    if (c.S.paste) {
      c.close();
      c.native.pasteIntoPrevious(transformed);
    } else {
      c.copy(transformed);
      c.toast('Clipboard updated');
    }
  }
}

/// Port of the native transform().
String transformText(String text, String mode) {
  switch (mode) {
    case 'upper':
      return text.toUpperCase();
    case 'lower':
      return text.toLowerCase();
    case 'title':
      return text
          .split(' ')
          .map(
            (w) => w.isEmpty
                ? w
                : w[0].toUpperCase() + w.substring(1).toLowerCase(),
          )
          .join(' ');
    case 'sentence':
      final lower = text.toLowerCase();
      return lower.isEmpty
          ? lower
          : lower[0].toUpperCase() + lower.substring(1);
    case 'trim':
      return text
          .split('\n')
          .map((l) => l.trim().split(RegExp(r'\s+')).join(' '))
          .join('\n')
          .trim();
    case 'oneline':
      return text.split(RegExp(r'\s+')).join(' ').trim();
    case 'reverse':
      return String.fromCharCodes(text.runes.toList().reversed);
    case 'slug':
      final s = text
          .toLowerCase()
          .split('')
          .map((ch) => ch.replaceAll(RegExp('[^a-z0-9]'), '-'))
          .join();
      return s.split('-').where((p) => p.isNotEmpty).join('-');
    default:
      return text;
  }
}

// ================= Password =================

class PasswordView extends StatefulWidget {
  const PasswordView({super.key});

  @override
  State<PasswordView> createState() => _PasswordViewState();
}

class _PasswordViewState extends State<PasswordView> {
  String _pw = '';
  double _len = 16;

  @override
  void initState() {
    super.initState();
    _gen();
  }

  void _gen() {
    const cs =
        'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#\$%&*-_+=?';
    final rnd = math.Random.secure();
    final out = List.generate(
      _len.round(),
      (_) => cs[rnd.nextInt(cs.length)],
    ).join();
    setState(() => _pw = out);
  }

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          title: utilityLabel(context, 'utility24'),
          onBack: () => _backToMore(c),
        ),
        GestureDetector(
          onTap: () => c.copy(_pw, 'Password copied'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _pw,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 14,
                color: p.ink,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Length ${_len.round()}',
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontFamilyFallback: const ['Segoe UI'],
              fontSize: 13,
              color: p.ink,
            ),
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: p.inv,
            thumbColor: p.inv,
            inactiveTrackColor: p.soft2,
            overlayColor: Colors.transparent,
            trackHeight: 3,
          ),
          child: Slider(
            min: 6,
            max: 48,
            value: _len,
            onChanged: (v) {
              _len = v;
              _gen();
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Btn(
                onPressed: _gen,
                child: Text(utilityLabel(context, 'utility17')),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Btn(
                primary: true,
                onPressed: () => c.copy(_pw, 'Password copied'),
                child: Text(utilityLabel(context, 'utility18')),
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

// ================= Units =================

Map<String, List<List<Object>>> _unitTable = {
  'in': [
    ['cm', 2.54],
  ],
  'cm': [
    ['in', 1 / 2.54],
    ['mm', 10],
  ],
  'mm': [
    ['in', 1 / 25.4],
    ['cm', .1],
  ],
  'm': [
    ['ft', 3.28084],
    ['cm', 100],
  ],
  'ft': [
    ['m', .3048],
    ['in', 12],
  ],
  'km': [
    ['mi', .621371],
    ['m', 1000],
  ],
  'mi': [
    ['km', 1.609344],
  ],
  'kg': [
    ['lb', 2.20462],
    ['g', 1000],
  ],
  'lb': [
    ['kg', .453592],
    ['oz', 16],
  ],
  'g': [
    ['oz', .035274],
  ],
  'oz': [
    ['g', 28.3495],
  ],
  'l': [
    ['gal', .264172],
    ['ml', 1000],
  ],
  'gal': [
    ['l', 3.78541],
  ],
  'mb': [
    ['gb', 1 / 1024],
    ['kb', 1024],
  ],
  'gb': [
    ['mb', 1024],
    ['tb', 1 / 1024],
  ],
  'kmh': [
    ['mph', .621371],
  ],
  'mph': [
    ['kmh', 1.609344],
  ],
};

class UnitsView extends StatefulWidget {
  const UnitsView({super.key});

  @override
  State<UnitsView> createState() => _UnitsViewState();
}

class _UnitsViewState extends State<UnitsView> {
  final _input = TextEditingController();
  List<(double, String)> _out = [];

  void _eval() {
    final text = _input.text.trim().toLowerCase();
    final m = RegExp(r'^(-?[\d.]+)\s*°?\s*([a-z/]+)$').firstMatch(text);
    List<(double, String)> out = [];
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      var u = m.group(2)!.replaceAll('km/h', 'kmh');
      if (v != null) {
        if (u == 'c') {
          out = [(v * 9 / 5 + 32, '°F'), (v + 273.15, 'K')];
        } else if (u == 'f') {
          out = [((v - 32) * 5 / 9, '°C')];
        } else if (_unitTable[u] != null) {
          out = [
            for (final pair in _unitTable[u]!)
              (v * (pair[1] as double), pair[0] as String),
          ];
        }
      }
    }
    setState(() => _out = out);
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
          title: utilityLabel(context, 'utility25'),
          onBack: () => _backToMore(c),
        ),
        Field(
          controller: _input,
          hint: utilityLabel(context, 'utility26'),
          autofocusDelayed: true,
          onChanged: (_) => _eval(),
        ),
        _out.isEmpty
            ? Empty(
                RegExp(
                      r'^-?[\d.]+\s*°?\s*[a-z/]+$',
                    ).hasMatch(_input.text.trim().toLowerCase())
                    ? AppLocalizations.of(context)!.unknownUnit
                    : 'in · cm · mm · m · ft · km · mi · kg · lb · g · oz · l · gal · c · f · mb · gb · kmh · mph',
              )
            : Column(
                children: [
                  for (final (v, n) in _out)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ItemRow(
                        plain: true,
                        onTap: () => c.copy('${fmtUnit(v)} $n'),
                        child: Text('${fmtUnit(v)} $n'),
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

String fmtUnit(double v) => _sig(v);

String _sig(double v) {
  var s = v.toStringAsPrecision(8);
  if (s.contains('e')) {
    s = v.toStringAsExponential(4);
  }
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

import '../../l10n/app_localizations.dart';
import '../../l10n/utility_strings.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../flyout.dart';
import '../widgets.dart';

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
        Head(onBack: () => _backToMore(c)),
        DesktopAction(
          label: utilityLabel(context, 'utility18'),
          excludeSemantics: true,
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
        Head(onBack: () => _backToMore(c)),
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

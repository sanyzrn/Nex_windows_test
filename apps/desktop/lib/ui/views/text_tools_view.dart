import '../../l10n/utility_strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../flyout.dart';
import '../widgets.dart';

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


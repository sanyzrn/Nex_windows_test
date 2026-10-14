// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Part of the shared widget library split (see widgets.dart); do not import
// this file directly.
part of 'widgets.dart';

class Field extends StatefulWidget {
  const Field({
    super.key,
    this.controller,
    this.hint,
    this.focusNode,
    this.onChanged,
    this.onSubmit,
    this.onEnter,
    this.maxLines = 1,
    this.minLines,
    this.multiline = false,
    this.autofocusDelayed = false,
    this.style,
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String? hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;
  final ValueChanged<String>? onEnter;
  final int maxLines;
  final int? minLines;
  final bool multiline;
  final bool autofocusDelayed;
  final TextStyle? style;
  final TextInputType? keyboardType;

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  late final FocusNode _ownNode;
  bool _hadFocus = false;
  PanelController? _trackedPanel;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    _ownNode = widget.focusNode ?? FocusNode();
    _ownNode.addListener(_focusChanged);
    if (widget.autofocusDelayed) {
      _focusTimer = Timer(const Duration(milliseconds: 60), () {
        if (mounted) _ownNode.requestFocus();
      });
    }
  }

  void _focusChanged() {
    final has = _ownNode.hasFocus;
    final panel = _trackedPanel ??= LiquidScope.panelOf(context);
    if (has && !_hadFocus) panel.focusGained();
    if (!has && _hadFocus) panel.focusLost();
    _hadFocus = has;
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    // If disposed while focused, release the typing guard so the panel can
    // still auto-close.
    if (_hadFocus) _trackedPanel?.focusLost();
    _ownNode.removeListener(_focusChanged);
    if (widget.focusNode == null) _ownNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return TextField(
      controller: widget.controller,
      focusNode: _ownNode,
      textDirection: nexDirectionOf(widget.controller?.text),
      style:
          widget.style ??
          _body(context).copyWith(
            fontFamilyFallback: [
              'Segoe UI Variable Text',
              'Segoe UI',
              'Consolas',
              'Segoe UI Emoji',
            ],
          ),
      keyboardType: widget.keyboardType,
      maxLines: widget.multiline ? null : widget.maxLines,
      minLines: widget.multiline ? null : widget.minLines,
      expands: widget.multiline,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: _body(context, color: p.muted),
        filled: true,
        fillColor: p.soft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      cursorColor: p.inv,
      textAlignVertical: TextAlignVertical.top,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmit,
    );
  }
}

/// `.btn`.
class Btn extends StatefulWidget {
  const Btn({
    super.key,
    required this.child,
    this.onPressed,
    this.primary = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<Btn> createState() => _BtnState();
}

class _BtnState extends State<Btn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.primary ? p.inv : (_hover ? p.soft2 : p.soft),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: DefaultTextStyle(
            style: _body(context).copyWith(
              color: widget.primary ? p.invInk : p.ink,
              fontWeight: widget.primary ? FontWeight.w600 : FontWeight.w400,
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// `.chip`.

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:nex_ui/nex_ui.dart';

/// The active paragraph's first strong letter, using UTF-16 selection offsets.
/// This is a mitigation: Flutter still lays the other paragraphs out with one
/// base direction. Read mode already uses NexTextSurface per paragraph.
TextDirection? desktopEditingDirection(TextEditingValue value) {
  if (!value.selection.isValid || !value.selection.isCollapsed) return null;
  final end = value.selection.extentOffset.clamp(0, value.text.length);
  final start = end == 0 ? 0 : value.text.lastIndexOf('\n', end - 1) + 1;
  final next = value.text.indexOf('\n', end);
  return nexDirectionOf(
    value.text.substring(start, next < 0 ? value.text.length : next),
  );
}

/// Holds direction during composition and range drags, and corrects a tap
/// landing across a newline. Text, keyboard input and undo remain Flutter-owned.
class DesktopEditingDirection extends StatefulWidget {
  const DesktopEditingDirection({
    super.key,
    required this.controller,
    required this.builder,
    this.multiline = true,
  });
  final TextEditingController controller;
  final bool multiline;
  final Widget Function(BuildContext, TextDirection?) builder;
  @override
  State<DesktopEditingDirection> createState() =>
      _DesktopEditingDirectionState();
}

class _DesktopEditingDirectionState extends State<DesktopEditingDirection> {
  TextDirection? direction;
  final _fieldKey = GlobalKey();
  Offset? _pointerDown;

  bool _normalizingSelection = false;

  void _keepCaretOnClickedLine() {
    final point = _pointerDown;
    if (!widget.multiline || point == null || _normalizingSelection) return;
    final value = widget.controller.value;
    if (!value.selection.isValid ||
        !value.selection.isCollapsed ||
        value.composing.isValid && !value.composing.isCollapsed) {
      return;
    }
    RenderEditable? editable;
    void findEditable(RenderObject object) {
      if (object is RenderEditable) {
        editable = object;
      } else if (editable == null) {
        object.visitChildren(findEditable);
      }
    }

    final root = _fieldKey.currentContext?.findRenderObject();
    if (root == null) return;
    findEditable(root);
    final render = editable;
    if (render == null || !render.hasSize) return;
    final local = render.globalToLocal(point);
    if (!render.size.contains(local)) return;
    final position = value.selection.extent;
    // Only normalize the result of this pointer's hit test, never an unrelated
    // keyboard selection or a previous caret while a gesture is starting.
    if (render.getPositionForPoint(point).offset != position.offset) return;
    final current = render.getLocalRectForCaret(position);
    if (local.dy >= current.top && local.dy <= current.bottom) return;
    final candidates = [
      TextPosition(offset: position.offset, affinity: TextAffinity.upstream),
      if (position.offset > 0 && value.text[position.offset - 1] == '\n')
        TextPosition(offset: position.offset - 1),
    ];
    for (final candidate in candidates) {
      final rect = render.getLocalRectForCaret(candidate);
      if (local.dy >= rect.top && local.dy <= rect.bottom) {
        // This listener is registered before EditableText's listener. Correct
        // the hit test synchronously, before its caret can paint or scroll.
        _normalizingSelection = true;
        try {
          widget.controller.selection = TextSelection.collapsed(
            offset: candidate.offset,
            affinity: candidate.affinity,
          );
        } finally {
          _normalizingSelection = false;
        }
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    direction = nexDirectionOf(widget.controller.text);
    widget.controller.addListener(update);
  }

  @override
  void didUpdateWidget(DesktopEditingDirection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(update);
    widget.controller.addListener(update);
    direction = nexDirectionOf(widget.controller.text);
  }

  void update() {
    if (_normalizingSelection) return;
    _keepCaretOnClickedLine();
    final value = widget.controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    if (value.selection.isValid && !value.selection.isCollapsed) return;
    final next = widget.multiline && value.selection.isValid
        ? desktopEditingDirection(value)
        : nexDirectionOf(value.text);
    // Empty neutral paragraphs retain the writer's last direction.
    if (value.text.isNotEmpty && next == null || next == direction) return;
    setState(() => direction = next);
  }

  @override
  void dispose() {
    widget.controller.removeListener(update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: _fieldKey,
    onPointerDown: (event) {
      _pointerDown = event.buttons == kPrimaryButton ? event.position : null;
      _keepCaretOnClickedLine();
    },
    onPointerMove: (event) {
      if (_pointerDown != null &&
          (event.position - _pointerDown!).distance > 4) {
        _pointerDown = null;
      }
    },
    onPointerUp: (_) => _pointerDown = null,
    onPointerCancel: (_) => _pointerDown = null,
    child: Directionality(
      textDirection: direction ?? Directionality.of(context),
      child: Builder(builder: (inner) => widget.builder(inner, direction)),
    ),
  );
}

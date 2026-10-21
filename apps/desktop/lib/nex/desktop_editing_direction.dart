import 'package:flutter/material.dart';
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

/// Never writes to the controller, replaces EditableText, or intercepts keys.
/// Hold direction during composition and range drags; rebuild only on an actual
/// direction change, so IME/undo/selection remain Flutter-owned.
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
    final value = widget.controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) return;
    if (value.selection.isValid && !value.selection.isCollapsed) return;
    final next = widget.multiline
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
  Widget build(BuildContext context) => Directionality(
    textDirection: direction ?? Directionality.of(context),
    child: Builder(builder: (inner) => widget.builder(inner, direction)),
  );
}

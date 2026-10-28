import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';

/// Controlled selection with the same surface, border and focus treatment as
/// desktop text fields. Material retains keyboard navigation and menu semantics.
class DesktopDropdown<T> extends StatefulWidget {
  const DesktopDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.width = 220,
  });
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final Widget? hint;
  final double width;

  @override
  State<DesktopDropdown<T>> createState() => _DesktopDropdownState<T>();
}

class _DesktopDropdownState<T> extends State<DesktopDropdown<T>> {
  bool focused = false, hovering = false;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => focused = value),
        child: InputDecorator(
          isFocused: focused,
          isHovering: hovering,
          decoration: InputDecoration(
            enabled: widget.onChanged != null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: widget.value,
              items: widget.items,
              hint: widget.hint,
              onChanged: widget.onChanged,
              isDense: true,
              isExpanded: true,
              menuMaxHeight: 320,
              borderRadius: nexDropdownRadius,
              dropdownColor: nexDropdownColor(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              icon: const Icon(Icons.expand_more_rounded, size: 20),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The text a dropdown shows its choice in: body size, not the 18 px title
/// Material falls back to.
TextStyle? desktopDropdownStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodyMedium
    ?.copyWith(color: Theme.of(context).colorScheme.onSurface);

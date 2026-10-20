import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_ui/nex_ui.dart';
import '../core/panel_holds.dart';
import '../nex/features_state.dart' show NexPanelScope;

/// Adds a keyboard-only outline to an existing focusable control, without
/// adding another Tab stop or changing its size/hit testing.
class DesktopFocusRing extends StatefulWidget {
  const DesktopFocusRing({
    super.key,
    required this.child,
    this.radius = NexRadius.md,
  });
  final Widget child;
  final double radius;

  @override
  State<DesktopFocusRing> createState() => _DesktopFocusRingState();
}

class _DesktopFocusRingState extends State<DesktopFocusRing> {
  bool _focused = false;
  PanelHoldable? _panel;
  VoidCallback? _release;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  void _highlightChanged(FocusHighlightMode mode) {
    _syncHold();
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final panel = NexPanelScope.maybeOf(context);
    if (!identical(panel, _panel)) {
      _release?.call();
      _release = null;
      _panel = panel;
    }
    _syncHold();
  }

  void _syncHold() {
    // Keyboard users can leave the editor for an action while the pointer is
    // outside the edge panel. Keep that interaction alive without pinning it
    // or changing the normal pointer-driven auto-hide behavior.
    if (_focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional) {
      _release ??= _panel?.holdOpen(modal: false);
    } else {
      _release?.call();
      _release = null;
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (value) {
        _focused = value;
        _syncHold();
        setState(() {});
      },
      child: DecoratedBox(
        key: const ValueKey('desktop-focus-ring'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: visible
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: nexFocusRingWidth,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Keyboard and semantics counterpart of a custom pointer action. Existing
/// pointer callbacks (including drag preparation) retain their original order.
class DesktopAction extends StatefulWidget {
  const DesktopAction({
    super.key,
    required this.child,
    this.label,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.behavior,
    this.selected,
    this.toggled,
    this.excludeSemantics = false,
    this.radius = NexRadius.md,
    this.material = false,
  });

  final Widget child;
  final String? label;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final HitTestBehavior? behavior;
  final bool? selected;
  final bool? toggled;
  final bool excludeSemantics;
  final double radius;
  final bool material;

  @override
  State<DesktopAction> createState() => _DesktopActionState();
}

class _DesktopActionState extends State<DesktopAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final onTap = widget.onTap;
    final enabled = onTap != null;
    Widget action = DesktopFocusRing(
      radius: widget.radius,
      child: FocusableActionDetector(
        enabled: enabled,
        includeFocusSemantics: false,
        onFocusChange: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap?.call();
              return null;
            },
          ),
        },
        child: Semantics(
          button: widget.toggled == null,
          focusable: enabled,
          focused: _focused,
          enabled: enabled,
          selected: widget.selected,
          toggled: widget.toggled,
          label: label,
          excludeSemantics: widget.excludeSemantics,
          onTap: onTap,
          child: widget.material
              ? InkWell(
                  canRequestFocus: false,
                  excludeFromSemantics: true,
                  borderRadius: BorderRadius.circular(widget.radius),
                  onTap: onTap,
                  onTapDown: widget.onTapDown,
                  onTapUp: widget.onTapUp,
                  onTapCancel: widget.onTapCancel,
                  child: widget.child,
                )
              : GestureDetector(
                  excludeFromSemantics: true,
                  behavior: widget.behavior,
                  onTap: onTap,
                  onTapDown: widget.onTapDown,
                  onTapUp: widget.onTapUp,
                  onTapCancel: widget.onTapCancel,
                  child: widget.child,
                ),
        ),
      ),
    );
    if (label != null) {
      action = Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: action,
      );
    }
    return action;
  }
}

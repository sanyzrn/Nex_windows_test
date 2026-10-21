import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import 'private_session.dart';

/// A fresh subtree on lock/blur: no private strings remain in semantics or
/// in an outgoing animation. Editors persist recoverable drafts securely.
class DesktopPrivateGate extends StatefulWidget {
  const DesktopPrivateGate({
    super.key,
    required this.session,
    required this.builder,
  });
  final DesktopPrivateSession session;
  final WidgetBuilder builder;
  @override
  State<DesktopPrivateGate> createState() => _DesktopPrivateGateState();
}

class _DesktopPrivateGateState extends State<DesktopPrivateGate>
    with WidgetsBindingObserver {
  bool _visible = true, _busy = false, _failed = false;
  @override
  void initState() {
    super.initState();
    _visible =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _visible = state == AppLifecycleState.resumed);
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final accepted = await widget.session.unlock(
        AppLocalizations.of(context)!.privateReason,
      );
      if (mounted) setState(() => _failed = !accepted);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!_visible || !widget.session.isOpen) {
      return ListView(
        padding: const EdgeInsets.all(NexSpacing.lg),
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: NexSpacing.md),
          Text(l.privateLocked, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: NexSpacing.sm),
          Text(l.privateHint),
          const SizedBox(height: NexSpacing.lg),
          FilledButton.icon(
            onPressed: _busy || !_visible ? null : _unlock,
            icon: const Icon(Icons.fingerprint_rounded),
            label: Text(_busy ? l.moduleLoading : l.privateUnlock),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: NexSpacing.md),
              child: Text(
                l.privateUnavailable,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    }
    return Listener(
      onPointerDown: (_) => widget.session.touch(),
      child: Focus(
        onKeyEvent: (_, _) {
          widget.session.touch();
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: widget.session.lock,
                icon: const Icon(Icons.lock_outline_rounded),
                label: Text(l.privateLockNow),
              ),
            ),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: widget.builder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

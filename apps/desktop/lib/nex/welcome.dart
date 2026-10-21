import 'package:nex_ui/nex_ui.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import '../l10n/desktop_strings.dart';
import 'settings.dart';
import 'test_notification.dart';

/// Production-only first-run host. Tests, background launches and native smoke
/// entrypoints do not opt in. Completion lives outside portable preferences.
class DesktopWelcome extends StatefulWidget {
  const DesktopWelcome({
    super.key,
    required this.controller,
    required this.child,
  });
  final PanelController controller;
  final Widget child;
  static const completedKey = 'nex.windows.welcome.v1';
  @override
  State<DesktopWelcome> createState() => _DesktopWelcomeState();
}

class _DesktopWelcomeState extends State<DesktopWelcome> {
  VoidCallback? _release;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_show()));
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  Future<void> _show() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool(DesktopWelcome.completedKey) == true) return;
    _release = widget.controller.holdOpen();
    try {
      final completed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _WelcomeDialog(controller: widget.controller),
      );
      // Escape is a deliberate skip too. An interrupted process never reaches
      // here and gets another opportunity on its next interactive launch.
      if (completed != null || mounted) {
        await prefs.setBool(DesktopWelcome.completedKey, true);
      }
    } finally {
      _release?.call();
      _release = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog({required this.controller});
  final PanelController controller;
  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  bool _testing = false;
  void _save() {
    widget.controller.save();
    widget.controller.refresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final l = AppLocalizations.of(context)!;
    final s = DesktopStrings.of(context);
    return AlertDialog(
      key: const ValueKey('desktop-welcome'),
      title: Text(s.t('welcomeTitle')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.t('welcomeHint')),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                borderRadius: nexDropdownRadius,
                dropdownColor: nexDropdownColor(context),
                key: ValueKey('welcome-language-${c.S.language}'),
                initialValue: c.S.language,
                decoration: InputDecoration(labelText: l.language),
                items: [
                  DropdownMenuItem(value: 'en', child: Text(l.english)),
                  DropdownMenuItem(value: 'fa', child: Text(l.persian)),
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(l.followSystem),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    c.S.language = value;
                    _save();
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                borderRadius: nexDropdownRadius,
                dropdownColor: nexDropdownColor(context),
                initialValue: ['light', 'dark', 'system'].contains(c.S.theme)
                    ? c.S.theme
                    : 'dark',
                decoration: InputDecoration(labelText: l.settingsAppearance),
                items: [
                  DropdownMenuItem(value: 'light', child: Text(l.light)),
                  DropdownMenuItem(value: 'dark', child: Text(l.dark)),
                  DropdownMenuItem(
                    value: 'system',
                    child: Text(l.followSystem),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    c.S.theme = value;
                    _save();
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    '#6750A4': Colors.deepPurple,
                    '#006A6A': Colors.teal,
                    '#375CA8': Colors.blue,
                    '#875200': Colors.orange,
                  }.entries)
                    Semantics(
                      selected: c.S.accentSeed == entry.key,
                      child: IconButton.filledTonal(
                        tooltip: '${l.accent} ${entry.key}',
                        onPressed: () {
                          c.S.accentSeed = entry.key;
                          _save();
                        },
                        icon: Icon(
                          c.S.accentSeed == entry.key
                              ? Icons.check_circle
                              : Icons.circle,
                          color: entry.value,
                        ),
                      ),
                    ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.windowRemember),
                subtitle: Text(l.windowRememberHint),
                value: c.S.windowRemember,
                onChanged: (v) {
                  c.S.windowRemember = v;
                  _save();
                  unawaited(c.native.setCompactRestoration(!v));
                },
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.notifications_outlined),
                    label: Text(l.testNotificationRun),
                    onPressed: _testing
                        ? null
                        : () async {
                            setState(() => _testing = true);
                            try {
                              await sendDesktopTestNotification(c, l);
                            } finally {
                              if (mounted) setState(() => _testing = false);
                            }
                          },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.backup_outlined),
                    label: Text(s.t('welcomeImport')),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => Dialog(
                        child: SizedBox(
                          width: 760,
                          height: MediaQuery.sizeOf(ctx).height * .85,
                          child: Column(
                            children: [
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: IconButton(
                                  tooltip: MaterialLocalizations.of(
                                    ctx,
                                  ).closeButtonTooltip,
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                              const Expanded(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.all(20),
                                  child: NexSettingsView(
                                    windowLayout: true,
                                    initialCategory: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(s.t('welcomeKeys')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('welcome-skip'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.t('welcomeSkip')),
        ),
        FilledButton(
          key: const ValueKey('welcome-start'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.t('welcomeStart')),
        ),
      ],
    );
  }
}

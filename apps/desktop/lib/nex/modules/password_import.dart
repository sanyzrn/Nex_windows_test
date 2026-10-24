import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/app_localizations.dart';
import '../features_state.dart';
import 'module_controller.dart';
import 'password_csv.dart';

/// Own the operation outside the editor subtree: a native picker can background
/// Nex, and the private gate deliberately removes that subtree on background.
Future<void> importDesktopPasswordCsv(
  BuildContext context,
  DesktopModules modules,
) async {
  final l = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context, rootNavigator: true);
  final session = modules.privateSession;
  if (!session.isOpen) return;
  await withPanelHold(context, () async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => NexAlertDialog(
        title: Text(l.vaultImportCsv),
        content: Text(l.vaultImportCsvConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.moduleCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.vaultImportCsv),
          ),
        ],
      ),
    );
    if (accepted != true || !navigator.mounted || !session.isOpen) return;
    String message;
    try {
      final picked = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(extensions: ['csv']),
        ],
      );
      if (picked == null || !navigator.mounted) return;
      if (!session.isOpen && !await session.unlock(l.privateReason)) return;
      final file = File(picked.path);
      if (await file.length() > 16 * 1024 * 1024) {
        throw const FormatException('CSV too large');
      }
      final parsed = parsePasswordCsv(await file.readAsString());
      if (!session.isOpen || !navigator.mounted) return;
      final result = await modules.vault.importPasswords(parsed.entries);
      message = l.vaultImportCsvResult(
        result.added,
        result.duplicates,
        result.overCapacity + parsed.problems.length,
      );
    } catch (_) {
      // Never include file contents, passwords or exception text in notices.
      message = l.privateReadFailed;
    }
    session.lock();
    if (!navigator.mounted) return;
    await showDialog<void>(
      context: navigator.context,
      builder: (ctx) => NexAlertDialog(
        title: Text(l.vaultImportCsv),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
        ],
      ),
    );
  });
}

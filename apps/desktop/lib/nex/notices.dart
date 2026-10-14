import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';

Future<void> deleteNoteWithUndo(
  NexFeatures features,
  String id,
  ScaffoldMessengerState messenger,
  AppLocalizations l,
) async {
  await features.guard(
    () => features.store.call<void>('delete', {'id': id}),
    rethrowError: true,
  );
  if (features.session.id == id) await features.fresh();
  showNexNotice(
    messenger,
    l.deleted,
    action: SnackBarAction(
      label: l.undo,
      onPressed: () => features.guard(
        () => features.store.call<void>('restore', {'id': id}),
      ),
    ),
  );
}

/// Success notices expire even when an Undo action is available.
void showNexNotice(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
}) {
  if (!messenger.mounted) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      persist: false,
      showCloseIcon: true,
      duration: const Duration(seconds: 4),
    ),
  );
}

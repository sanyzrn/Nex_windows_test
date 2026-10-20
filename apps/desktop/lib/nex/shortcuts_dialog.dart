// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shortcuts / Help dialog displaying all desktop keyboard shortcuts.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/shortcut_labels.dart';

/// Shows the keyboard shortcuts reference dialog.
Future<void> showShortcutsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const _ShortcutsDialog(),
  );
}

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final shortcuts = [
      (ShortcutLabels.spaced(ShortcutLabels.newNote), l.actionNewNote),
      (ShortcutLabels.spaced(ShortcutLabels.newChecklist), l.actionNewChecklist),
      (ShortcutLabels.spaced(ShortcutLabels.search), l.actionSearch),
      (ShortcutLabels.spaced(ShortcutLabels.library), l.actionLibrary),
      (ShortcutLabels.spaced(ShortcutLabels.settings), l.actionSettings),
      (ShortcutLabels.moveSelection, l.actionMoveSelection),
      (ShortcutLabels.open, l.actionOpenNote),
      (ShortcutLabels.close, l.actionCloseOrClear),
      (ShortcutLabels.delete, l.actionDelete),
      (ShortcutLabels.spaced(ShortcutLabels.pin), l.actionPin),
      (ShortcutLabels.spaced(ShortcutLabels.copy), l.actionCopy),
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.keyboard_outlined,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.keyboardShortcuts,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: shortcuts.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          itemBuilder: (context, index) {
            final (keyCombo, actionLabel) = shortcuts[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      actionLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.04,
                          ),
                          offset: const Offset(0, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      keyCombo,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(l.close),
        ),
      ],
    );
  }
}

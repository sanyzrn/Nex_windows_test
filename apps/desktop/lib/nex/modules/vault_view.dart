import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_core/nex_core.dart';
import '../features_state.dart';
import '../../l10n/app_localizations.dart';
import '../desktop_editing_direction.dart';
import 'module_controller.dart';
import 'vault_store.dart';

class DesktopVaultView extends StatefulWidget {
  const DesktopVaultView({super.key, required this.modules});
  final DesktopModules modules;
  @override
  State<DesktopVaultView> createState() => _DesktopVaultViewState();
}

class _DesktopVaultViewState extends State<DesktopVaultView> {
  VaultSnapshot? snapshot;
  VaultKind kind = VaultKind.password;
  VaultEntry? editing;
  bool failed = false;
  String query = '';
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await widget.modules.vault.read();
      if (mounted)
        setState(() {
          snapshot = value;
          failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entry = editing;
    if (entry != null)
      return _VaultEditor(
        key: ValueKey(entry.id),
        modules: widget.modules,
        entry: entry,
        onBack: () async {
          setState(() => editing = null);
          await load();
        },
      );
    final labels = [l.vaultPasswords, l.vaultCards, l.vaultMessages];
    final icons = [
      Icons.key_rounded,
      Icons.credit_card_outlined,
      Icons.mark_email_unread_outlined,
    ];
    final draft = snapshot?.draft;
    return ListView(
      padding: const EdgeInsets.all(NexSpacing.md),
      children: [
        Text(l.privateDeviceOnly, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: NexSpacing.md),
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.sm,
          children: [
            for (final value in VaultKind.values)
              ChoiceChip(
                avatar: Icon(icons[value.index], size: 18),
                label: Text(labels[value.index]),
                selected: kind == value,
                onSelected: (_) => setState(() {
                  kind = value;
                  query = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: NexSpacing.md),
        if (failed) ...[
          Text(
            l.privateReadFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: load, child: Text(l.retry)),
        ] else if (snapshot == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          TextField(
            key: ValueKey('vault-search-${kind.name}'),
            decoration: InputDecoration(
              labelText: l.moduleSearch,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => query = value.toLowerCase().trim()),
          ),
          const SizedBox(height: NexSpacing.sm),
          Wrap(
            spacing: NexSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => setState(
                  () => editing = draft?.kind == kind
                      ? draft
                      : VaultStore.empty(kind),
                ),
                icon: const Icon(Icons.add),
                label: Text(l.moduleAdd),
              ),
              if (draft != null)
                TextButton.icon(
                  key: const ValueKey('vault-resume-draft'),
                  onPressed: () => setState(() => editing = draft),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(l.privateDraft),
                ),
            ],
          ),
          const SizedBox(height: NexSpacing.sm),
          if (!snapshot!.entries.any(
            (e) => e.kind == kind && e.title.toLowerCase().contains(query),
          ))
            Padding(
              padding: const EdgeInsets.all(NexSpacing.lg),
              child: Text(l.empty),
            ),
          for (final e
              in snapshot!.entries
                  .where(
                    (e) =>
                        e.kind == kind && e.title.toLowerCase().contains(query),
                  )
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
            Card(
              child: ListTile(
                leading: Icon(icons[kind.index]),
                title: NexTextSurface(e.title, maxLines: 2),
                subtitle: Text(
                  nexDisplayDate(
                    e.updatedAt,
                    solar:
                        NexPanelScope.maybeOf(context)?.S.solarCalendar ??
                        (l.localeName == 'fa'),
                    persian: l.localeName == 'fa',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => editing = e),
              ),
            ),
        ],
      ],
    );
  }
}

class _VaultEditor extends StatefulWidget {
  const _VaultEditor({
    super.key,
    required this.modules,
    required this.entry,
    required this.onBack,
  });
  final DesktopModules modules;
  final VaultEntry entry;
  final VoidCallback onBack;
  @override
  State<_VaultEditor> createState() => _VaultEditorState();
}

class _VaultEditorState extends State<_VaultEditor> {
  final fields = <String, TextEditingController>{};
  bool reveal = false, busy = false;
  String? error;
  Future<void> pending = Future.value();
  @override
  void initState() {
    super.initState();
    for (final key in [
      'title',
      'login',
      'password',
      'website',
      'number',
      'holder',
      'expiry',
      'cvv2',
      'iban',
      'text',
      'notes',
    ]) {
      fields[key] = TextEditingController(text: widget.entry.value(key));
    }
  }

  VaultEntry get value => VaultEntry(
    id: widget.entry.id,
    kind: widget.entry.kind,
    fields: {
      ...widget.entry.fields,
      for (final e in fields.entries) e.key: e.value.text,
    },
    updatedAt: DateTime.now(),
    favorite: widget.entry.favorite,
  );
  void changed() {
    widget.modules.privateSession.touch();
    final draft = value;
    pending = widget.modules.vault.saveDraft(draft);
    // A failed draft must remain visible as a failure; Save retries the full
    // value and does not report success until secure read-back succeeds.
    unawaited(
      pending.catchError((Object _) {
        if (mounted)
          setState(() => error = AppLocalizations.of(context)!.failed);
      }),
    );
  }

  Future<void> save() async {
    final l = AppLocalizations.of(context)!;
    final entry = value;
    if (entry.title.trim().isEmpty ||
        switch (entry.kind) {
          VaultKind.password => entry.value('password').isEmpty,
          VaultKind.card =>
            entry.value('number').isEmpty && entry.value('iban').isEmpty,
          VaultKind.message => entry.value('text').trim().isEmpty,
        }) {
      setState(() => error = l.vaultRequired);
      return;
    }
    if (entry.kind == VaultKind.card &&
        (entry.value('number').isNotEmpty &&
                !validVaultCard(entry.value('number')) ||
            entry.value('iban').isNotEmpty &&
                !validVaultIban(entry.value('iban')))) {
      setState(() => error = l.vaultInvalidCard);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // VaultStore serializes all changes, including outstanding drafts.
      await widget.modules.vault.save(entry);
      if (mounted) widget.onBack();
    } catch (_) {
      if (mounted) setState(() => error = l.failed);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    final l = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(l.vaultDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.moduleCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || !widget.modules.privateSession.isOpen)
      return;
    setState(() => busy = true);
    try {
      await widget.modules.vault.delete(widget.entry.id);
      if (mounted) widget.onBack();
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = l.failed;
        });
    }
  }

  Future<void> copy(String key) async {
    try {
      await widget.modules.privateSession.copy(fields[key]!.text);
      if (mounted)
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.privateCopyHint),
          ),
        );
    } catch (_) {
      if (mounted) setState(() => error = AppLocalizations.of(context)!.failed);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final kind = widget.entry.kind;
    final definitions = <(String, String, bool)>[
      ('title', l.vaultTitle, false),
      if (kind == VaultKind.password) ...[
        ('login', l.vaultLogin, true),
        ('password', l.vaultPassword, true),
        ('website', l.vaultWebsite, false),
      ],
      if (kind == VaultKind.card) ...[
        ('number', l.vaultCardNumber, true),
        ('holder', l.vaultCardHolder, false),
        ('expiry', l.vaultExpiry, true),
        ('cvv2', l.vaultCvv, true),
        ('iban', l.vaultIban, true),
      ],
      if (kind == VaultKind.message) ('text', l.vaultMessage, true),
      ('notes', l.vaultNotes, true),
    ];
    return ListView(
      padding: const EdgeInsets.all(NexSpacing.md),
      children: [
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.sm,
          children: [
            TextButton.icon(
              onPressed: busy ? null : widget.onBack,
              icon: const BackButtonIcon(),
              label: Text(l.moduleBack),
            ),
            TextButton.icon(
              onPressed: () => setState(() => reveal = !reveal),
              icon: Icon(
                reveal
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(reveal ? l.vaultHide : l.vaultReveal),
            ),
          ],
        ),
        Text(l.privateDraftHint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: NexSpacing.md),
        for (final (key, label, secret) in definitions)
          Padding(
            padding: const EdgeInsets.only(bottom: NexSpacing.md),
            child: DesktopEditingDirection(
              controller: fields[key]!,
              builder: (context, direction) => TextField(
                key: ValueKey('vault-field-$key'),
                controller: fields[key],
                textDirection: direction,
                enabled: !busy,
                obscureText: secret && !reveal,
                enableSuggestions: false,
                autocorrect: false,
                // Secret text never uses the framework copy menu, which would
                // feed the ordinary clipboard watcher. Copy goes through native.
                enableInteractiveSelection: !secret,
                maxLines: !secret || !reveal
                    ? 1
                    : (key == 'text' || key == 'notes' ? 5 : 1),
                decoration: InputDecoration(
                  labelText: label,
                  suffixIcon: secret
                      ? IconButton(
                          tooltip: l.copy,
                          onPressed: busy ? null : () => copy(key),
                          icon: const Icon(Icons.copy_outlined),
                        )
                      : null,
                ),
                onChanged: (_) => changed(),
              ),
            ),
          ),
        if (kind == VaultKind.password)
          TextButton.icon(
            onPressed: busy
                ? null
                : () {
                    fields['password']!.text = generateVaultPassword();
                    changed();
                  },
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: Text(l.vaultGenerate),
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: NexSpacing.md),
        Wrap(
          spacing: NexSpacing.sm,
          runSpacing: NexSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.check_rounded),
              label: Text(l.save),
            ),
            TextButton.icon(
              onPressed: busy ? null : remove,
              icon: const Icon(Icons.delete_outline),
              label: Text(l.delete),
            ),
          ],
        ),
      ],
    );
  }
}

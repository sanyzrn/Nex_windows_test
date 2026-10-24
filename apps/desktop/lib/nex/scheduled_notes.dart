import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';

Future<void> showScheduledNotes(BuildContext context) {
  final features = NexScope.of(context);
  final panel = NexPanelScope.maybeOf(context);
  return showDialog<void>(
    context: context,
    builder: (_) => NexScope(
      features: features,
      child: panel == null
          ? const _ScheduledDialog()
          : NexPanelScope(controller: panel, child: const _ScheduledDialog()),
    ),
  );
}

class _ScheduledDialog extends StatefulWidget {
  const _ScheduledDialog();
  @override
  State<_ScheduledDialog> createState() => _ScheduledDialogState();
}

class _ScheduledDialogState extends State<_ScheduledDialog> {
  List<ScheduledNote> notes = [];
  String? error;
  bool loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      load();
    }
  }

  Future<void> load() async {
    try {
      final value = await NexScope.of(
        context,
      ).store.call<List<ScheduledNote>>('scheduled');
      if (mounted) {
        setState(() {
          notes = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> deliver(String id) async {
    final features = NexScope.of(context);
    try {
      await features.guard(
        () => features.store
            .call<Note?>('releaseScheduled', {'id': id})
            .then((_) {}),
        rethrowError: true,
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    return AlertDialog(
      title: Text(l.scheduledNotes),
      content: SizedBox(
        width: 520,
        child: notes.isEmpty && error == null
            ? Text(l.empty)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) Text(error!),
                    for (final note in notes)
                      ListTile(
                        title: NexTextSurface(note.content, maxLines: 3),
                        subtitle: Text(
                          nexDisplayDate(
                            note.releaseAt.toLocal(),
                            solar:
                                NexPanelScope.maybeOf(
                                  context,
                                )?.S.solarCalendar ??
                                fa,
                            persian: fa,
                            time: true,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: l.releaseNow,
                          icon: const Icon(Icons.send_outlined),
                          onPressed: () => deliver(note.id),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}

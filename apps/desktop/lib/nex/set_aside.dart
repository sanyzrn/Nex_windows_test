import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/app_localizations.dart';
import 'desktop_date_picker.dart';
import 'features_state.dart';
import 'note_detail_view.dart';

/// Same return times as Android: evening at 18:00, tomorrow/next week at 08:00.
Future<void> setDesktopNotesAside(
  BuildContext context,
  List<Note> notes,
) async {
  if (notes.isEmpty) return;
  final f = NexScope.of(context);
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final panel = NexPanelScope.maybeOf(context);
  final now = DateTime.now();
  final evening = DateTime(now.year, now.month, now.day, 18);
  final choices = <(String, DateTime?)>[
    (l.setAsideUntilBack, null),
    if (evening.difference(now) > const Duration(hours: 1))
      (l.setAsideThisEvening, evening),
    (l.setAsideTomorrow, DateTime(now.year, now.month, now.day + 1, 8)),
    (l.setAsideNextWeek, DateTime(now.year, now.month, now.day + 7, 8)),
  ];
  await withPanelHold(context, () async {
    final index = await showDialog<int>(
      context: context,
      builder: (ctx) => NexAlertDialog(
        title: Text(l.setAsideSheetTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.setAsideSheetHint),
              for (var i = 0; i < choices.length; i++)
                ListTile(
                  title: Text(choices[i].$1),
                  onTap: () => Navigator.pop(ctx, i),
                ),
              ListTile(
                title: Text(l.setAsidePickDate),
                onTap: () => Navigator.pop(ctx, choices.length),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
        ],
      ),
    );
    if (index == null || !context.mounted) return;
    DateTime? until;
    if (index == choices.length) {
      final day = await showDesktopDatePicker(
        context,
        initialDate: DateTime(now.year, now.month, now.day + 1),
        firstDate: DateTime(now.year, now.month, now.day + 1),
        lastDate: DateTime(now.year + 2, now.month, now.day),
        solar: panel?.S.solarCalendar ?? l.localeName == 'fa',
      );
      if (day == null) return;
      until = DateTime(day.year, day.month, day.day, 8);
    } else {
      until = choices[index].$2;
    }
    final done = <String>[];
    await f.guard(() async {
      for (final note in notes) {
        if (await f.store.call<bool>('setAside', {
          'id': note.id,
          'until': until,
        })) {
          done.add(note.id);
        }
      }
    });
    if (done.isEmpty || !context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          done.length == 1 ? l.setAsideDone : l.setAsideGroupDone(done.length),
        ),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => f.guard(() async {
            for (final id in done) {
              await f.store.call<void>('bringBack', {'id': id});
            }
          }),
        ),
      ),
    );
  });
}

class NexSetAsideView extends StatefulWidget {
  const NexSetAsideView({super.key});
  @override
  State<NexSetAsideView> createState() => _NexSetAsideViewState();
}

class _NexSetAsideViewState extends State<NexSetAsideView> {
  List<Note>? notes;
  String? error;
  int revision = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final f = NexScope.of(context);
    if (revision != f.libraryRevision) {
      revision = f.libraryRevision;
      load();
    }
  }

  Future<void> load() async {
    try {
      final rows = await NexScope.of(
        context,
      ).store.call<List<Note>>('setAsideNotes', {'limit': 10000});
      if (mounted) {
        setState(() {
          notes = rows;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = AppLocalizations.of(context)!.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final f = NexScope.of(context);
    if (error != null) {
      return Center(
        child: TextButton(onPressed: load, child: Text(l.retry)),
      );
    }
    if (notes == null) return const Center(child: CircularProgressIndicator());
    if (notes!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('${l.setAsideEmptyTitle}\n${l.setAsideEmptyBody}'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes!.length,
      itemBuilder: (context, index) {
        final note = notes![index];
        final until = note.setAsideUntil;
        return ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: NexTextSurface(
            note.content ?? note.type.wireName,
            maxLines: 2,
          ),
          subtitle: Text(
            until == null
                ? l.setAsideUntilFurther
                : l.setAsideBackOn(
                    nexDisplayDate(
                      until.toLocal(),
                      solar:
                          NexPanelScope.maybeOf(context)?.S.solarCalendar ??
                          l.localeName == 'fa',
                      persian: l.localeName == 'fa',
                      time: true,
                    ),
                  ),
          ),
          onTap: () async {
            final panel = NexPanelScope.maybeOf(context);
            await showDialog<void>(
              context: context,
              builder: (ctx) {
                Widget child = Dialog(
                  child: SizedBox(
                    width: 800,
                    height: MediaQuery.sizeOf(ctx).height * .85,
                    child: NexNoteDetail(
                      note: note,
                      onClose: () => Navigator.pop(ctx),
                    ),
                  ),
                );
                if (panel != null) {
                  child = NexPanelScope(controller: panel, child: child);
                }
                return NexScope(features: f, child: child);
              },
            );
            if (mounted) await load();
          },
          trailing: TextButton(
            onPressed: () async {
              await f.guard(
                () => f.store.call<void>('bringBack', {'id': note.id}),
              );
              if (mounted) await load();
            },
            child: Text(l.setAsideBringBack),
          ),
        );
      },
    );
  }
}

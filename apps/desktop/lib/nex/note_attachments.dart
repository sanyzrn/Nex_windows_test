import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'features_state.dart';

/// The same attachment rows that mobile stores, opened by the Windows host.
class NexNoteAttachments extends StatefulWidget {
  const NexNoteAttachments({
    super.key,
    required this.noteId,
    required this.revision,
  });
  final String noteId;
  final int revision;
  @override
  State<NexNoteAttachments> createState() => _NexNoteAttachmentsState();
}

class _NexNoteAttachmentsState extends State<NexNoteAttachments> {
  List<NoteAttachment> attachments = [];
  String? error;
  bool busy = false;
  int generation = 0;
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      load();
    }
  }

  @override
  void didUpdateWidget(covariant NexNoteAttachments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId ||
        oldWidget.revision != widget.revision) {
      load();
    }
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final value = await NexScope.of(
        context,
      ).store.call<List<NoteAttachment>>('attachments', {'id': widget.noteId});
      if (mounted && request == generation) {
        setState(() {
          attachments = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = e.toString());
      }
    }
  }

  Future<void> addFiles() async {
    final features = NexScope.of(context);
    final id = widget.noteId;
    setState(() => busy = true);
    try {
      final files = await withPanelHold(
        context,
        () => features.pickFiles?.call(const []) ?? openFiles(),
      );
      await features.guard(() async {
        for (final file in files) {
          await features.store.call<NoteAttachment?>('attachMedia', {
            'path': file.path,
            'noteId': id,
          });
        }
      }, rethrowError: true);
      if (mounted && widget.noteId == id) await load();
    } catch (e) {
      if (mounted && widget.noteId == id) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(NoteAttachment attachment) async {
    final features = NexScope.of(context);
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await features.guard(
        () => features.store.call<void>('removeAttachment', {
          'id': attachment.id,
        }),
        rethrowError: true,
      );
      if (!mounted) return;
      await load();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.remove),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () async {
              await features.guard(
                () => features.store
                    .call<bool>('restoreAttachment', {'id': attachment.id})
                    .then((_) {}),
              );
              if (mounted) await load();
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final native = NexPanelScope.maybeOf(context)?.native;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: busy ? null : addFiles,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file, size: 18),
            label: Text(l.attach),
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final attachment in attachments)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(switch (attachment.kind) {
                AttachmentKind.photo => Icons.image_outlined,
                AttachmentKind.voice => Icons.audiotrack_outlined,
                AttachmentKind.file => Icons.insert_drive_file_outlined,
              }),
              title: NexTextSurface(
                attachment.name ??
                    attachment.mediaUri.split(RegExp(r'[/\\]')).last,
                maxLines: 2,
              ),
              subtitle: attachment.caption == null
                  ? null
                  : NexTextSurface(attachment.caption!, maxLines: 3),
              onTap: native == null
                  ? null
                  : () => NexScope.of(
                      context,
                    ).guard(() => native.launch(attachment.mediaUri)),
              trailing: IconButton(
                tooltip: l.remove,
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => remove(attachment),
              ),
            ),
          ),
      ],
    );
  }
}

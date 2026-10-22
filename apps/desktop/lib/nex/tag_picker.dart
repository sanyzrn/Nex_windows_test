import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_ui/nex_ui.dart';

import '../l10n/app_localizations.dart';
import 'command_palette.dart' show nexFoldText;
import 'desktop_editing_direction.dart';
import 'store.dart';

Future<Tag?> showDesktopTagPicker(
  BuildContext context, {
  required DesktopStore store,
  required String noteId,
}) => showDialog<Tag>(
  context: context,
  builder: (_) => DesktopTagPicker(store: store, noteId: noteId),
);

class DesktopTagPicker extends StatefulWidget {
  const DesktopTagPicker({
    super.key,
    required this.store,
    required this.noteId,
  });
  final DesktopStore store;
  final String noteId;

  @override
  State<DesktopTagPicker> createState() => _DesktopTagPickerState();
}

class _DesktopTagPickerState extends State<DesktopTagPicker> {
  final search = TextEditingController();
  List<Tag> available = [];
  bool loading = true, failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final tags = await widget.store.call<List<Tag>>('tags');
      final note = await widget.store.call<Note?>('get', {'id': widget.noteId});
      if (note == null || note.deletedAt != null) {
        throw StateError('Note unavailable');
      }
      final used = {for (final tag in note.tags) tag.id};
      if (mounted) {
        setState(() {
          available = tags.where((tag) => !used.contains(tag.id)).toList();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final query = nexFoldText(search.text);
    final shown = available
        .where((tag) => nexFoldText(tag.name).contains(query))
        .toList();
    return NexAlertDialog(
      title: Text(l.chooseExistingTag),
      insetPadding: const EdgeInsets.all(NexSpacing.md),
      scrollable: true,
      content: SizedBox(
        width: 420,
        height: (MediaQuery.sizeOf(context).height * .5).clamp(140, 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopEditingDirection(
              controller: search,
              multiline: false,
              builder: (context, direction) => TextField(
                key: const ValueKey('existing-tag-search'),
                controller: search,
                autofocus: true,
                textDirection: direction,
                decoration: InputDecoration(
                  hintText: l.searchTags,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clearSearch,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: NexSpacing.sm),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : failed
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.failed),
                          TextButton(onPressed: load, child: Text(l.retry)),
                        ],
                      ),
                    )
                  : shown.isEmpty
                  ? Center(
                      child: Text(
                        available.isEmpty
                            ? l.noAvailableTags
                            : l.noMatchingTags,
                      ),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final tag = shown[index];
                        final color = nexParseTagColor(tag.color);
                        return ListTile(
                          key: ValueKey('existing-tag-${tag.id}'),
                          leading: color == null
                              ? const Icon(Icons.sell_outlined)
                              : Container(
                                  key: ValueKey('existing-tag-color-${tag.id}'),
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          title: NexTextSurface(tag.name, maxLines: 2),
                          onTap: () => Navigator.of(context).pop(tag),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}

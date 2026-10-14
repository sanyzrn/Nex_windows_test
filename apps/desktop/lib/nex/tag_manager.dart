import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';

Future<void> showTagManager(BuildContext context, NexFeatures features) =>
    showDialog<void>(
      context: context,
      builder: (_) => _TagManager(features: features),
    );

class _TagManager extends StatefulWidget {
  const _TagManager({required this.features});
  final NexFeatures features;
  @override
  State<_TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends State<_TagManager> {
  final name = TextEditingController();
  final search = TextEditingController();
  List<Tag> tags = [];
  String? editingId, failure;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.features.store.call<List<Tag>>('tags');
      if (mounted) {
        setState(() {
          tags = result;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          failure = e.toString();
          busy = false;
        });
      }
    }
  }

  Future<void> save() async {
    final value = name.text.trim();
    final l = AppLocalizations.of(context)!;
    if (value.isEmpty ||
        tags.any(
          (t) =>
              t.id != editingId && t.name.toLowerCase() == value.toLowerCase(),
        )) {
      setState(() => failure = l.tagNameRequired);
      return;
    }
    await mutate(editingId == null ? 'createTag' : 'renameTag', {
      'name': value,
      'tag': editingId,
    });
    if (!mounted || failure != null) return;
    setState(() {
      editingId = null;
      name.clear();
    });
  }

  Future<void> mutate(String command, Map<String, dynamic> args) async {
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.features.guard(
        () => widget.features.store.call<void>(command, args),
        rethrowError: true,
      );
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          failure = e.toString();
        });
      }
    }
  }

  Future<void> remove(Tag tag) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l.delete}: ${tag.name}'),
        content: Text(l.tagDeleteHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await mutate('deleteTag', {'tag': tag.id});
    if (mounted && editingId == tag.id) {
      setState(() {
        editingId = null;
        name.clear();
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final shown = tags
        .where(
          (t) =>
              t.name.toLowerCase().contains(search.text.trim().toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: Text(l.manageTags),
      content: SizedBox(
        width: 420,
        height: (MediaQuery.sizeOf(context).height * .6).clamp(200, 460),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('tag-search'),
              controller: search,
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('tag-name'),
              controller: name,
              enabled: !busy,
              decoration: InputDecoration(
                labelText: editingId == null ? l.addTag : l.edit,
                suffixIcon: IconButton(
                  tooltip: l.save,
                  onPressed: busy ? null : save,
                  icon: const Icon(Icons.check),
                ),
              ),
              onSubmitted: (_) => save(),
            ),
            if (failure != null)
              Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : shown.isEmpty
                  ? Center(child: Text(l.empty))
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final tag = shown[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(tag.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l.edit,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => setState(() {
                                  editingId = tag.id;
                                  name.text = tag.name;
                                  failure = null;
                                }),
                              ),
                              IconButton(
                                tooltip: l.delete,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => remove(tag),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

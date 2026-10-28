import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart' show TagUsage;
import 'package:nex_ui/nex_ui.dart';

import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import '../nex/features_state.dart';

/// The tags in the sidebar: a colour dot, the name, how many notes carry it.
/// One click shows only those notes in the Library; a second click clears it.
class NexRailTags extends StatefulWidget {
  const NexRailTags({
    super.key,
    required this.features,
    required this.controller,
    required this.section,
  });

  final NexFeatures features;
  final PanelController controller;
  final String section;

  @override
  State<NexRailTags> createState() => _NexRailTagsState();
}

class _NexRailTagsState extends State<NexRailTags> {
  List<TagUsage> _tags = const [];
  int _revision = -1, _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.features.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.features.removeListener(_changed);
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  void _changed() {
    if (_revision == widget.features.libraryRevision) {
      if (mounted) setState(() {});
      return;
    }
    final first = _revision == -1;
    _revision = widget.features.libraryRevision;
    _debounce?.cancel();
    if (first) {
      unawaited(_load());
    } else {
      _debounce = Timer(const Duration(milliseconds: 250), _load);
    }
  }

  Future<void> _load() async {
    final token = ++_generation;
    try {
      final usage = await widget.features.store.call<List<TagUsage>>(
        'tagUsage',
      );
      if (!mounted || token != _generation) return;
      setState(
        () => _tags = [
          for (final u in usage)
            if (u.count > 0) u,
        ],
      );
    } catch (_) {
      // A sidebar without its tags is still a sidebar.
    }
  }

  void _open(String id) {
    final active =
        widget.section == 'library' && widget.features.libraryTag == id;
    widget.features.requestLibraryTag(active ? null : id);
    widget.controller.selectWindowSection('library');
  }

  @override
  Widget build(BuildContext context) {
    if (_tags.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final selectedId = widget.section == 'library'
        ? widget.features.libraryTag
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 18, 12, 6),
          child: Text(
            fa ? l.tags : l.tags.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              // Letter-spacing would pull Persian letters apart.
              letterSpacing: fa ? 0 : .8,
            ),
          ),
        ),
        for (final usage in _tags)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: NexWorkspaceDestination(
              key: ValueKey('rail-tag-${usage.tag.id}'),
              dense: true,
              icon: Icons.circle,
              iconWidget: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: nexParseTagColor(usage.tag.color) ?? scheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              label: usage.tag.name,
              selected: selectedId == usage.tag.id,
              trailing: Text(
                nexDigits('${usage.count}', persian: fa),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onPressed: () => _open(usage.tag.id),
            ),
          ),
      ],
    );
  }
}

/// The note types in the sidebar, under the tags: an icon, the name and how
/// many notes are of it. Shown only when there is more than one type to tell
/// apart. One click filters the Library; a second clears it.
class NexRailTypes extends StatefulWidget {
  const NexRailTypes({
    super.key,
    required this.features,
    required this.controller,
    required this.section,
  });

  final NexFeatures features;
  final PanelController controller;
  final String section;

  @override
  State<NexRailTypes> createState() => _NexRailTypesState();
}

class _NexRailTypesState extends State<NexRailTypes> {
  Map<NoteType, int> _counts = const {};
  int _revision = -1, _generation = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.features.addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    widget.features.removeListener(_changed);
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  void _changed() {
    if (_revision == widget.features.libraryRevision) {
      if (mounted) setState(() {});
      return;
    }
    final first = _revision == -1;
    _revision = widget.features.libraryRevision;
    _debounce?.cancel();
    if (first) {
      unawaited(_load());
    } else {
      _debounce = Timer(const Duration(milliseconds: 250), _load);
    }
  }

  Future<void> _load() async {
    final token = ++_generation;
    try {
      final raw = await widget.features.store.call<Map<String, int>>(
        'typeCounts',
      );
      if (!mounted || token != _generation) return;
      setState(
        () => _counts = {
          for (final type in NoteType.values)
            if ((raw[type.name] ?? 0) > 0) type: raw[type.name]!,
        },
      );
    } catch (_) {
      // A sidebar without its types is still a sidebar.
    }
  }

  void _open(NoteType type) {
    final active =
        widget.section == 'library' && widget.features.libraryType == type;
    widget.features.requestLibraryType(active ? null : type);
    widget.controller.selectWindowSection('library');
  }

  @override
  Widget build(BuildContext context) {
    if (_counts.length < 2) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final selected = widget.section == 'library'
        ? widget.features.libraryType
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 18, 12, 6),
          child: Text(
            fa ? l.type : l.type.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: fa ? 0 : .8,
            ),
          ),
        ),
        for (final entry in _counts.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: NexWorkspaceDestination(
              key: ValueKey('rail-type-${entry.key.name}'),
              dense: true,
              icon: nexNoteTypeIcon(entry.key.wireName),
              label: noteTypeLabel(l, entry.key),
              selected: selected == entry.key,
              trailing: Text(
                nexDigits('${entry.value}', persian: fa),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onPressed: () => _open(entry.key),
            ),
          ),
      ],
    );
  }
}

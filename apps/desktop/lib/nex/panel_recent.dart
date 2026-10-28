import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nex_core/nex_core.dart';

import '../core/controller.dart';
import '../l10n/app_localizations.dart';
import 'features_state.dart';
import 'note_tile.dart';

/// Under the edge panel's editor: the notes written last, as a row of small
/// tinted cards you can swipe along. A glance at what you were doing, and one
/// tap back into it — the panel is where you drop in for a moment, and the
/// last thing you wrote is usually why.
class NexPanelRecent extends StatefulWidget {
  const NexPanelRecent({super.key, required this.features, this.controller});

  final NexFeatures features;
  final PanelController? controller;

  @override
  State<NexPanelRecent> createState() => _NexPanelRecentState();
}

class _NexPanelRecentState extends State<NexPanelRecent> {
  List<Note> _notes = const [];
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
    if (_revision == widget.features.libraryRevision) return;
    final first = _revision == -1;
    _revision = widget.features.libraryRevision;
    _debounce?.cancel();
    if (first) {
      unawaited(_load());
    } else {
      _debounce = Timer(const Duration(milliseconds: 300), _load);
    }
  }

  Future<void> _load() async {
    final token = ++_generation;
    try {
      final overview = await widget.features.store.call<Map<String, dynamic>>(
        'workspace',
      );
      if (!mounted || token != _generation) return;
      final recent = (overview['recent'] as List?)?.cast<Note>() ?? const [];
      setState(() => _notes = recent.take(6).toList());
    } catch (_) {
      // A panel without its recent notes is still a panel.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 8),
            child: Text(
              l.workspaceRecent,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: NexNoteTile.heightFor(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _notes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => SizedBox(
                width: 168,
                child: NexNoteTile(
                  note: _notes[i],
                  showDate: false,
                  onOpen: () {
                    widget.features.requestNote(_notes[i]);
                    widget.controller?.openWidget('timeline');
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

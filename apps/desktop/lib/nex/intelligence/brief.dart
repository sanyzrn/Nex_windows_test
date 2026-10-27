import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/intelligence_strings.dart';
import '../features_state.dart';
import 'controller.dart';
import 'settings.dart';

class IntelligenceBrief extends StatefulWidget {
  const IntelligenceBrief({super.key});
  @override
  State<IntelligenceBrief> createState() => _BriefState();
}

class _BriefState extends State<IntelligenceBrief> {
  DesktopIntelligence? _ai;
  int _revision = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final features = NexScope.of(context);
    _ai ??= features.intelligence;
    if (_revision != features.libraryRevision) {
      _revision = features.libraryRevision;
      unawaited(_refresh());
    }
  }

  Future<void> _refresh({bool manual = false}) async {
    try {
      await _ai!.refreshBrief(manual: manual);
    } catch (_) {
      /* Keep the previous successful brief visible. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AiStrings.of(context), theme = Theme.of(context), ai = _ai!;
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        // Until a provider is set and a brief exists there is nothing to
        // show; the way in is Settings and the Intelligence page, not a
        // billboard on every launch of the home page.
        if (!ai.enabled && ai.brief.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t('brief'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: s.t('refresh'),
                    visualDensity: VisualDensity.compact,
                    onPressed: ai.busy || !ai.enabled
                        ? null
                        : () => _refresh(manual: true),
                    icon: const Icon(Icons.refresh, size: 17),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (ai.brief.isNotEmpty)
                NexMarkdown(ai.brief)
              else
                Text(
                  s.t('briefHint'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: ai.enabled
                      ? () => NexPanelScope.maybeOf(
                          context,
                        )?.selectWindowSection('assistant')
                      : () => showIntelligenceSettings(context),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    ai.enabled ? Icons.arrow_outward : Icons.tune,
                    size: 15,
                  ),
                  label: Text(s.t(ai.enabled ? 'assistant' : 'configure')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

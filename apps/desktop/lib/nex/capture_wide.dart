part of 'capture_view.dart';

mixin CaptureWide on CaptureViewBase {
  @override
  Widget _buildWide(
    BuildContext context,
    NexFeatures f,
    AppLocalizations l,
    PanelController? c,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = constraints.maxWidth < 650 || constraints.maxHeight < 650;
        final body = Padding(
          padding: embedded ? EdgeInsets.zero : EdgeInsets.all(small ? 24 : 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!embedded)
                    NexWorkspaceIntro(
                      title: l.workspaceCaptureTitle,
                      description: l.workspaceCaptureDescription,
                      compact: small,
                    ),
                  if (!embedded) SizedBox(height: small ? 24 : 32),
                  NexWorkspaceCard(
                    key: const ValueKey('workspace-editor'),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            24,
                            12,
                            16,
                            12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f.saving ? l.saving : l.savedLocally,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => f.fresh(),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l.newNote),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.keyV,
                              control: true,
                            ): () =>
                                unawaited(_pasteIntoComposer(context, f, c)),
                          },
                          child: Focus(
                            onFocusChange: (focused) =>
                                focused ? c?.focusGained() : c?.focusLost(),
                            child: TextField(
                              key: const ValueKey('capture-field'),
                              controller: f.composer,
                              focusNode: f.focus,
                              autofocus: true,
                              minLines: embedded || constraints.maxHeight < 850
                                  ? 4
                                  : 7,
                              maxLines: small ? 10 : 16,
                              textAlignVertical: TextAlignVertical.top,
                              textDirection: nexDirectionOf(f.composer.text),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 20,
                                height: 1.65,
                              ),
                              decoration: InputDecoration(
                                hintText: l.captureHint,
                                hintStyle: theme.textTheme.headlineSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                                filled: false,
                                contentPadding: const EdgeInsets.all(28),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onChanged: f.write,
                            ),
                          ),
                        ),
                        Divider(height: 1, color: scheme.outlineVariant),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: f.checklist,
                                    onChanged: f.session.id == null
                                        ? (v) {
                                            f.checklist = v;
                                            f.notify();
                                          }
                                        : null,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l.checklist,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              ),
                              ListenableBuilder(
                                listenable: f.composer,
                                builder: (context, _) {
                                  final text = f.composer.text;
                                  return Text(
                                    nexDigits(
                                      l.editorCount(
                                        text.trim().isEmpty
                                            ? 0
                                            : text
                                                  .trim()
                                                  .split(RegExp(r'\s+'))
                                                  .length,
                                        text.length,
                                      ),
                                      persian:
                                          Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'fa',
                                    ),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _actions(context, f, l, c),
                  if (f.importing || f.recordingBusy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (f.recordingAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l.recording,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  if (f.importedCount > 0 && !f.importing)
                    TextButton.icon(
                      onPressed: () => c?.selectWindowSection('library'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(l.mediaAdded(f.importedCount)),
                    ),
                  if (f.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${l.failed}: ${f.error}',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  if (!embedded) const SizedBox(height: 24),
                  if (!embedded)
                    Text(
                      l.workspaceCaptureFooter,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        return embedded ? body : SingleChildScrollView(child: body);
      },
    );
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 740 ? 3 : 2;
        return SizedBox(
          width: (constraints.maxWidth - (columns - 1) * 8) / columns,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 19),
            label: Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              backgroundColor: scheme.surfaceContainerLowest,
              side: BorderSide(color: scheme.outline),
              alignment: AlignmentDirectional.centerStart,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        );
      },
    );
  }
}

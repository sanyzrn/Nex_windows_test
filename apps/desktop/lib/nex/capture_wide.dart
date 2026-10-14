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
        final small = constraints.maxWidth < 650;
        // The footer's right-hand group (count + new-note) needs ~250px of
        // its own; below ~420 the label gives way to an icon so the row
        // never has to shove anything off the edge.
        final cramped = constraints.maxWidth < 420;
        final body = Padding(
          padding: embedded ? EdgeInsets.zero : EdgeInsets.all(small ? 16 : 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!embedded)
                    NexWorkspaceIntro(
                      title: l.workspaceCaptureTitle,
                      description: l.workspaceCaptureDescription,
                      compact: small,
                    ),
                  if (!embedded) const SizedBox(height: 16),
                  // One surface, one job: write. The status row, its two
                  // dividers and the leading "New note" button that used to
                  // frame the composer are gone — saving is what the app does
                  // by default, and the affordance to start a new note sits
                  // in the footer where the last word left off.
                  NexWorkspaceCard(
                    key: const ValueKey('workspace-editor'),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                              minLines: 5,
                              maxLines: small ? 9 : 14,
                              textAlignVertical: TextAlignVertical.top,
                              textDirection: nexDirectionOf(f.composer.text),
                              keyboardType: TextInputType.multiline,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                height: 1.6,
                              ),
                              decoration: InputDecoration(
                                hintText: l.captureHint,
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                                filled: false,
                                contentPadding: const EdgeInsets.all(18),
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
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
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
                                  const SizedBox(width: 2),
                                  Text(
                                    l.checklist,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // The count gives ground first: it is a
                                  // nicety, and a shrinking row must not push
                                  // the button off the edge.
                                  Flexible(
                                    child: ListenableBuilder(
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
                                                        .split(
                                                          RegExp(r'\s+'),
                                                        )
                                                        .length,
                                              text.length,
                                            ),
                                            persian:
                                                Localizations.localeOf(
                                                  context,
                                                ).languageCode ==
                                                'fa',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color:
                                                    scheme.onSurfaceVariant,
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (cramped)
                                    IconButton(
                                      tooltip: l.newNote,
                                      onPressed: () => f.fresh(),
                                      icon: const Icon(Icons.add, size: 17),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  else
                                    TextButton.icon(
                                      onPressed: () => f.fresh(),
                                      icon: const Icon(Icons.add, size: 15),
                                      label: Text(l.newNote),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _actions(context, f, l, c),
                  if (f.importing || f.recordingBusy)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (f.recordingAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.recording,
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ),
                  if (f.importedCount > 0 && !f.importing)
                    TextButton.icon(
                      onPressed: () => c?.selectWindowSection('library'),
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: Text(l.mediaAdded(f.importedCount)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (f.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${l.failed}: ${f.error}',
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ),
                  if (!embedded) const SizedBox(height: 16),
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
        final columns = constraints.maxWidth >= 680 ? 3 : 2;
        return SizedBox(
          width: (constraints.maxWidth - (columns - 1) * 8) / columns,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              backgroundColor: scheme.surfaceContainerLowest,
              side: BorderSide(color: scheme.outlineVariant),
              alignment: AlignmentDirectional.centerStart,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        );
      },
    );
  }
}

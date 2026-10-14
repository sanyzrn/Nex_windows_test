part of 'window_shell.dart';

class _CaptureSection extends StatelessWidget {
  const _CaptureSection();
  @override
  Widget build(BuildContext context) => NexScope.maybeOf(context) == null
      ? const Center(child: CircularProgressIndicator())
      : const NexWorkspaceHome();
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: const NexSettingsView(windowLayout: true),
      ),
    ),
  );
}

class _MissingStoreNotice extends StatelessWidget {
  const _MissingStoreNotice();
  @override
  Widget build(BuildContext context) =>
      Text(AppLocalizations.of(context)!.libraryUnavailable);
}

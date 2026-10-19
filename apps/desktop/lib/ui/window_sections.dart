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
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        // Narrower than the old 960: a settings row's control sits at the
        // far end of its line, and past ~760px the label and its control
        // stopped reading as one thing.
        constraints: const BoxConstraints(maxWidth: 1040),
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

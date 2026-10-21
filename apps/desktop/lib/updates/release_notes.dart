import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import '../l10n/app_localizations.dart';
import '../l10n/desktop_strings.dart';

String releaseNotesAsset(String language) =>
    language == 'fa' ? 'assets/CHANGELOG.fa.md' : 'CHANGELOG.md';

class ReleaseNotesButton extends StatelessWidget {
  const ReleaseNotesButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('release-notes-open'),
    onPressed: () => showReleaseNotes(context),
    icon: const Icon(Icons.history_rounded, size: 18),
    label: Text(DesktopStrings.of(context).t('whatsNew')),
  );
}

Future<void> showReleaseNotes(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _ReleaseNotesDialog(),
);

class _ReleaseNotesDialog extends StatefulWidget {
  const _ReleaseNotesDialog();
  @override
  State<_ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

class _ReleaseNotesDialogState extends State<_ReleaseNotesDialog> {
  String? _asset;
  late Future<String> _text;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final asset = releaseNotesAsset(Localizations.localeOf(context).languageCode);
    if (_asset != asset) {
      _asset = asset;
      _text = DefaultAssetBundle.of(context).loadString(asset);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(DesktopStrings.of(context).t('whatsNew')),
    content: SizedBox(
      width: 640,
      height: MediaQuery.sizeOf(context).height * .65,
      child: FutureBuilder<String>(
        future: _text,
        builder: (context, state) {
          if (state.hasError) {
            return Text(DesktopStrings.of(context).t('releaseNotesError'));
          }
          if (!state.hasData) { return const Center(child: CircularProgressIndicator()); }
          return SingleChildScrollView(child: NexMarkdown(state.data!));
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppLocalizations.of(context)!.close),
      ),
    ],
  );
}

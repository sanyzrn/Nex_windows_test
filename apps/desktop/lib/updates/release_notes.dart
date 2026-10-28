import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:nex_core/nex_core.dart';
import '../nex/features_state.dart';
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

Future<void> showReleaseNotes(BuildContext context) {
  final fa = Localizations.localeOf(context).languageCode == 'fa';
  final solar = NexPanelScope.maybeOf(context)?.S.solarCalendar ?? fa;
  return showDialog<void>(
    context: context,
    builder: (_) => _ReleaseNotesDialog(solar: solar, persian: fa),
  );
}

String formatReleaseNoteDates(
  String text, {
  required bool solar,
  required bool persian,
}) {
  if (!solar) return text;
  final headings = RegExp(
    r'^(##[^\n]*?)(\d{4}-\d{2}-\d{2})(?=\s*$)',
    multiLine: true,
  );
  return text.replaceAllMapped(headings, (match) {
    final date = DateTime.tryParse(match.group(2)!);
    return date == null
        ? match.group(0)!
        : '${match.group(1)}${nexDisplayDate(date, solar: true, persian: persian)}';
  });
}

class _ReleaseNotesDialog extends StatefulWidget {
  const _ReleaseNotesDialog({required this.solar, required this.persian});
  final bool solar, persian;
  @override
  State<_ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

class _ReleaseNotesDialogState extends State<_ReleaseNotesDialog> {
  String? _asset;
  late Future<String> _text;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final asset = releaseNotesAsset(
      Localizations.localeOf(context).languageCode,
    );
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
          if (!state.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            child: NexMarkdown(
              formatReleaseNoteDates(
                state.data!,
                solar: widget.solar,
                persian: widget.persian,
              ),
            ),
          );
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

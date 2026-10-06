import io

p = 'apps/desktop/lib/nex/settings.dart'
lines = io.open(p, encoding='utf-8').read().split('\n')

# sanity anchors
assert lines[23].startswith('class _NexSettingsViewState'), lines[23]
assert lines[24].strip() == 'String? recoveryKey;', lines[24]
assert lines[26].strip() == '@override', lines[26]
assert 'class _SettingsCard' in lines[660], lines[660]

# 1) part directives after the last import (line 11, index 10)
assert "import 'features.dart';" in lines[10]
lines[10] = "import 'features.dart';\n\npart 'settings_display_appearance.dart';\npart 'settings_shortcuts_backup.dart';\npart 'settings_tools_about.dart';"

# 2) replace the state class decl + giant build (lines 24..659, indexes 23..658)
new_state = """abstract class _SettingsStateBase extends State<NexSettingsView> {
  String? recoveryKey;

  // Card builders implemented in the part files of this library; declared
  // here so the base build can compose them.
  Widget _buildDisplayAppearance(BuildContext context);
  Widget _buildShortcutsBackup(BuildContext context);
  Widget _buildToolsAbout(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final f = NexScope.maybeOf(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.windowLayout ? 8 : 16,
          vertical: widget.windowLayout ? 16 : 16,
        ),
        child: Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No page title here: the flyout's panel header already names the
            // view (audit defect 5 - "Settings" used to appear twice).
            _buildDisplayAppearance(context),
            _buildShortcutsBackup(context),
            _buildToolsAbout(context),

            if (f?.error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${l.failed}: ${f!.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The composed settings state. Same library, so the mixins and this class
/// share every private member.
class _NexSettingsViewState = _SettingsStateBase
    with _SettingsDisplayAppearance, _SettingsShortcutsBackup,
    _SettingsToolsAbout;"""
out = lines[0:23] + new_state.split('\n') + lines[659:]
io.open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('OK')

import io

p = 'apps/desktop/lib/nex/capture_view.dart'
lines = io.open(p, encoding='utf-8').read().split('\n')

assert lines[18].startswith('class NexCaptureView extends StatelessWidget'), lines[18]
assert 'const NexCaptureView(' in lines[19], lines[19]
assert lines[248].strip().startswith('/// Desktop window layout'), lines[248]
assert lines[250].strip() == 'Widget _buildWide(', lines[250]
assert lines[545].startswith('class _CaptureAction'), lines[545]
assert lines[543].strip() == '}', lines[543]

part_line = "part 'capture_wide.dart';"

base_head = [
    'abstract class _CaptureViewBase extends StatelessWidget {',
    '  const _CaptureViewBase({super.key, this.pickFiles, this.compact = true});',
]
forward = [
    '',
    '  /// Desktop window layout builder; implemented in capture_wide.dart.',
    '  Widget _buildWide(',
    '    BuildContext context,',
    '    NexFeatures f,',
    '    AppLocalizations l,',
    '    PanelController? c,',
    '  );',
    '',
]
alias = [
    '',
    '/// The composed capture view. Same library, so the mixin and this class',
    '/// share every private member.',
    'class NexCaptureView = _CaptureViewBase with _CaptureWide;',
]

out = (
    lines[0:17]            # 1-17: header + imports (idx 0..16)
    + [part_line, '']      # part directive + blank
    + base_head
    + lines[19:25]         # original lines 20-25: fields
    + forward
    + lines[25:247]        # original lines 26-247: _choose + build
    + lines[522:544]       # original lines 523-544: _paste + class close
    + alias
)
io.open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('OK')

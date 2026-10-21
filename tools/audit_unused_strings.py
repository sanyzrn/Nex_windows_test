#!/usr/bin/env python3
"""List conservative cleanup candidates, not proof that a message is unreachable.

Inspect dynamic/interpolated lookups before removing a candidate. Utility messages
also resolve by English text, so retain any value mentioned by runtime/test code.
Generated localization sources are deliberately excluded from reference counts.
"""
import json
from pathlib import Path
import re
from check_l10n_parity import dart_map

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / 'apps/desktop/lib/l10n'


def candidates():
    sources = [p for base in ('apps/desktop/lib', 'apps/desktop/test', 'packages')
               for p in (ROOT / base).rglob('*.dart') if L10N not in p.parents]
    text = '\n'.join(p.read_text(encoding='utf-8') for p in sources)
    # World-clock labels derive from IANA zone names, e.g. New_York.
    derived = text.replace('_', ' ')
    identifiers = set(re.findall(r'\b[A-Za-z_]\w*\b', text))
    arb = json.loads((L10N / 'app_en.arb').read_text(encoding='utf-8'))
    groups = {'ARB': {k: v for k, v in arb.items() if not k.startswith('@')}}
    for file, name in [('desktop_strings.dart', '_copy'),
                       ('intelligence_strings.dart', '_words')]:
        groups[file] = dart_map((L10N / file).read_text(encoding='utf-8'), name)
    for group, entries in groups.items():
        for key, value in entries.items():
            english = value[0] if isinstance(value, list) else value
            if key not in identifiers and english not in text and english not in derived:
                yield group, key


if __name__ == '__main__':
    for group, key in candidates():
        print(f'{group}: {key}')

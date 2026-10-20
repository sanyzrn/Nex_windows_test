#!/usr/bin/env python3
"""Check desktop translation sources without requiring Flutter or dependencies."""

import argparse
import ast
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
PLACEHOLDER = re.compile(r"\{\s*([A-Za-z_]\w*)\s*[,}]")
BIDI = re.compile("[\u200e\u200f\u202a-\u202e\u2066-\u2069]")
TOKEN = re.compile(r"\s+|//[^\n]*|/\*.*?\*/|r?'(?:\\.|[^'\\])*'|r?\"(?:\\.|[^\"\\])*\"|[][{}:,]", re.S)
VISIBLE_LITERAL = re.compile(
    r'''(?:\b(?:Text|SelectableText)\s*\(\s*|\b(?:tooltip|hintText|labelText|label)\s*:\s*)'''
    r'''(['"])((?:\\.|(?!\1).)*?)\1''', re.S)


def check_visible_literals(source):
    """Supplement the line-based hygiene gate for multiline/double-quoted copy.

    Symbols/numeric output and interpolated data are not translation messages.
    Translated maps/ARB, protocol values and utility lookup arguments are outside
    these direct UI sinks. This is a focused guard, not a Dart AST analyzer.
    """
    # Keep line offsets while ignoring documentation and ordinary comments.
    source = re.sub(r''' '(?:\\.|[^'\\])*' | "(?:\\.|[^"\\])*" | /\*.*?\*/ | //[^\n]* ''',
                    lambda m: re.sub(r'[^\n]', ' ', m.group())
                    if m.group().startswith(('//', '/*')) else m.group(),
                    source, flags=re.S | re.X)
    return [(source.count('\n', 0, m.start()) + 1, m[2])
            for m in VISIBLE_LITERAL.finditer(source)
            if '$' not in m[2] and any(c.isalpha() for c in m[2])]


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate key: {key}")
        result[key] = value
    return result


def dart_map(source, name):
    """Parse only literal string maps/lists; fail closed on other Dart syntax."""
    start = re.search(r"\b" + re.escape(name) + r"\s*=\s*<[^;=]+?>\s*\{", source)
    if not start:
        raise ValueError(f"missing literal map {name}")
    end = source.find("};", start.end())
    if end < 0:
        raise ValueError(f"unterminated map {name}")
    body = source[start.end() - 1:end + 1]
    tokens = []
    at = 0
    while at < len(body):
        match = TOKEN.match(body, at)
        if not match:
            raise ValueError(f"unsupported syntax in {name}: {body[at:at + 25]!r}")
        token = match.group()
        at = match.end()
        if token.isspace() or token.startswith(("//", "/*")):
            continue
        tokens.append(token)
    index = 0

    def take(expected=None):
        nonlocal index
        if index >= len(tokens):
            raise ValueError(f"unexpected end of {name}")
        token = tokens[index]
        index += 1
        if expected is not None and token != expected:
            raise ValueError(f"expected {expected!r} in {name}, got {token!r}")
        return token

    def string():
        token = take()
        if not token.startswith(("'", '"', "r'", 'r"')):
            raise ValueError(f"expected string in {name}, got {token!r}")
        if not token.startswith('r') and re.search(r"(?<!\\)\$", token):
            raise ValueError(f"interpolated translation in {name}")
        value = ast.literal_eval(token.replace(r"\$", "$"))
        if not isinstance(value, str):
            raise ValueError(f"non-string value in {name}")
        return value

    take('{')
    pairs = []
    while tokens[index] != '}':
        key = string()
        take(':')
        if tokens[index] == '[':
            take('[')
            value = []
            while tokens[index] != ']':
                value.append(string())
                if tokens[index] != ']':
                    take(',')
            take(']')
        else:
            value = string()
        pairs.append((key, value))
        if tokens[index] != '}':
            take(',')
    take('}')
    if index != len(tokens):
        raise ValueError(f"unexpected trailing tokens in {name}")
    return unique_pairs(pairs)


def check_pair(label, en, fa):
    errors = []
    if not isinstance(en, str) or not en.strip():
        errors.append(f"{label}: English is missing or empty")
    if not isinstance(fa, str) or not fa.strip():
        errors.append(f"{label}: Persian is missing or empty")
    if errors:
        return errors
    if set(PLACEHOLDER.findall(en)) != set(PLACEHOLDER.findall(fa)):
        errors.append(f"{label}: placeholders differ")
    if BIDI.search(en + fa):
        errors.append(f"{label}: invisible bidi control character")
    return errors


def check(root):
    folder = Path(root) / 'apps/desktop/lib/l10n'
    en, fa = [json.loads((folder / f'app_{lang}.arb').read_text(encoding='utf-8'),
                         object_pairs_hook=unique_pairs) for lang in ('en', 'fa')]
    errors = []
    en_keys = {k for k in en if not k.startswith('@')}
    fa_keys = {k for k in fa if not k.startswith('@')}
    for key in sorted(en_keys ^ fa_keys):
        errors.append(f"ARB {key}: missing in {'Persian' if key in en_keys else 'English'}")
    for key in sorted(en_keys & fa_keys):
        errors.extend(check_pair(f'ARB {key}', en[key], fa[key]))
        for lang, entries in (('en', en), ('fa', fa)):
            declared = entries.get('@' + key, {}).get('placeholders', {})
            actual = set(PLACEHOLDER.findall(entries[key]))
            if set(declared) != actual:
                errors.append(f'ARB {key} ({lang}): placeholder metadata differs from message')
        left = en.get('@' + key, {}).get('placeholders', {})
        right = fa.get('@' + key, {}).get('placeholders', {})
        # Descriptions/examples may be translated. Types and formatting may not drift.
        fields = ('type', 'format', 'optionalParameters', 'isCustomDateFormat')
        for placeholder in set(left) & set(right):
            if any(left[placeholder].get(f) != right[placeholder].get(f) for f in fields):
                errors.append(f'ARB {key}.{placeholder}: placeholder metadata differs')
    for lang, entries in (('en', en), ('fa', fa)):
        for key in entries:
            if key.startswith('@') and not key.startswith('@@') and key[1:] not in entries:
                errors.append(f'ARB {lang} {key}: orphan metadata')
    for filename, map_name in (('desktop_strings.dart', '_copy'),
                               ('intelligence_strings.dart', '_words')):
        entries = dart_map((folder / filename).read_text(encoding='utf-8'), map_name)
        if not entries:
            errors.append(f'{filename}: empty translation map')
        for key, pair in entries.items():
            if not isinstance(pair, list) or len(pair) != 2:
                errors.append(f'{filename} {key}: expected exactly [English, Persian]')
            else:
                errors.extend(check_pair(f'{filename} {key}', *pair))
    source = (folder / 'utility_strings.dart').read_text(encoding='utf-8')
    utility_en, utility_fa = (dart_map(source, name) for name in ('_en', '_fa'))
    expected = {key for key in en_keys if key.startswith('utility')}
    for lang, entries, arb in (('en', utility_en, en), ('fa', utility_fa, fa)):
        if set(entries) != expected:
            errors.append(f'utility_strings.dart {lang}: keys differ from ARB')
        for key, value in entries.items():
            if value != arb.get(key):
                errors.append(f'utility_strings.dart {lang} {key}: stale generated translation')
    for key in utility_en.keys() | utility_fa.keys():
        errors.extend(check_pair(f'utility_strings.dart {key}', utility_en.get(key), utility_fa.get(key)))
    for path in sorted((Path(root) / 'apps/desktop/lib').rglob('*.dart')):
        if 'l10n' in path.parts:
            continue
        for line, value in check_visible_literals(path.read_text(encoding='utf-8')):
            errors.append(f'{path.relative_to(root)}:{line}: hard-coded UI string {value!r}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        errors = check(args.root)
    except (ValueError, OSError, IndexError, SyntaxError) as error:
        errors = [str(error)]
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Localization parity: OK (ARB, placeholders and all three Dart maps)')
    return 0


if __name__ == '__main__':
    sys.exit(main())

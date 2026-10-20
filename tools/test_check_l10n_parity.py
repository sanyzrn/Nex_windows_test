"""Regression tests: broken translations must fail the CI parity gate."""

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from check_l10n_parity import ROOT, check, check_visible_literals, dart_map


class LocalizationParityTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / 'apps/desktop/lib/l10n'
        shutil.copytree(ROOT / 'apps/desktop/lib/l10n', self.folder)

    def arb(self, lang, mutate):
        path = self.folder / f'app_{lang}.arb'
        data = json.loads(path.read_text(encoding='utf-8'))
        mutate(data)
        path.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')

    def test_current_sources_pass(self):
        self.assertEqual(check(self.root), [])

    def test_missing_key_fails(self):
        self.arb('fa', lambda d: d.pop('capture'))
        self.assertTrue(any('capture: missing' in e for e in check(self.root)))

    def test_empty_translation_fails(self):
        self.arb('fa', lambda d: d.update(capture='  '))
        self.assertTrue(any('capture: Persian' in e for e in check(self.root)))

    def test_renamed_placeholder_fails(self):
        self.arb('fa', lambda d: d.update(wordCount='{total} واژه'))
        self.assertTrue(any('wordCount: placeholders differ' in e for e in check(self.root)))

    def test_missing_placeholder_metadata_fails(self):
        self.arb('fa', lambda d: d.pop('@wordCount'))
        self.assertTrue(any('wordCount (fa): placeholder metadata' in e for e in check(self.root)))

    def test_placeholder_type_drift_fails(self):
        self.arb('fa', lambda d: d['@wordCount']['placeholders']['count'].update(type='String'))
        self.assertTrue(any('wordCount.count: placeholder metadata differs' in e for e in check(self.root)))

    def test_bidi_marks_fail(self):
        self.arb('fa', lambda d: d.update(capture='\u200fثبت'))
        self.assertTrue(any('capture: invisible bidi' in e for e in check(self.root)))

    def test_orphan_metadata_fails(self):
        self.arb('fa', lambda d: d.update({'@missing': {}}))
        self.assertTrue(any('orphan metadata' in e for e in check(self.root)))

    def test_duplicate_json_key_fails(self):
        path = self.folder / 'app_fa.arb'
        text = path.read_text(encoding='utf-8')
        path.write_text(text.replace('{', '{"capture": "duplicate",', 1), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'duplicate key: capture'):
            check(self.root)

    def test_both_pair_maps_need_exactly_two_nonempty_languages(self):
        for filename in ('desktop_strings.dart', 'intelligence_strings.dart'):
            with self.subTest(filename=filename):
                path = self.folder / filename
                original = path.read_text(encoding='utf-8')
                for pair in ("['Only English']", "['English', '  ']", "['English', 'فارسی', 'Extra']"):
                    at = original.index('{', original.index('static const')) + 1
                    path.write_text(original[:at] + "'broken': " + pair + ',' + original[at:], encoding='utf-8')
                    self.assertTrue(any('broken:' in e for e in check(self.root)))
                path.write_text(original, encoding='utf-8')

    def test_stale_generated_utility_fails(self):
        path = self.folder / 'utility_strings.dart'
        path.write_text(path.read_text(encoding='utf-8').replace("'پاک کردن'", "'قدیمی'", 1), encoding='utf-8')
        self.assertTrue(any('stale generated' in e for e in check(self.root)))

    def test_missing_utility_language_fails(self):
        path = self.folder / 'utility_strings.dart'
        path.write_text(path.read_text(encoding='utf-8').replace("  'utility2': 'پاک کردن',", ''), encoding='utf-8')
        self.assertTrue(any('keys differ' in e for e in check(self.root)))

    def test_literal_parser_handles_comments_escapes_and_unicode(self):
        source = r"""static const _words = <String, List<String>>{
          // This comment is not an entry: 'fake': ['x', 'y'],
          'quote': ['It\'s \$5', 'نیم\u200cفاصله'],
          'braces': ['{count}', '{count}'],
        };"""
        self.assertEqual(dart_map(source, '_words'), {
            'quote': ["It's $5", 'نیم\u200cفاصله'], 'braces': ['{count}', '{count}'],
        })

    def test_literal_parser_fails_closed(self):
        for body in ("'a': translatedValue", "'a': ['one', 'دو'], 'a': ['three', 'چهار']"):
            with self.subTest(body=body), self.assertRaises(ValueError):
                dart_map('const _copy = <String, List<String>>{' + body + '};', '_copy')

    def test_multiline_lowercase_and_double_quoted_ui_copy_fails(self):
        source = '''Text(\n "hello"); tooltip: 'search'; hintText: "find a note"; labelText: 'عنوان';'''
        self.assertEqual([s for _, s in check_visible_literals(source)],
                         ['hello', 'search', 'find a note', 'عنوان'])

    def test_localized_data_comments_and_symbols_are_not_ui_literals(self):
        source = '''// Text('comment')
        Text(l.capture); Text('•'); Text('$count'); Text('×'); Text('۱۲');
        label: s.t('images'); /* tooltip: 'comment' */'''
        self.assertEqual(check_visible_literals(source), [])


if __name__ == '__main__':
    unittest.main()

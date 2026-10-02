from pathlib import Path
import json
p=Path(__file__).resolve().parents[1]
en=json.loads((p/'lib/l10n/app_en.arb').read_text(encoding='utf-8'))
fa=json.loads((p/'lib/l10n/app_fa.arb').read_text(encoding='utf-8'))
def dart(value): return "'" + value.replace('\\', '\\\\').replace("'", "\\'").replace('$', r'\$').replace('\n', r'\n') + "'"
entries=[k for k in en if k.startswith('utility')]
s="// Generated from app_en.arb and app_fa.arb. Run tools/generate_utility_strings.py.\nimport 'package:flutter/widgets.dart';\n"
s+="const _en = <String,String>{"+','.join(dart(k)+':'+dart(en[k]) for k in entries)+"};\n"
s+="const _fa = <String,String>{"+','.join(dart(k)+':'+dart(fa[k]) for k in entries)+"};\n"
s+="String utilityForLocale(String language,String text) { final key = _en.entries.where((e)=>e.value==text).firstOrNull?.key; return key==null ? text : (language == 'fa' ? _fa[key]! : _en[key]!); }\n"
s+="String utilityLabel(BuildContext context,String key) => Localizations.localeOf(context).languageCode == 'fa' ? _fa[key]! : _en[key]!;\n"
s+="String utilityLabelForText(BuildContext context,String text) { final key = _en.entries.where((e)=>e.value==text).firstOrNull?.key; return key==null ? text : utilityLabel(context,key); }\n"
(p/'lib/l10n/utility_strings.dart').write_text(s,encoding='utf-8')

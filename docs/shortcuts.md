# Keyboard shortcuts / میان‌برهای صفحه‌کلید

Generated from `shortcuts_dialog.dart`, `shortcut_labels.dart` and both ARBs.
From `apps/desktop`, run `dart run tool/generate_shortcuts.dart` after editing them.

These are the actions listed by the in-app help dialog. Library selection actions
apply while the library owns focus; an active text editor keeps its editing keys.

| Shortcut | English | فارسی |
| --- | --- | --- |
| `Ctrl+N` | New note | یادداشت جدید |
| `Ctrl+Shift+N` | New checklist | فهرست جدید |
| `Ctrl+F` | Search | جست‌وجو |
| `Ctrl+L` | Library | کتابخانه |
| `Ctrl+,` | Settings | تنظیمات |
| `↑ / ↓` | Move selection | حرکت بین یادداشت‌ها |
| `Enter` | Open note | باز کردن یادداشت |
| `Esc` | Close reader / Clear search | بستن یادداشت / پاک کردن جست‌وجو |
| `Delete` | Delete | حذف |
| `Ctrl+P` | Pin / Unpin | سنجاق / لغو سنجاق |
| `Ctrl+C` | Copy | کپی |

Additional bindings: `Ctrl+K` opens the command palette; `F1` opens help
(`Ctrl+/` also opens help in the library); `Ctrl+Z` undoes library deletion when
an editor does not own focus. The global capture shortcut defaults to
`Ctrl+Alt+N` and is configurable in Settings → Shortcuts & input.

The generated table describes the help dialog; context-specific bindings above
are documented separately. [Product guide](../README.md).

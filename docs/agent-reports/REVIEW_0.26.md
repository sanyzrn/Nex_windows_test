# 0.26 Windows visual review

[Windows refresh 39695846116](https://github.com/sanyzrn/Nex_windows_test/actions/runs/39695846116)
passed **226** golden/review cases. Generated commit: `40ba6cb`.
Reviewed all **47 changed images** in a contact sheet and inspected the four
module examples below against the published 0.25 source. No comparison tolerance
was changed. Changes are confined to intended module layouts, close behavior
settings and version/release-history surfaces. Physical monitor QA remains open.

| View | Reviewed result |
| --- | --- |
| Cycle, wide/compact, fa/en, light/dark | Segmented inspectable ring; wide ring/calendar columns, stacked compact layout; selected date/mood/actions/history stay scrollable. |
| PDF, same matrix | Clear centered local-open action; no duplicate open button in the empty state. Actual document rendering/search is a separate runtime test. |
| Vault, same matrix | Readable counted category cards, title search and preserved private item list. |
| Portrait, same matrix | Local metric cards and refresh; existing rhythm/type/tag/AI sections retained. |
| Settings/About/history/panel | Close-to-tray explanation, 0.26 labels and bilingual release notes; no unrelated baseline promotion. |

Examples (synthetic fixtures only):

- [Cycle, Persian light](../../apps/desktop/test/review_goldens/b8_cycle_wide_fa_light.png)
- [PDF, English light](../../apps/desktop/test/review_goldens/b8_pdf_wide_en_light.png)
- [Vault, English compact dark](../../apps/desktop/test/review_goldens/b8_vault_compact_en_dark.png)
- [Portrait, Persian dark](../../apps/desktop/test/review_goldens/b8_portrait_wide_fa_dark.png)

The native smoke additionally checks the process's actual AUMID, a real normal
second launch restoring the original HWND, installed protocol command and shortcut
AUMID. A visible/restored HWND is not proof of foreground priority under every
Windows focus policy; physical focus behavior remains in the owner checklist.
The optional 30-minute idle soak was not run here; no numbers are claimed.

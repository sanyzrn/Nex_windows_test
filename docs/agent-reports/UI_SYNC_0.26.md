# Android menu sync and module comparison — 0.26

Source: actual `sanyzrn/DbsNex` branch `release/1.80.0`, commit `9590194f2425ed7eb3fa46ec61c1719cb98872a4`.
Ported `packages/ui/lib/widgets/nex_popup_menu.dart`; copied only popupMenuTheme
into `packages/ui/lib/tokens/nex_tokens.dart`. Windows tool accents, card density,
leading sizes and Windows-owned files remain intact. Shared helpers now supply
constraints, row sizing, corner radius, surface and readable destructive ink.
Desktop popup buttons/context menus use these helpers.

Exceptions: the tag-filter PopupMenuItem retains its colored tag dot. Material
DropdownButton/DropdownButtonFormField retain native keyboard selection and
FormField validation, with explicit Nex radius/surface. Existing SnackBars remain
Material transient feedback with actions/live accessibility; they are not menus.
The stock-menu ratchet permits only the single tagged-entry exception. Shared UI
menu/contrast tests check the port; Windows visual comparison remains required.

Modules compared with Android `widgets/pdf_reader.dart`, `screens/cycle/` ring,
today and calendar, `screens/vault_screen.dart`, and writing portrait code.
PDF keeps the native PDFium desktop renderer/search/selection rather than porting
Android's bitmap bridge; adds a clear local-open empty state, document identity and Ctrl+O/F/G. Cycle now has an
inspectable phase ring with keyboard slider and quick mood on the selected date,
preserving other observations through copyWith. Ring/calendar sit side by side
on wide windows and stack on narrow ones. Vault adds counted category cards;
Portrait uses readable metric cards and refresh. Tool dialogs explain context
and retain immediate shared private-session locking. These are desktop
adaptations, not a claim of full Android parity: Android native widgets,
reminders, file-vault/biometric platform APIs and all portrait styling are not
ported. Future work must preserve privacy/backup contracts.

No historical screenshots, patches, vendored licenses or archives were deleted:
no inspected tracked artifact was proven unnecessary. Build caches are ignored.

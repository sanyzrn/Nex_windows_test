/// Windows key names deliberately stay language-neutral, as printed on keyboards.
/// Use Directionality.ltr for a standalone hint; never add bidi marks to text.
abstract final class ShortcutLabels {
  static const newNote = 'Ctrl+N';
  static const newChecklist = 'Ctrl+Shift+N';
  static const search = 'Ctrl+F';
  static const library = 'Ctrl+L';
  static const settings = 'Ctrl+,';
  static const commandPalette = 'Ctrl+K';
  static const help = 'F1';
  static const moveSelection = '↑ / ↓';
  static const open = 'Enter';
  static const close = 'Esc';
  static const delete = 'Delete';
  static const pin = 'Ctrl+P';
  static const copy = 'Ctrl+C';

  static String spaced(String keys) => keys.replaceAll('+', ' + ');
}

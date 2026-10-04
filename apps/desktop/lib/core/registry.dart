/// The widget registry, ported 1:1 from the original `W` table.
/// Icons keep the exact SVG path data so the visuals match.
library;

enum ToolKind { panel, action, app }

class ToolDef {
  const ToolDef({
    required this.id,
    required this.name,
    this.emoji,
    this.svg,
    this.kind = ToolKind.panel,
    this.dockOnly = false,
    this.action,
    this.fixed = false,
  });

  final String id;
  final String name;
  final String? emoji;
  final String? svg;
  final ToolKind kind;
  final bool dockOnly;

  /// Action id for ToolKind.action ("shot", "lock", ...).
  final String? action;

  /// Tools that can't be dragged or hidden (Settings).
  final bool fixed;
}

const Map<String, ToolDef> kTools = {
  'timeline': ToolDef(id: 'timeline', name: 'Library', emoji: '📚'),
  'emoji': ToolDef(id: 'emoji', name: 'Emoji', emoji: '😊'),
  'clip': ToolDef(
    id: 'clip',
    name: 'Clipboard',
    svg:
        '<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4h6v3H9z"/>',
  ),
  'color': ToolDef(
    id: 'color',
    name: 'Color',
    svg:
        '<path d="M12 3a9 9 0 1 0 0 18c1 0 1.5-.8 1.5-1.5 0-1.2-1-1.5-1-2.5 0-.8.7-1.5 1.5-1.5H16a5 5 0 0 0 5-5c0-4-4-7.5-9-7.5z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7.5" r="1"/>',
  ),
  'shot': ToolDef(
    id: 'shot',
    name: 'Screenshot',
    kind: ToolKind.action,
    action: 'shot',
    svg:
        '<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2"/><circle cx="12" cy="12" r="3"/>',
  ),
  'note': ToolDef(
    id: 'note',
    name: 'Note',
    svg: '<path d="M5 4h10l4 4v12H5z"/><path d="M9 12h6M9 16h4"/>',
  ),
  'more': ToolDef(
    id: 'more',
    name: 'More',
    dockOnly: true,
    svg:
        '<rect x="4" y="4" width="6" height="6" rx="1.5"/><rect x="14" y="4" width="6" height="6" rx="1.5"/><rect x="4" y="14" width="6" height="6" rx="1.5"/><rect x="14" y="14" width="6" height="6" rx="1.5"/>',
  ),
  'calc': ToolDef(
    id: 'calc',
    name: 'Calculator',
    svg:
        '<rect x="5" y="3" width="14" height="18" rx="2.5"/><path d="M8 7h8M8.5 11h.01M12 11h.01M15.5 11h.01M8.5 14.5h.01M12 14.5h.01M15.5 14.5h.01M8.5 18h.01M12 18h.01M15.5 18h.01"/>',
  ),
  'timer': ToolDef(
    id: 'timer',
    name: 'Timer',
    svg:
        '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 13.5V10M10 2.5h4M18.5 6.5l1.5-1.5"/>',
  ),
  'stopwatch': ToolDef(
    id: 'stopwatch',
    name: 'Stopwatch',
    svg: '<circle cx="12" cy="14" r="7"/><path d="M12 14l3-3M10 3h4M12 3v4"/>',
  ),
  'text': ToolDef(
    id: 'text',
    name: 'Text tools',
    svg:
        '<path d="M4 18l4.5-12L13 18M5.7 14h5.6M15.5 13.5a2.5 2.5 0 1 1 5 0V18M20.5 15.5c-1.5-.8-5-.8-5 1.2 0 1.8 3.5 1.8 5 0"/>',
  ),
  'pass': ToolDef(
    id: 'pass',
    name: 'Password',
    svg:
        '<circle cx="8" cy="15" r="4"/><path d="M11 12l9-9M16.5 6.5l2.5 2.5M14 9l2 2"/>',
  ),
  'unit': ToolDef(
    id: 'unit',
    name: 'Units',
    svg:
        '<rect x="2.5" y="8" width="19" height="8" rx="1.5"/><path d="M6.5 8v3M10 8v4.5M13.5 8v3M17 8v4.5"/>',
  ),
  'media': ToolDef(
    id: 'media',
    name: 'Media',
    svg:
        '<path d="M9 18V6l11-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
  ),
  'gen': ToolDef(
    id: 'gen',
    name: 'Generate',
    svg:
        '<path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"/>',
  ),
  'folders': ToolDef(
    id: 'folders',
    name: 'Folders',
    svg:
        '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  ),
  'snippets': ToolDef(
    id: 'snippets',
    name: 'Snippets',
    svg: '<path d="M8 6l-5 6 5 6M16 6l5 6-5 6M13.5 4l-3 16"/>',
  ),
  'search': ToolDef(
    id: 'search',
    name: 'Search',
    svg: '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
  ),
  'clock': ToolDef(
    id: 'clock',
    name: 'World clock',
    svg:
        '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
  ),
  'awake': ToolDef(
    id: 'awake',
    name: 'Keep awake',
    kind: ToolKind.action,
    action: 'awake',
    svg:
        '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
  ),
  'pinwin': ToolDef(
    id: 'pinwin',
    name: 'Pin window',
    kind: ToolKind.action,
    action: 'pinwin',
    svg: '<path d="M9 4h6l-1 5 3 3v2H7v-2l3-3zM12 14v7"/>',
  ),
  'desktop': ToolDef(
    id: 'desktop',
    name: 'Desktop',
    kind: ToolKind.action,
    action: 'desktop',
    svg:
        '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
  ),
  'screenoff': ToolDef(
    id: 'screenoff',
    name: 'Screen off',
    kind: ToolKind.action,
    action: 'screenoff',
    svg:
        '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4M15 8a3.2 3.2 0 1 1-3-2 2.5 2.5 0 0 0 3 2z"/>',
  ),
  'lock': ToolDef(
    id: 'lock',
    name: 'Lock PC',
    kind: ToolKind.action,
    action: 'lock',
    svg:
        '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V7.5a3.5 3.5 0 0 1 7 0v3M12 14.5v2"/>',
  ),
  'taskmgr': ToolDef(
    id: 'taskmgr',
    name: 'Task Mgr',
    kind: ToolKind.action,
    action: 'taskmgr',
    svg: '<path d="M3 12h4l3-7 4 14 3-7h4"/>',
  ),
  'settings': ToolDef(
    id: 'settings',
    name: 'Settings',
    fixed: true,
    svg:
        '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  ),
  'winset': ToolDef(
    id: 'winset',
    name: 'Win Settings',
    kind: ToolKind.action,
    action: 'winset',
    svg:
        '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
  ),
};

/// Media panel button icons.
const Map<String, String> kMediaIcons = {
  'prev': '<path d="M19 5L9 12l10 7zM5 5v14"/>',
  'play': '<path d="M7 4l12 8-12 8z"/>',
  'next': '<path d="M5 5l10 7-10 7zM19 5v14"/>',
  'voldown': '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M17 12h4"/>',
  'mute': '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M17 9l4 6M21 9l-4 6"/>',
  'volup': '<path d="M4 9v6h4l5 4V5L8 9z"/><path d="M17 12h4M19 10v4"/>',
};

import '../l10n/utility_strings.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'models.dart';
import 'native.dart';
import 'registry.dart';
import 'spring.dart';
import 'storage.dart';
import 'theme_defs.dart';
import 'package:nex_ui/nex_ui.dart';

/// The persisted settings, JSON-compatible with the original app
/// Domain content is held only by nex_data; this is shell-only JSON.
class Settings {
  Settings();

  String theme = 'midnight';
  String language = 'fa';
  String? installLanguageMarker;
  String preset = 'classic';
  String hotkey = 'N';
  Color accent = const Color(0xFF000000);
  bool startup = false;
  bool paste = true;
  bool magnify = true;
  bool panelPinned = false;
  List<String> recentEmoji = [];
  List<Color> recentColors = [];
  String edge = 'right';
  int monitor = 0;
  bool updates = true;
  int lastCheck = 0;
  List<String> hidden = [];
  List<AppItem> apps = [];
  List<String> snippets = [];
  List<String> pins = [];
  String engine = 'Google';
  List<String> zones = [
    'UTC',
    'Europe/London',
    'America/New_York',
    'Asia/Tokyo',
  ];
  List<String>? dock;
  List<String>? more;

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  static Color _col(dynamic v) {
    var s = (v ?? '#000000').toString();
    if (s.length == 7 && s.startsWith('#')) {
      return Color(int.parse('FF${s.substring(1)}', radix: 16));
    }
    if (s.length == 9 && s.startsWith('#')) {
      return Color(int.parse(s.substring(1), radix: 16));
    }
    return const Color(0xFF000000);
  }

  Map<String, dynamic> toMap() => {
    'theme': theme,
    'language': language,
    'installLanguageMarker': installLanguageMarker,
    'preset': preset,
    'hotkey': hotkey,
    'accent': _hex(accent),
    'startup': startup,
    'paste': paste,
    'magnify': magnify,
    'panelPinned': panelPinned,
    'recentEmoji': recentEmoji,
    'recentColors': recentColors.map(_hex).toList(),
    'edge': edge,
    'monitor': monitor,
    'updates': updates,
    'lastCheck': lastCheck,
    'hidden': hidden,
    'apps': apps.map((a) => a.toJson()).toList(),
    'snippets': snippets,
    'pins': pins,
    'engine': engine,
    'zones': zones,
    'dock': dock,
    'more': more,
  };

  static Settings fromMap(Map<String, dynamic> j) {
    final s = Settings();
    s.theme = j['theme'] as String? ?? 'midnight';
    s.language = j['language'] as String? ?? 'fa';
    s.installLanguageMarker = j['installLanguageMarker'] as String?;
    s.preset = j['preset'] as String? ?? 'classic';
    s.hotkey = j['hotkey'] as String? ?? 'N';
    s.accent = _col(j['accent']);
    s.startup = j['startup'] as bool? ?? false;
    s.paste = j['paste'] as bool? ?? true;
    s.magnify = j['magnify'] as bool? ?? true;
    s.panelPinned = j['panelPinned'] as bool? ?? false;
    s.recentEmoji = ((j['recentEmoji'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    s.recentColors = ((j['recentColors'] as List?) ?? [])
        .map((e) => _col(e))
        .toList();
    s.edge = j['edge'] as String? ?? 'right';
    s.monitor = (j['monitor'] as num?)?.toInt() ?? 0;
    s.updates = j['updates'] as bool? ?? true;
    s.lastCheck = (j['lastCheck'] as num?)?.toInt() ?? 0;
    s.hidden = ((j['hidden'] as List?) ?? []).map((e) => e.toString()).toList();
    s.apps = ((j['apps'] as List?) ?? [])
        .whereType<Map>()
        .map((m) => AppItem.fromJson(m.cast<String, dynamic>()))
        .toList();
    s.snippets = ((j['snippets'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    s.pins = ((j['pins'] as List?) ?? []).map((e) => e.toString()).toList();
    s.engine = j['engine'] as String? ?? 'Google';
    s.zones = ((j['zones'] as List?) ?? []).map((e) => e.toString()).toList();
    s.dock = (j['dock'] as List?)?.map((e) => e.toString()).toList();
    s.more = (j['more'] as List?)?.map((e) => e.toString()).toList();
    return s;
  }
}

/// No-op host used when none is injected (tests).
class _StubNativeHost extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

/// Info about a dockable widget: a registry tool or a pinned app.
class ToolInfo {
  const ToolInfo({
    required this.id,
    required this.name,
    this.emoji,
    this.svg,
    required this.kind,
    this.dockOnly = false,
    this.fixed = false,
    this.action,
    this.app,
  });

  factory ToolInfo.of(String id) {
    if (id.startsWith('app-')) {
      final app = _controllerApps.firstWhere(
        (a) => a.id == id,
        orElse: () => AppItem(id: id, name: 'App', path: ''),
      );
      return ToolInfo(
        id: id,
        name: app.name,
        emoji: app.icon == null ? '🚀' : null,
        kind: ToolKind.app,
        app: app,
      );
    }
    final w = kTools[id]!;
    return ToolInfo(
      id: id,
      name: w.name,
      emoji: w.emoji,
      svg: w.svg,
      kind: w.kind,
      dockOnly: w.dockOnly,
      fixed: w.fixed,
      action: w.action,
    );
  }

  static List<AppItem> _controllerApps = [];

  final String id;
  final String name;
  final String? emoji;
  final String? svg;
  final ToolKind kind;
  final bool dockOnly;
  final bool fixed;
  final String? action;
  final AppItem? app;
}

/// Per-tool springs, preserved across re-renders (like el._s / el._m / el._p
/// on the DOM nodes) so tools never re-pop when the list is rebuilt.
class ToolSprings {
  ToolSprings()
    : sp = Spring(0, 380, 25),
      mg = Spring(0, 500, 30),
      pr = Spring(0, 700, 28);
  final Spring sp;
  final Spring mg;
  final Spring pr;
}

/// Owns every bit of app state and all interactions; the port of the
/// original's module-level script plus the `app` object.
class PanelController extends ChangeNotifier {
  PanelController({NativeHost? nativeHost})
    : native = nativeHost ?? _StubNativeHost() {
    _wireNative();
  }

  final Storage storage = Storage();
  final NativeHost native;
  late final NavigatorObserver routeObserver = _PanelRouteObserver(this);
  bool _persistSettings = true;
  Future<void> Function()? beforeShutdown;
  void Function()? onCapture;
  void Function(List<String>)? importFiles;

  late Settings S;
  List<ClipEntry> clips = [];
  String lastClip = '';
  bool awake = false;
  bool picking = false;
  bool settingsChangedWhileTyping = false;

  // ---- interaction state (module-level vars of the original) ----
  bool isOpen = false;
  String? panel;

  /// The panel that was open last; the flyout keeps showing it while it
  /// shrinks away ("keep old content while it shrinks away" in the original).
  String? lastPanel;
  bool sub = false;
  bool sticky = false;
  bool dragging = false;
  double anchorY = 340;
  double mx = -1; // logical px from edge, -1 = away
  double? hoverY;
  Timer? outT;
  double openedAt = -1e9;
  double closedAt = -1e9;

  /// Monotonic clock (seconds) maintained by the shell's ticker; the
  /// animation state machine uses it so behavior is deterministic in tests.
  double clockSec = 0;
  bool _quitQueued = false;
  bool _disposed = false;
  final _delayed = <Timer>{};
  void _later(Duration delay, VoidCallback action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _delayed.remove(timer);
      if (!_disposed) action();
    });
    _delayed.add(timer);
  }

  /// Bumped by the shell's ticker every frame; frame-driven widgets listen
  /// to this instead of the whole controller.
  final ValueNotifier<int> frame = ValueNotifier(0);

  /// Current toast message (null = hidden).
  final ValueNotifier<String?> toastMsg = ValueNotifier(null);
  Timer? _toastT;
  int _toastSeq = 0;

  // ---- liquid engine ----
  final Spring slide = Spring(0, 320, 38);
  final Spring grow = Spring(0, 340, 24);
  late final Spring fy = Spring(340, 380, 30);
  final Spring pillY = Spring(0, 420, 26);
  final Spring pillS = Spring(0, 380, 22);
  final Map<String, ToolSprings> toolSprings = {};

  ToolSprings springsFor(String id) =>
      toolSprings.putIfAbsent(id, ToolSprings.new);

  double flyH = 0; // measured by the flyout each layout

  /// Placement hooks filled in by the widgets that know geometry.
  double? Function(String id)? dockAnchorOf;
  double? Function()? moreAnchorOf;
  Rect? tabRect;
  Rect? flyRect;

  Placement? placement;
  List<Map<String, dynamic>> screens = [];

  // ---- dock geometry keys (registered by the dock widget) ----
  final GlobalKey tabBoxKey = GlobalKey();
  final GlobalKey toolsViewportKey = GlobalKey();
  final GlobalKey flyBoxKey = GlobalKey();
  int panelSerial = 0;
  final ScrollController toolScroll = ScrollController();
  final Map<String, GlobalKey> zoneKeys = {
    'dock': GlobalKey(),
    'more': GlobalKey(),
    'wdock': GlobalKey(),
    'wmore': GlobalKey(),
  };
  final Map<String, GlobalKey> toolKeys = {};

  GlobalKey toolKey(String id) => toolKeys.putIfAbsent(id, GlobalKey.new);

  /// The dock tool that carries the pill right now.
  String? get activeToolId => panel != null ? (sub ? 'more' : panel) : null;

  // ---- widget drag & drop (dock <-> More <-> settings lists) ----
  final ValueNotifier<DragInfo?> dragInfo = ValueNotifier(null);
  DragCandidate? _dragCandidate;
  bool _dragMoved = false;

  void beginDragCandidate(String id, Offset position) {
    _dragCandidate = DragCandidate(id, position);
  }

  /// Handles a pointer that might be dragging a widget. Returns true while a
  /// drag is in progress (the shell calls this from its root listener).
  bool handleDragPointer(PointerEvent e) {
    final cand = _dragCandidate;
    if (cand == null) return dragInfo.value != null;
    if (e is PointerUpEvent || e.buttons == 0) {
      {
        _endDrag(e.position);
      }
      return false;
    }
    if (!_dragMoved) {
      if ((e.position - cand.start).distance < 5) return false;
      _dragMoved = true;
      dragging = true;
      cancelClose();
    }
    _updateDrag(cand.id, e.position);
    return true;
  }

  void _updateDrag(String id, Offset p) {
    final zone = _zoneAt(p);
    if (zone == null || (zone == 'more' && (kTools[id]?.dockOnly ?? false))) {
      if (dragInfo.value?.id == id) {
        dragInfo.value = DragInfo(id: id, moved: true, zone: null, pointer: p);
      }
      return;
    }
    final idx = _insertIndex(zone, p, id);
    dragInfo.value = DragInfo(
      id: id,
      moved: true,
      zone: zone,
      insertIdx: idx,
      pointer: p,
    );
  }

  String? _zoneAt(Offset p) {
    for (final entry in zoneKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is RenderBox && box.attached) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (rect.inflate(4).contains(p)) return entry.key;
      }
    }
    return null;
  }

  int _insertIndex(String zone, Offset p, String draggingId) {
    final list = zone == 'dock'
        ? S.dock!
        : zone == 'more'
        ? S.more!
        : zone == 'wdock'
        ? S.dock!
        : S.more!;
    final withHidden = zone.startsWith('w');
    final kids = list
        .where((x) => x != draggingId && (withHidden || !S.hidden.contains(x)))
        .toList();
    final isGrid = zone == 'more';
    for (var i = 0; i < kids.length; i++) {
      final key = toolKeys[kids[i]];
      final ctx = key?.currentContext;
      final box = ctx?.findRenderObject();
      if (box is RenderBox && box.attached) {
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final hit = isGrid
            ? (p.dy < rect.bottom &&
                      (S.language == 'fa'
                          ? p.dx > rect.center.dx
                          : p.dx < rect.center.dx)) ||
                  p.dy < rect.top
            : p.dy < rect.top + rect.height / 2;
        if (hit) return i;
      }
    }
    return kids.length;
  }

  void _endDrag(Offset p) {
    final cand = _dragCandidate;
    final info = dragInfo.value;
    _dragCandidate = null;
    dragging = false;
    dragInfo.value = null;
    if (cand != null && _dragMoved && info?.zone != null) {
      final zone = info!.zone!;
      final list = zone == 'dock' ? 'dock' : 'more';
      moveWidget(
        cand.id,
        list,
        info.insertIdx,
        withHidden: zone.startsWith('w'),
      );
    }
    if (_dragMoved) {
      // clicks that happen right after a drag are swallowed
      Future.delayed(const Duration(milliseconds: 60), () {
        _dragMoved = false;
      });
    }
    notifyListeners();
  }

  /// Guard used by tool taps (the original's dragMoved check).
  bool get dragMoved => _dragMoved;

  /// Port of the tiles click handler (opens as a sub-panel of More).
  void onTileTap(String id) {
    if (_dragMoved) return;
    final w = ToolInfo.of(id);
    if (w.kind == ToolKind.panel) {
      anchorY = fy.v;
      setPanel(id, fromMore: true);
    } else {
      openWidget(id);
    }
  }

  /// Port of the tab click handler.
  void onToolTap(String id) {
    if (_dragMoved) return;
    final w = ToolInfo.of(id);
    if (w.kind == ToolKind.app) {
      _later(const Duration(milliseconds: 160), () {
        close();
        unawaited(native.launch(w.app!.path).catchError((_) {}));
      });
      return;
    }
    if (w.kind == ToolKind.action) {
      runAction(w.action!);
      return;
    }
    anchorY = dockAnchorOf?.call(id) ?? anchorY;
    setPanel(panel == id && !sub ? null : id);
  }

  // ---- timer / stopwatch (kept alive across panel closes) ----
  int tTotal = 300;
  int tLeft = 300;
  Timer? tRun;

  void timerPreset(int minutes) {
    tRun?.cancel();
    tRun = null;
    tTotal = tLeft = minutes * 60;
    notifyListeners();
  }

  void timerToggle() {
    if (tRun != null) {
      tRun?.cancel();
      tRun = null;
    } else {
      if (tLeft == 0) tLeft = tTotal;
      tRun = Timer.periodic(const Duration(seconds: 1), (_) {
        tLeft--;
        if (tLeft <= 0) {
          tRun?.cancel();
          tRun = null;
          tLeft = 0;
          unawaited(native.beep().catchError((_) {}));
          sticky = true;
          open();
          _later(const Duration(milliseconds: 140), () => openWidget('timer'));
          toast('⏰ Time is up!');
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void timerReset() {
    tRun?.cancel();
    tRun = null;
    tLeft = tTotal;
    notifyListeners();
  }

  double swStart = 0;
  int swAcc = 0;
  Timer? swTimer;
  List<int> swLaps = [];
  final ValueNotifier<String> swDisplay = ValueNotifier('00:00.00');

  int get swNow =>
      swAcc +
      (swTimer != null
          ? (DateTime.now().millisecondsSinceEpoch - swStart).round()
          : 0);

  void swToggle() {
    if (swTimer != null) {
      swAcc = swNow;
      swTimer?.cancel();
      swTimer = null;
      swDisplay.value = fmtSwValue(swAcc);
    } else {
      swStart = DateTime.now().millisecondsSinceEpoch.toDouble();
      swTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        swDisplay.value = fmtSwValue(swNow);
      });
    }
    notifyListeners();
  }

  void swLapOrReset() {
    if (swTimer != null) {
      swLaps.insert(0, swNow);
    } else {
      swAcc = 0;
      swLaps = [];
      swDisplay.value = fmtSwValue(0);
    }
    notifyListeners();
  }

  static String fmtSwValue(int ms) =>
      '${(ms ~/ 60000).toString().padLeft(2, '0')}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${((ms ~/ 10) % 100).toString().padLeft(2, '0')}';

  int _textFocusCount = 0;
  void focusGained() => _textFocusCount++;
  void focusLost() => _textFocusCount = math.max(0, _textFocusCount - 1);
  bool get typing => _textFocusCount > 0;

  int _interactionCount = 0;
  bool get interacting => _interactionCount > 0;
  bool get keepOpen => S.panelPinned || interacting || typing;

  /// An owned lease keeps readers, recorders and OS dialogs visible. Releasing
  /// one lease cannot accidentally unlock another overlapping interaction.
  VoidCallback holdOpen() {
    _interactionCount++;
    cancelClose();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _interactionCount--;
      if (isOpen) sticky = true;
    };
  }

  void togglePanelPin() {
    S.panelPinned = !S.panelPinned;
    cancelClose();
    save();
    refresh();
  }

  /// Public notify for views (ChangeNotifier.notifyListeners is protected).
  void refresh() => notifyListeners();

  LiquidPalette get palette => paletteFromTheme(appTheme);
  ThemeData get appTheme {
    final base = nexApplyThemePreset(
      S.theme == 'light' || S.theme == 'sky'
          ? nexLightTheme(
              transparentScaffold: true,
              fontFamily: nexFontFor(Locale(S.language)),
            )
          : nexDarkTheme(
              transparentScaffold: true,
              fontFamily: nexFontFor(Locale(S.language)),
            ),
      S.preset,
      nexThemePresetSeed(S.preset),
    );
    final scheme = base.colorScheme;
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: .16)),
    );
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: .16)),
          minimumSize: const Size(0, 42),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          maximumSize: const Size(40, 40),
          padding: const EdgeInsets.all(8),
        ),
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        waitDuration: const Duration(milliseconds: 600),
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: scheme.onSurface.withValues(alpha: .12),
      ),
    );
  }

  double get dir => S.edge == 'left' ? -1 : 1;
  double get screenHeight => 680;

  // ================= lifecycle =================
  /// [preset] and [useNative] exist so tests can boot without touching
  /// the filesystem or the platform channel.
  Future<void> bootstrap({
    Settings? preset,
    bool useNative = true,
    String? installerLanguageMarker,
  }) async {
    _persistSettings = preset == null;
    S = preset ?? Settings.fromMap(storage.loadSettings());
    final installLanguage = installerLanguageMarker?.trim();
    if (installLanguage != null && installLanguage != S.installLanguageMarker) {
      final locale = installLanguage.split('|').first;
      if (locale == 'en' || locale == 'fa') {
        S.language = locale;
        S.installLanguageMarker = installLanguage;
      }
    }

    if (useNative) {
      // startup flag comes from the registry, like the original
      try {
        S.startup = await native.startupEnabled();
      } catch (_) {}
    }

    // migrate/normalize dock & more lists
    normalize();
    // Repair empty launcher entries left by the old cancelled-picker bug.
    S.apps.removeWhere((app) => app.path.trim().isEmpty);
    normalize();
    if (preset == null && installLanguage != null) save();

    ToolInfo._controllerApps = S.apps;
    if (preset == null) clips = storage.loadPinnedImages();

    if (useNative) {
      try {
        final p = await native.applyPlacement(S.edge, S.monitor);
        if (p != null) placement = Placement.fromMap(p);
      } catch (_) {}
      try {
        screens = await native.screens();
      } catch (_) {}
      _startEdgeWatch();
      await native.ready().catchError((_) {});
      if (S.hotkey != 'N') await native.configureHotkey(S.hotkey);

      // re-read icons of saved apps (clean, no shortcut arrow)
      for (final a in S.apps) {
        unawaited(native.appIcon(a.id, a.path).catchError((_) {}));
      }
    }
  }

  void normalize() {
    S.dock ??= ['note', 'timeline', 'more', ...S.apps.map((a) => a.id)];
    S.more ??= [...kDefaultMore];
    final known = <String>{
      ...kTools.keys.where((k) => !kTools[k]!.fixed),
      ...S.apps.map((a) => a.id),
    };
    S.dock = S.dock!.where(known.contains).toSet().toList();
    S.more = S.more!
        .where(
          (id) =>
              known.contains(id) &&
              !S.dock!.contains(id) &&
              !(kTools[id]?.dockOnly ?? false),
        )
        .toSet()
        .toList();
    if (!S.dock!.contains('more')) S.dock!.add('more');
    for (final id in known) {
      if (!S.dock!.contains(id) && !S.more!.contains(id)) S.more!.add(id);
    }
  }

  void _wireNative() {
    if (native is WinNativeHost) {
      (native as WinNativeHost).events = NativeEvents(
        onPlacement: (map) async {
          placement = Placement.fromMap(map);
          S.edge = placement!.onLeft ? 'left' : 'right';
          S.monitor = (map['monitor'] as num?)?.toInt() ?? S.monitor;
          try {
            screens = await native.screens();
          } catch (_) {}
          if (!_disposed) notifyListeners();
        },
        onClipText: clip,
        onClipImage: (img) => addClipImage(img),
        onTray: onTray,
        onBlur: blur,
        onFilesDropped: onFilesDropped,
        onPickedColor: onPickedColor,
        onPickedCustomColor: onPickedCustomColor,
        onPickedApp: (path) => appAdded(path: path),
        onPickerState: setPickerActive,
        onAppIcon: iconFor,
      );
    }
  }

  void save() {
    ToolInfo._controllerApps = S.apps;
    if (_persistSettings) storage.saveSettings(S.toMap());
  }

  // ================= the `app` object =================
  void open() {
    cancelClose();
    unawaited(native.setPassthrough(false).catchError((_) {}));
    if (isOpen) return;
    isOpen = true;
    openedAt = clockSec;
    notifyListeners();
  }

  void close() {
    if (!isOpen) return;
    isOpen = false;
    sticky = false;
    closedAt = clockSec;
    setPanel(null);
    mx = -1;
    hoverY = null;
    notifyListeners();
    // Let the original spring exit finish before hiding the native host.
    _later(const Duration(milliseconds: 450), () {
      if (!isOpen) unawaited(native.setPassthrough(true).catchError((_) {}));
    });
  }

  void cursor(double dist) => mx = dist;

  void show(String name) {
    sticky = true;
    open();
    if (name.isNotEmpty) {
      _later(const Duration(milliseconds: 140), () {
        if (isOpen) openWidget(name);
      });
    }
  }

  void appAdded({required String path, String? icon}) {
    if (path.trim().isEmpty) return;
    if (S.apps.any((app) => app.path.toLowerCase() == path.toLowerCase())) {
      return;
    }
    final id = 'app-${DateTime.now().millisecondsSinceEpoch}';
    S.apps.add(
      AppItem(id: id, name: Storage.displayName(path), path: path, icon: icon),
    );
    final at = math.max(0, S.dock!.indexOf('more'));
    S.dock!.insert(at, id);
    save();
    notifyListeners();
    toast(message('Added {value}', {'value': Storage.displayName(path)}));
    unawaited(native.appIcon(id, path).catchError((_) {}));
  }

  void iconFor(String id, String icon) {
    final a = S.apps.where((x) => x.id == id).toList();
    if (a.isEmpty || icon.isEmpty) return;
    if (a.first.icon != icon) {
      a.first.icon = icon;
      save();
      notifyListeners();
    }
  }

  void syncStartup(bool v) {
    S.startup = v;
    save();
    notifyListeners();
  }

  void blur() {
    if (isOpen && !keepOpen && !sticky && !dragging && !picking) close();
  }

  void setPickerActive(bool active) {
    picking = active;
    cancelClose();
    if (!active && isOpen) sticky = true;
  }

  void clip(String text) => addClip(text);

  void addClip(String text) {
    if (text.trim().isEmpty) return;
    lastClip = text;
    clips = [
      ClipEntry.text(text, time: DateTime.now()),
      ...clips.where((c) => c.text != text || c.isImage),
    ].take(50).toList();
    notifyListeners();
  }

  void addClipImage(ClipImage img) {
    clips = [
      ClipEntry.image(img, time: DateTime.now()),
      ...clips.where((c) => c.image?.id != img.id),
    ].take(50).toList();
    notifyListeners();
  }

  void onPickedColor(String? hex) {
    picking = false;
    if (hex == null) return;
    // setColor + pushRecentColor + copy + open the color panel
    unawaited(Clipboard.setData(ClipboardData(text: hex)));
    pickedColorHex = hex;
    pushRecentColor(_parseHex(hex));
    open();
    openWidget('color');
    notifyListeners();
    toast(message('Picked {value}', {'value': hex}));
  }

  String pickedColorHex = '#3b82f6';
  Future<void> pickCustomColorFor(String target) async {
    await native.pickCustomColor(pickedColorHex).catchError((_) {});
  }

  void onPickedCustomColor(String? hex) {
    if (hex == null) return;
    pickedColorHex = hex;
    notifyListeners();
  }

  /// Moves the panel to the chosen edge / monitor (placement message).
  Future<void> applyPlacement(String edge, int monitor) async {
    S.edge = edge;
    S.monitor = monitor;
    save();
    try {
      final p = await native.applyPlacement(edge, monitor);
      if (p != null) placement = Placement.fromMap(p);
    } catch (_) {}
    notifyListeners();
    toast(
      message('Panel moved to the {value}', {
        'value': utilityForLocale(
          S.language,
          edge == 'left' ? 'Left' : 'Right',
        ),
      }),
    );
  }

  void onPickedApp(String path) {
    if (path.isEmpty) return;
    appAdded(path: path);
    show('settings');
  }

  void onFilesDropped(List<String> paths) {
    dropHintOn.value = false;
    if (importFiles != null) {
      importFiles!(paths);
      return;
    }
    for (final path in paths) {
      appAdded(path: path);
    }
  }

  void onTray(String id) {
    switch (id) {
      case 'capture':
        sticky = true;
        open();
        openWidget('note');
        onCapture?.call();
        break;
      case 'shutdown':
        unawaited(quit());
        break;
      case 'open':
        show('');
        break;
      case 'settings':
        show('settings');
        break;
      case 'addapp':
        unawaited(native.pickApp().catchError((_) {}));
        break;
      case 'startup':
        final on = !S.startup;
        S.startup = on;
        unawaited(native.setStartup(on).catchError((_) {}));
        save();
        notifyListeners();
        break;
      case 'quit':
        quit();
        break;
    }
  }

  Future<void> quit() async {
    if (_quitQueued) return;
    _quitQueued = true;
    try {
      await beforeShutdown?.call();
    } catch (_) {
      _quitQueued = false;
      return;
    }
    await native.quit().catchError((_) {});
  }

  // ---- flyout panel switching (setPanel) ----
  void setPanel(String? name, {bool fromMore = false}) {
    if (name != null && panel == null) {
      fy.v = anchorY;
      fy.vel = 0;
      grow.v = 0;
      grow.vel = 0;
    } else if (name != null && panel != null && name != panel) {
      grow.vel -= 3; // little squish when switching
    }
    if (name != null) {
      if (name != panel) panelSerial++;
      lastPanel = name;
    }
    panel = name;
    sub = name != null && fromMore;
    notifyListeners();
  }

  void openWidget(String id) {
    final w = ToolInfo.of(id);
    if (w.kind == ToolKind.app) {
      _later(const Duration(milliseconds: 160), () {
        close();
        unawaited(native.launch(w.app!.path).catchError((_) {}));
      });
      return;
    }
    if (w.kind == ToolKind.action) {
      runAction(w.action!);
      return;
    }
    final dockAnchor = dockAnchorOf?.call(id);
    if (S.dock!.contains(id) || (dockAnchor != null && dockAnchor.isFinite)) {
      anchorY = dockAnchor ?? anchorY;
      setPanel(id);
    } else {
      final m = moreAnchorOf?.call();
      anchorY = m ?? 340;
      setPanel(id, fromMore: true);
    }
  }

  void runAction(String action) {
    switch (action) {
      case 'shot':
        close();
        unawaited(native.screenshot().catchError((_) {}));
        break;
      case 'awake':
        toggleAwake();
        break;
      case 'pinwin':
        native
            .pinWindow()
            .then((result) {
              final parts = result.split('\n');
              toast(
                parts.length == 2
                    ? message(
                        parts.first == 'pinned'
                            ? 'Pinned {value}'
                            : 'Unpinned {value}',
                        {'value': parts.last},
                      )
                    : result,
              );
            })
            .catchError((_) {});
        break;
      case 'desktop':
        close();
        unawaited(native.pressKey('desktop').catchError((_) {}));
        break;
      case 'screenoff':
        close();
        unawaited(native.screenOff().catchError((_) {}));
        break;
      case 'lock':
        close();
        unawaited(native.lock().catchError((_) {}));
        break;
      case 'taskmgr':
        close();
        unawaited(native.launch('taskmgr').catchError((_) {}));
        break;
      case 'winset':
        close();
        unawaited(native.launch('ms-settings:').catchError((_) {}));
        break;
    }
  }

  void toggleAwake() {
    awake = !awake;
    unawaited(native.keepAwake(awake).catchError((_) {}));
    toast(awake ? '☀ PC stays awake' : 'Sleep allowed again');
    notifyListeners();
  }

  // ---- clipboard history ops ----
  void deliver(String text) {
    if (S.paste) {
      close();
      unawaited(native.pasteIntoPrevious(text).catchError((_) {}));
    } else {
      copy(text);
    }
  }

  void copy(String text, [String? msg]) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    toast(msg ?? 'Copied');
  }

  void togglePinClip(ClipEntry c) {
    if (c.isImage) {
      c.pinned = !c.pinned;
      if (c.pinned) {
        storage.pinImage(c.image!);
      } else {
        storage.unpinImage(c.image!.id);
      }
    } else {
      if (c.pinned) {
        S.pins = S.pins.where((x) => x != c.text).toList();
        c.pinned = false;
      } else {
        S.pins = [c.text!, ...S.pins].take(30).toList();
        c.pinned = true;
      }
      save();
    }
    notifyListeners();
  }

  void removeClip(ClipEntry c) {
    if (c.isImage) {
      if (c.pinned) storage.unpinImage(c.image!.id);
      clips = clips.where((x) => x.image?.id != c.image!.id).toList();
    } else {
      if (c.pinned) {
        S.pins = S.pins.where((x) => x != c.text).toList();
        save();
      }
      clips = clips.where((x) => x.text != c.text).toList();
    }
    notifyListeners();
  }

  void copyImage(ClipImage img) {
    unawaited(
      native.setClipboardImage(img.w, img.h, img.rgba).catchError((_) {}),
    );
    toast('Image copied');
  }

  // ---- widget manager (drag & drop) ----
  void moveWidget(String id, String list, int idx, {bool withHidden = false}) {
    if (list == 'more' && (kTools[id]?.dockOnly ?? false)) return;
    final wasHidden = S.hidden.contains(id);
    final target = list == 'dock' ? S.dock! : S.more!;
    final visible = target
        .where((x) => x != id && (withHidden || !S.hidden.contains(x)))
        .toList();
    final anchor = idx < visible.length ? visible[idx] : null;
    S.dock = S.dock!.where((x) => x != id).toList();
    S.more = S.more!.where((x) => x != id).toList();
    final dest = list == 'dock' ? S.dock! : S.more!;
    var at = anchor != null ? dest.indexOf(anchor) : dest.length;
    if (at < 0) at = dest.length;
    dest.insert(at, id);
    if (wasHidden && !withHidden) {
      S.hidden = S.hidden.where((x) => x != id).toList();
    }
    save();
    notifyListeners();
    if (list == 'dock' && panel == 'more') {
      toast(
        message('{value} → dock', {
          'value': utilityForLocale(S.language, ToolInfo.of(id).name),
        }),
      );
    }
  }

  void toggleHidden(String id) {
    if (S.hidden.contains(id)) {
      S.hidden = S.hidden.where((x) => x != id).toList();
    } else {
      S.hidden = [...S.hidden, id];
    }
    save();
    notifyListeners();
  }

  void removeApp(String id) {
    S.apps = S.apps.where((x) => x.id != id).toList();
    S.dock = S.dock!.where((x) => x != id).toList();
    S.more = S.more!.where((x) => x != id).toList();
    ToolInfo._controllerApps = S.apps;
    save();
    notifyListeners();
  }

  // ---- misc ----
  void pushRecentEmoji(String em) {
    S.recentEmoji = [
      em,
      ...S.recentEmoji.where((x) => x != em),
    ].take(28).toList();
    save();
  }

  void pushRecentColor(Color c) {
    S.recentColors = [
      c,
      ...S.recentColors.where((x) => x != c),
    ].take(16).toList();
    save();
    notifyListeners();
  }

  Color _parseHex(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  final ValueNotifier<bool> dropHintOn = ValueNotifier(false);

  String message(String text, Map<String, String> values) {
    var result = utilityForLocale(S.language, text);
    for (final e in values.entries) {
      result = result.replaceAll('{${e.key}}', e.value);
    }
    return result;
  }

  void toast(String msg) {
    msg = utilityForLocale(S.language, msg);
    _toastSeq++;
    toastMsg.value = '$msg\x00$_toastSeq';
    _toastT?.cancel();
    _toastT = Timer(const Duration(milliseconds: 1600), () {
      toastMsg.value = null;
    });
  }

  bool maybeClose() {
    if (isOpen && !keepOpen && !sticky && !dragging && !picking) {
      outT?.cancel();
      outT = Timer(const Duration(milliseconds: 600), () {
        if (!keepOpen && !sticky && !dragging && !picking) close();
      });
      return true;
    }
    return false;
  }

  void cancelClose() => outT?.cancel();

  /// Port of `inside()` — is the pointer within the tab / flyout (with the
  /// original's tolerance margins)?
  bool inside(Offset p) {
    final t = tabRect;
    if (t != null) {
      final nearTab = dir > 0 ? p.dx > t.left - 16 : p.dx < t.right + 16;
      if (nearTab && p.dy > t.top - 30 && p.dy < t.bottom + 30) return true;
    }
    if (panel != null) {
      final f = flyRect;
      if (f != null) {
        final inFly = dir > 0
            ? (p.dx > f.left - 16 && p.dx < (t?.left ?? 0) + 4)
            : (p.dx < f.right + 16 && p.dx > (t?.right ?? 480) - 4);
        if (inFly && p.dy > f.top - 16 && p.dy < f.bottom + 16) return true;
      }
    }
    return false;
  }

  // ================= edge watcher (Dart FFI port of spawn_edge_watch) =================
  Timer? _edgeT;
  bool _near = false;
  int _lastX = -2147483648, _lastY = -2147483648;
  int _held = 0;

  void _startEdgeWatch() {
    if (!native.ffiAvailable) return;
    _edgeT?.cancel();
    _edgeT = Timer.periodic(
      const Duration(milliseconds: 12),
      (_) => _edgeTick(),
    );
  }

  Future<void> _edgeTick() async {
    if (isOpen || picking) {
      _near = false;
      return;
    }
    final pos = native.cursorPos();
    if (pos == null) return;
    final (px, py) = pos;
    final pl = placement;
    if (pl == null) return;
    final (winY, h, edge) = (pl.y, pl.h, pl.edgeX);
    final left = pl.onLeft;
    final moved = px != _lastX || py != _lastY;
    _lastX = px;
    _lastY = py;
    final inBand = py >= winY && py < winY + h;
    final dist = left ? px - edge : edge - 1 - px;
    // a held button usually means dragging something: wait until it rests
    final buttonDown = native.leftDown();
    if (buttonDown && inBand && dist >= 0 && dist <= 1) {
      _held++;
    } else {
      _held = 0;
    }
    if (!buttonDown && dropHintOn.value) dropHintOn.value = false;
    if ((moved || _held == 31) &&
        inBand &&
        dist >= 0 &&
        dist <= 8 * pl.scale &&
        (!buttonDown || _held > 30)) {
      unawaited(native.rememberForeground().catchError((_) {}));
      unawaited(native.setPassthrough(false).catchError((_) {}));
      open();
      if (buttonDown) dropHintOn.value = true;
      _near = false;
    } else if (inBand && dist >= 0 && dist < (160 * pl.scale)) {
      _near = true;
      cursor(dist / pl.scale);
    } else if (_near) {
      _near = false;
      cursor(-1);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _delayed) {
      timer.cancel();
    }
    _delayed.clear();
    if (native is WinNativeHost) (native as WinNativeHost).dispose();
    tRun?.cancel();
    swTimer?.cancel();
    swDisplay.dispose();
    toolScroll.dispose();
    dragInfo.dispose();
    dropHintOn.dispose();
    _edgeT?.cancel();
    _toastT?.cancel();
    outT?.cancel();
    frame.dispose();
    toastMsg.dispose();
    super.dispose();
  }
}

/// Popup menus and secondary routes can extend beyond the measured flyout.
/// Keep their host alive until Navigator dismisses them.
class _PanelRouteObserver extends NavigatorObserver {
  _PanelRouteObserver(this.controller);
  final PanelController controller;
  final _holds = <Route<dynamic>, VoidCallback>{};
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _holds[route] = controller.holdOpen();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _release(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _release(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final held = _holds.containsKey(oldRoute);
    if (oldRoute != null) _release(oldRoute);
    if (held && newRoute != null) _holds[newRoute] = controller.holdOpen();
  }

  void _release(Route<dynamic> route) => _holds.remove(route)?.call();
}

Color hexToColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF000000);
}

String colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

/// Live drag state for widget reordering (ghost, hovered zone, insert index).
class DragInfo {
  DragInfo({
    required this.id,
    required this.moved,
    this.zone,
    this.insertIdx = 0,
    this.pointer,
  });

  final String id;
  final bool moved;
  final String? zone; // dock | more | wdock | wmore
  final int insertIdx;
  final Offset? pointer;
}

class DragCandidate {
  DragCandidate(this.id, this.start);

  final String id;
  final Offset start;
}

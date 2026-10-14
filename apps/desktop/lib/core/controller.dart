import '../l10n/utility_strings.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'models.dart';
import 'native.dart';
import 'display_identity.dart';
import 'panel_geometry.dart';
import 'panel_holds.dart';
import 'panel_settings.dart';
import 'registry.dart';
import 'spring.dart';
import 'storage.dart';
import 'clipboard_state.dart';
import 'theme_defs.dart';
import 'package:nex_ui/nex_ui.dart';

export 'panel_settings.dart';
export 'panel_geometry.dart';
export 'panel_holds.dart';
export 'panel_window_mode.dart';
export 'panel_utility_state.dart';

part 'controller_actions.dart';
part 'controller_clipboard.dart';
part 'controller_lifecycle.dart';
part 'controller_timers.dart';
part 'controller_wiring.dart';
part 'controller_window_mode.dart';
part 'controller_panel_dismissal.dart';

/// No-op host used when none is injected (tests).
class _StubNativeHost extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

abstract class PanelStateBase extends ChangeNotifier implements PanelHoldable {
  PanelStateBase({NativeHost? nativeHost, Storage? storage})
    : storage = storage ?? Storage(),
      native = nativeHost ?? _StubNativeHost() {
    clipboard.addListener(_clipboardChanged);
  }
  void _clipboardChanged() {
    if (!_disposed) notifyListeners();
  }

  // ==== forward declarations ====
  void bootstrap({
    Settings? preset,
    bool useNative = true,
    bool showWindow = true,
    bool forcePanelMode = false,
  });
  void normalize();
  void save();
  void open();
  void close();
  void show(String name);
  void cursor(double dist);
  void openWidget(String id);
  void setPanel(String? name, {bool fromMore = false});
  void runAction(String action);
  void selectWindowSection(String section);
  void openWindowTool(String id);
  void backToTools();
  void deliver(String text);
  void copy(String text, [String? msg]);
  void addClip(String text);
  void addClipImage(ClipImage img);
  void onTileTap(String id);
  void onToolTap(String id);
  void beginDragCandidate(String id, Offset position);
  bool handleDragPointer(PointerEvent e);
  void moveWidget(String id, String list, int idx, {bool withHidden = false});
  void appAdded({required String path, String? icon});
  Future<void> setWindowMode(String mode);
  Future<void> _rememberWindowFrame();
  Future<void> quit();
  void _wireNative();
  void clip(String text);
  void onTray(String id);
  void blur();
  void onFilesDropped(List<String> paths);
  void onPickedColor(String? hex);
  void onPickedCustomColor(String? hex);
  void setPickerActive(bool active);
  void iconFor(String id, String icon);
  void disposeTimers();
  void dismissPanel({Offset? at});
  void pollPanelPointer();

  final Storage storage;
  final clipboard = ClipboardState();
  final NativeHost native;
  late final NavigatorObserver routeObserver = PanelRouteObserver(this);
  bool _persistSettings = true;
  Future<void> Function()? beforeShutdown;
  void Function()? onCapture;
  void Function(String)? onOpenNote;
  void Function(List<String>)? importFiles;

  late Settings S;
  List<ClipEntry> get clips => clipboard.entries;
  set clips(List<ClipEntry> entries) => clipboard.seed(entries);
  String lastClip = '';
  bool awake = false;
  bool awakeBusy = false;
  bool picking = false;
  bool settingsChangedWhileTyping = false;

  // ---- interaction state (module-level vars of the original) ----
  bool isOpen = false;
  bool windowModeChanging = false;
  String? panel;

  /// The main mode: 'window' shows the full desktop window shell; 'panel'
  /// keeps only the right/left-edge slide-out. Both share the same data,
  /// settings and features.
  bool get isWindowMode => S.windowMode == 'window';

  /// Section shown by the desktop window shell: capture | library | tools |
  /// settings. A ValueNotifier so the shell can listen without rebuilding
  /// the whole app.
  final ValueNotifier<String> windowSection = ValueNotifier('capture');

  /// Utility tool opened inside the window shell's Tools section
  /// (null = the grid). Mirrors the flyout's panel switching.
  final ValueNotifier<String?> windowTool = ValueNotifier(null);

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
  late final Spring flyHs = Spring(0, 380, 30); // card height spring (audit 6)
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

  final _holdsTracker = PanelHoldsTracker();
  void focusGained() => _holdsTracker.focusGained();
  void focusLost() => _holdsTracker.focusLost();
  bool get typing => _holdsTracker.typing;
  bool get interacting => _holdsTracker.interacting;
  bool get modalOpen => _holdsTracker.modal;
  bool get keepOpen => S.panelPinned || interacting || typing;

  /// An owned lease keeps readers, recorders and OS dialogs visible. Releasing
  /// one lease cannot accidentally unlock another overlapping interaction.
  @override
  VoidCallback holdOpen({bool modal = true}) =>
      _holdsTracker.acquireHold(cancelClose, () {}, modal: modal);

  void togglePanelPin() {
    S.panelPinned = !S.panelPinned;
    cancelClose();
    save();
    refresh();
  }

  /// Public notify for views (ChangeNotifier.notifyListeners is protected).
  void refresh() => notifyListeners();

  (String, String, String)? _themeKey;
  ThemeData? _cachedTheme;
  LiquidPalette? _cachedPalette;

  LiquidPalette get palette {
    final theme = appTheme;
    return _cachedPalette ??= paletteFromTheme(theme);
  }

  ThemeData get appTheme {
    final key = (S.theme, S.preset, S.language);
    if (_themeKey == key && _cachedTheme != null) return _cachedTheme!;
    final theme = _buildAppTheme();
    _themeKey = key;
    _cachedPalette = null;
    return _cachedTheme = theme;
  }

  ThemeData _buildAppTheme() {
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
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: .16)),
    );
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
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
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size(0, 36),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          maximumSize: const Size(48, 48),
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
      if (outT?.isActive == true) return true;
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
    // The edge reveal only belongs to the panel mode.
    if (isWindowMode || windowModeChanging) {
      _near = false;
      return;
    }
    pollPanelPointer();
    if (isOpen) {
      _near = false;
      return;
    }
    if (picking) {
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
    clipboard.dispose();
    for (final timer in _delayed) {
      timer.cancel();
    }
    _delayed.clear();
    if (native is WinNativeHost) (native as WinNativeHost).dispose();
    disposeTimers();
    toolScroll.dispose();
    dragInfo.dispose();
    dropHintOn.dispose();
    windowSection.dispose();
    windowTool.dispose();
    _edgeT?.cancel();
    _toastT?.cancel();
    outT?.cancel();
    frame.dispose();
    toastMsg.dispose();
    super.dispose();
  }
}

class PanelController = PanelStateBase
    with
        PanelLifecycle,
        PanelTimers,
        PanelWiring,
        PanelDismissal,
        PanelWindowTransitions,
        PanelActions,
        PanelClipboardOps;

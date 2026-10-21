// Part of the PanelController split (see controller.dart). Members
// below are spliced into the class body; do not import this file directly.
part of 'controller.dart';

/// Boot, settings persistence, the original `app` object and placement.

/// Boot, settings persistence, the original `app` object and placement.
mixin PanelLifecycle on PanelStateBase {
  // ================= lifecycle =================
  /// [preset] and [useNative] exist so tests can boot without touching
  /// the filesystem or the platform channel.
  @override
  Future<void> bootstrap({
    Settings? preset,
    bool useNative = true,
    String? installerLanguageMarker,
    bool showWindow = true,
    bool forcePanelMode = false,
  }) async {
    _persistSettings = preset == null;
    try {
      S = preset ?? Settings.fromMap(storage.loadSettings());
    } catch (_) {
      // Damaged shell preferences must not make the user's library unusable.
      S = Settings();
    }
    _wireNative();
    // The native smoke probe exercises edge-panel placement/reveal; it must
    // run in the panel mode regardless of the saved preference.
    if (forcePanelMode) S.windowMode = 'panel';
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

    ToolInfo.controllerApps = S.apps;
    if (preset == null) {
      await clipboard.initialize(storage.dir, _restorePinnedClips());
      S.pins = clipboard.pinnedTexts;
      if (clipboard.recent.isNotEmpty) {
        lastClip = clipboard.recent.first.text ?? '';
      }
    }

    if (useNative) {
      try {
        screens = await native.screens();
        S.monitor = displayIndex(screens, S.monitorName, S.monitor);
      } catch (_) {}
      if (isWindowMode) {
        // Main mode: a full desktop window, restoring the saved frame.
        try {
          await native.setWindowMode(
            'window',
            bounds: S.windowRemember ? S.windowBounds : null,
            maximized: S.windowRemember && S.windowMaximized,
            compact: !S.windowRemember,
            show: showWindow,
          );
        } catch (_) {}
      } else {
        try {
          final p = await native.applyPlacement(S.edge, S.monitor);
          if (p != null) placement = Placement.fromMap(p);
        } catch (_) {}
      }
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

  /// Rebuilds the pinned clipboard entries at boot: images come from the
  /// pins directory, pinned text from the persisted pins list. Without this
  /// pinned text appeared with a fake timestamp and pinned images only
  /// reappeared after a restart.
  List<ClipEntry> _restorePinnedClips() {
    final out = storage.loadPinnedImages();
    for (final text in S.pins) {
      out.add(ClipEntry.text(text, time: DateTime.now(), pinned: true));
    }
    return out;
  }

  @override
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

  @override
  void save() {
    ToolInfo.controllerApps = S.apps;
    if (_persistSettings) storage.saveSettings(S.toMap());
  }

  // ================= the `app` object =================
  @override
  void open() {
    cancelClose();
    if (!isWindowMode) {
      unawaited(native.setPassthrough(false).catchError((_) {}));
    }
    if (isOpen) return;
    isOpen = true;
    openedAt = clockSec;
    notifyListeners();
  }

  @override
  void close() {
    if (!isOpen) return;
    isOpen = false;
    sticky = false;
    closedAt = clockSec;
    setPanel(null);
    mx = -1;
    hoverY = null;
    notifyListeners();
    // The desktop window stays visible when it loses focus; only the edge
    // panel hides itself away after the spring exit.
    if (isWindowMode) return;
    // Let the original spring exit finish before hiding the native host.
    _later(const Duration(milliseconds: 450), () {
      if (!isOpen) unawaited(native.setPassthrough(true).catchError((_) {}));
    });
  }

  @override
  void cursor(double dist) => mx = dist;

  @override
  void show(String name) {
    if (isWindowMode) {
      // The window is the primary surface: reveal it and route inside.
      unawaited(native.focusWindow().catchError((_) {}));
      if (name == 'settings') selectWindowSection('settings');
      return;
    }
    sticky = true;
    open();
    if (name.isNotEmpty) {
      _later(const Duration(milliseconds: 140), () {
        if (isOpen) openWidget(name);
      });
    }
  }

  /// Focuses the desktop window and shows [section].
  @override
  void selectWindowSection(String section) {
    windowTool.value = null;
    windowSection.value = section;
    notifyListeners();
  }

  /// Opens a utility tool inside the window shell's Tools section.
  @override
  void openWindowTool(String id) {
    windowSection.value = 'tools';
    windowTool.value = id;
    notifyListeners();
  }

  /// Returns from an open tool view to the tools surface: the window shell's
  /// directory or the flyout's More grid, depending on the active mode.
  @override
  void backToTools() {
    if (isWindowMode) {
      windowTool.value = null;
      notifyListeners();
      return;
    }
    anchorY = fy.v;
    setPanel('more', fromMore: true);
  }

  @override
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

  @override
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

  @override
  void blur() {
    // A desktop window must survive losing focus; only the edge panel
    // auto-hides (the original's WindowEvent::Focused(false) behaviour).
    dismissPanel();
  }

  @override
  void setPickerActive(bool active) {
    picking = active;
    cancelClose();
    if (!active && isOpen) sticky = true;
  }

  @override
  void clip(String text) => addClip(text);

  @override
  void addClip(String text) {
    if (text.trim().isEmpty) return;
    lastClip = text;
    clipboard.add(ClipEntry.text(text, time: DateTime.now()));
  }

  @override
  void addClipImage(ClipImage img) {
    lastClip = '';
    clipboard.add(ClipEntry.image(img, time: DateTime.now()));
  }

  @override
  void onPickedColor(String? hex) {
    picking = false;
    if (hex == null) return;
    // setColor + pushRecentColor + copy + open the color panel
    unawaited(Clipboard.setData(ClipboardData(text: hex)));
    pickedColorHex = hex;
    pushRecentColor(_parseHex(hex));
    if (isWindowMode) {
      // The window's tools card showing the color view refreshes in place.
      notifyListeners();
    } else {
      open();
      openWidget('color');
      notifyListeners();
    }
    toast(message('Picked {value}', {'value': hex}));
  }

  String pickedColorHex = '#3b82f6';
  Future<void> pickCustomColorFor(String target) async {
    await native.pickCustomColor(pickedColorHex).catchError((_) {});
  }

  @override
  void onPickedCustomColor(String? hex) {
    if (hex == null) return;
    pickedColorHex = hex;
    notifyListeners();
  }

  /// Moves the panel to the chosen edge / monitor (placement message).
  /// In window mode the choice is only remembered; it applies when the user
  /// returns to the panel mode.
  Future<void> applyPlacement(String edge, int monitor) async {
    S.edge = edge;
    S.monitor = monitor;
    if (monitor >= 0 && monitor < screens.length) {
      S.monitorName = screens[monitor]['name'] as String?;
    }
    save();
    if (isWindowMode) {
      notifyListeners();
      return;
    }
    try {
      final p = await native.applyPlacement(edge, monitor);
      if (p != null) placement = Placement.fromMap(p);
    } catch (_) {}
    notifyListeners();
    toast(
      message('Panel moved to the {value}', {
        'value': utilityForLocale(
          resolvedLanguage,
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

  @override
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

  @override
  void onTray(String id) {
    if (isWindowMode) {
      // The desktop window is always the primary surface.
      switch (id) {
        case 'capture':
          unawaited(native.focusWindow().catchError((_) {}));
          selectWindowSection('capture');
          onCapture?.call();
          break;
        case 'shutdown':
          unawaited(_closeWindow());
          break;
        case 'open':
        case 'settings':
          show(id == 'settings' ? 'settings' : '');
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
          unawaited(quit());
          break;
      }
      return;
    }
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

  bool _closingWindow = false;
  Future<void> _closeWindow() async {
    if (_closingWindow || _quitQueued) return;
    _closingWindow = true;
    try {
      if (S.closeToTray) {
        await _rememberWindowFrame();
        save();
        if (await native.hideToTray()) return;
      }
      await quit();
    } finally {
      _closingWindow = false;
    }
  }

  @override
  Future<void> quit() async {
    if (_quitQueued) return;
    _quitQueued = true;
    // Persist the desktop window's position/size before anything drains.
    if (isWindowMode) await _rememberWindowFrame();
    if (isWindowMode) save();
    try {
      await clipboard.flushed;
      if (clipboard.error != null) await clipboard.retry();
      if (clipboard.error != null) throw StateError('Clipboard not persisted');
      await beforeShutdown?.call();
      await clipboard.close();
    } catch (_) {
      _quitQueued = false;
      return;
    }
    await native.quit().catchError((_) {});
  }
}

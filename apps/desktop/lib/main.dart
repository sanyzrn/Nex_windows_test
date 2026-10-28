import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nex_core/nex_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'nex/features.dart';
import 'nex/welcome.dart';
import 'nex/store.dart';
import 'nex/media_smoke.dart';
import 'nex/modules/module_probe.dart';
import 'nex/panel_smoke.dart';
import 'nex/lifecycle_smoke.dart';
import 'nex/reminder_smoke.dart';
import 'nex/reminder_coordinator.dart';
import 'nex/note_activation.dart';
import 'nex/reminder_activation.dart';
import 'l10n/app_localizations.dart';
import 'core/app_meta.dart';
import 'updates/controller.dart';
import 'updates/handoff.dart';

import 'core/controller.dart';
import 'core/native.dart';
import 'core/clipboard_smoke.dart';
import 'ui/shell.dart';
import 'ui/desktop_theme.dart';
import 'ui/window_shell.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (arguments.length == 4 && arguments.first == '--clipboard-smoke') {
    await clipboardSmoke(arguments);
    return;
  }
  if (arguments.length == 4 && arguments.first == '--media-smoke') {
    await mediaSmoke(arguments);
    return;
  }
  if (arguments.length == 2 && arguments.first == '--panel-smoke') {
    await panelSmoke(arguments[1]);
    return;
  }
  if (arguments.length == 2 && arguments.first == '--reminder-smoke') {
    await reminderSmoke(arguments[1]);
    return;
  }
  if (arguments.length == 2 && arguments.first == '--lifecycle-smoke') {
    await lifecycleSmoke(arguments[1]);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final device = prefs.getString('deviceId') ?? newUuidV7();
  await prefs.setString('deviceId', device);
  final smokeMode =
      arguments.length == 2 && arguments.first == '--native-smoke';
  final support = smokeMode
      ? await Directory.systemTemp.createTemp('nex-native-smoke-')
      : await getApplicationSupportDirectory();
  final features = NexFeatures(await DesktopStore.open(support.path, device));
  final controller = PanelController(nativeHost: WinNativeHost());
  // Local opt-in diagnostics contain geometry/state, never note content.
  if (File(
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}diagnostics.flag',
  ).existsSync()) {
    final diagnosticsDir = controller.storage.dir;
    FlutterError.onError = (details) {
      File(
        '${diagnosticsDir.path}/desktop-error.log',
      ).writeAsStringSync('${details.exceptionAsString()}\n${details.stack}');
      FlutterError.presentError(details);
    };
    Timer.periodic(const Duration(seconds: 1), (_) {
      File('${diagnosticsDir.path}/ui-state.json').writeAsStringSync(
        jsonEncode({
          'open': controller.isOpen,
          'panel': controller.panel,
          'frames': controller.frame.value,
          'clock': controller.clockSec,
          'slide': controller.slide.v,
          'grow': controller.grow.v,
          'flyHeight': controller.flyH,
          'sticky': controller.sticky,
        }),
      );
    });
  }
  String? installerLanguage;
  if (!smokeMode) {
    try {
      installerLanguage = await File(
        '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}install-language.txt',
      ).readAsString();
    } on FileSystemException {
      // Source runs have no installer marker and use normal saved preferences.
    }
  }
  final actionLaunch =
      arguments.length == 2 &&
      arguments.first == '--open-note' &&
      ReminderActivation.parse(arguments[1]) != null;
  await controller.bootstrap(
    installerLanguageMarker: installerLanguage,
    showWindow: !arguments.contains('--background') && !actionLaunch,
    forcePanelMode: smokeMode,
  );
  controller.importFiles = (paths) {
    features.importPaths(paths);
  };
  controller.onCapture = () {
    features.fresh();
  };
  controller.onOpenNote = (uri) =>
      unawaited(features.guard(() => activateNote(uri, controller, features)));
  controller.beforeShutdown = features.close;
  if (smokeMode) {
    final native = controller.native as WinNativeHost;
    final startup = await native.startupEnabled();
    final result = await native.diagnostics();
    var moduleStage = 'start';
    try {
      result['modules'] = await probeDesktopModules(
        support.path,
        onStage: (stage) {
          moduleStage = stage;
          File(
            '${arguments[1]}.progress.json',
          ).writeAsStringSync(jsonEncode({'stage': stage}));
        },
      );
    } catch (error) {
      // Explicit synthetic probe only: retain failures instead of an opaque
      // external timeout. Never serialize vault values or user authentication.
      File('${arguments[1]}.failure.json').writeAsStringSync(
        jsonEncode({'stage': moduleStage, 'error': error.toString()}),
      );
      rethrow;
    }
    var captures = 0;
    controller.onCapture = () {
      captures++;
    };
    await native.probeHotkey();
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (captures == 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    result['hotkeyDelivered'] = captures > 0;
    result['captureOpened'] = controller.isOpen && controller.panel == 'note';
    try {
      await native.setStartup(!startup);
      result['startupToggle'] = await native.startupEnabled() == !startup;
      final saved = controller.placement;
      final savedEdge = controller.S.edge, savedMonitor = controller.S.monitor;
      final monitors = await native.screens();
      final positions = <Map<String, dynamic>>[];
      final originalCursor = native.cursorPos();
      try {
        for (var i = 0; i < monitors.length; i++) {
          for (final edge in ['left', 'right']) {
            final placement = await native.applyPlacement(edge, i);
            if (placement != null) {
              controller.placement = Placement.fromMap(placement);
              controller.close();
              final actual = controller.placement!;
              await native.probeCursor(
                actual.x + actual.w ~/ 2,
                actual.y + actual.h ~/ 2,
              );
              await Future<void>.delayed(const Duration(milliseconds: 40));
              await native.probeCursor(
                actual.onLeft ? actual.edgeX : actual.edgeX - 1,
                actual.y + actual.h ~/ 2,
              );
              final until = DateTime.now().add(
                const Duration(milliseconds: 800),
              );
              while (!controller.isOpen && DateTime.now().isBefore(until)) {
                await Future<void>.delayed(const Duration(milliseconds: 20));
              }
              positions.add({
                'monitor': i,
                'edge': edge,
                ...placement,
                'edgeReveal': controller.isOpen,
              });
            }
          }
        }
      } finally {
        await native.applyPlacement(savedEdge, savedMonitor);
        controller.placement = saved;
        controller.S.edge = savedEdge;
        controller.S.monitor = savedMonitor;
        if (originalCursor != null) {
          await native.probeCursor(originalCursor.$1, originalCursor.$2);
        }
      }
      result['placements'] = positions;
      final previous = controller.placement;
      await native.probeDisplayChange();
      final until = DateTime.now().add(const Duration(seconds: 1));
      while (identical(controller.placement, previous) &&
          DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      result['displayChangeRefresh'] = !identical(
        controller.placement,
        previous,
      );
    } finally {
      await native.setStartup(startup);
    }
    result['startupRestored'] = await native.startupEnabled() == startup;
    await File(arguments[1]).writeAsString(jsonEncode(result));
    // Gives the external harness a bounded window to verify the named mutex.
    await Future<void>.delayed(const Duration(seconds: 2));
    await features.close();
    controller.beforeShutdown = null;
    await support.delete(recursive: true);
    await controller.quit();
    return;
  }
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'PDFium',
    ], await rootBundle.loadString('assets/notices/pdfium.txt'));
    yield LicenseEntryWithLineBreaks([
      'Right Panel',
    ], await rootBundle.loadString('assets/notices/right-panel.txt'));
    yield LicenseEntryWithLineBreaks([
      'Nex',
    ], await rootBundle.loadString('assets/notices/nex.txt'));
    yield LicenseEntryWithLineBreaks([
      'Inter',
    ], await rootBundle.loadString('assets/notices/inter-OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Vazirmatn',
    ], await rootBundle.loadString('assets/notices/vazirmatn-OFL.txt'));
  });
  final reminders = ReminderCoordinator(
    features.store,
    NativeReminderScheduler(controller.native),
    onDeliveredChanged: features.setDeliveredReminders,
    onFailureChanged: (failed) {
      if (features.reminderDeliveryFailed != failed) {
        features.reminderDeliveryFailed = failed;
        features.notify();
      }
    },
  );
  features.synchronizeReminders = () async {
    final result = await reminders.refresh();
    if (result.failedCount > 0) throw ReminderDeliveryFailure();
  };
  controller.beforeShutdown = () async {
    await reminders.close();
    await features.close();
  };
  final labels = await AppLocalizations.delegate.load(
    Locale(controller.resolvedLanguage),
  );
  await controller.native.setLabels({
    'snooze': labels.reminderSnooze,
    'done': labels.reminderDone,
  });
  if (actionLaunch) {
    await reminders.start();
    try {
      await activateNote(arguments[1], controller, features);
    } finally {
      await controller.quit();
    }
    return;
  }
  unawaited(reminders.start());
  if (Platform.isWindows) {
    final updates = features.updates = DesktopUpdates(
      currentVersion: kAppShortVersion,
      cache: Directory(
        '${(await getTemporaryDirectory()).path}/nex-windows-updates',
      ),
      install: (file, digest) => installWindowsUpdate(file, digest, controller),
    );
    unawaited(updates.initialize());
    // Give capture and the first frame priority. No updater runs in probes.
    unawaited(Future<void>.delayed(const Duration(seconds: 12), updates.start));
  }
  runApp(
    RightPanelApp(
      controller: controller,
      features: features,
      showWelcome: !smokeMode && !arguments.contains('--background'),
    ),
  );
  // A manual launch must immediately present a usable, focused capture
  // surface. Startup launches opt into the unobtrusive background mode;
  // the edge panel stays hidden and the window waits in the tray.
  if (arguments.length == 2 && arguments.first == '--open-note') {
    unawaited(activateNote(arguments[1], controller, features));
  } else if (!arguments.contains('--background')) {
    controller.onTray('capture');
  }
}

class RightPanelApp extends StatelessWidget {
  const RightPanelApp({
    super.key,
    required this.controller,
    this.features,
    this.showWelcome = false,
  });
  final bool showWelcome;

  final PanelController controller;
  final NexFeatures? features;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'Nex',
        debugShowCheckedModeBanner: false,
        navigatorObservers: [controller.routeObserver],
        locale: Locale(controller.resolvedLanguage),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: nexDesktopTheme(controller.appTheme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: _SharedTextScaler(
              MediaQuery.textScalerOf(context),
              // The desktop window sets its type a notch smaller than the
              // edge panel and the phone: a pointer needs no touch-sized
              // text, and a wide page reads calmer in small type.
              controller.S.uiScale *
                  (controller.isWindowMode ? kWindowTypeDensity : 1),
            ),
          ),
          child: NexPanelScope(
            controller: controller,
            child: NativeLocaleLabels(
              controller: controller,
              child: features == null
                  ? child!
                  : NexScope(features: features!, child: child!),
            ),
          ),
        ),
        home: NexPanelScope(
          controller: controller,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final shell = controller.isWindowMode
                  ? NexWindowShell(controller: controller, features: features)
                  : PanelShell(controller: controller);
              return showWelcome
                  ? DesktopWelcome(controller: controller, child: shell)
                  : shell;
            },
          ),
        ),
      ),
    );
  }
}

class NativeLocaleLabels extends StatefulWidget {
  const NativeLocaleLabels({
    super.key,
    required this.controller,
    required this.child,
  });
  final PanelController controller;
  final Widget child;
  @override
  State<NativeLocaleLabels> createState() => _NativeLocaleLabelsState();
}

class _NativeLocaleLabelsState extends State<NativeLocaleLabels>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => widget.controller.refresh();

  @override
  void didChangeLocales(List<Locale>? locales) => widget.controller.refresh();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context)!;
    widget.controller.native.setLabels({
      'open': l.trayOpen,
      'newNote': l.newNote,
      'snooze': l.reminderSnooze,
      'done': l.reminderDone,
      'settings': l.settings,
      'addApp': l.addApp,
      'startup': l.startup,
      'quit': l.trayQuit,
      'addFolder': l.addFolder,
      'apps': l.appsAndShortcuts,
      'files': l.allFiles,
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SharedTextScaler extends TextScaler {
  const _SharedTextScaler(this.system, this.multiplier);
  final TextScaler system;
  final double multiplier;
  @override
  double scale(double fontSize) => system.scale(fontSize) * multiplier;
  @override
  double get textScaleFactor => scale(14) / 14;
}

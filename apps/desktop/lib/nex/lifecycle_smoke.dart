import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/native.dart';
import '../main.dart' show RightPanelApp;
import 'features_state.dart';
import 'store.dart';

/// Deliberately uses the legacy false flag to verify migration-independent close.
/// The PowerShell harness sends real WM_CLOSE/tray commands and checks HWNDs.
Future<void> lifecycleSmoke(String output) async {
  final root = await Directory.systemTemp.createTemp('nex-lifecycle-');
  final native = WinNativeHost();
  final features = NexFeatures(
    await DesktopStore.open(root.path, 'lifecycle-probe'),
  );
  final c = PanelController(nativeHost: native);
  await c.bootstrap(
    preset: Settings()
      ..language = 'en'
      ..closeToTray = false,
    useNative: false,
  );
  await native.setWindowMode('window', compact: true);
  c.beforeShutdown = () async {
    await features.close();
    await File(output).writeAsString(jsonEncode({'drained': true}));
    await root.delete(recursive: true);
  };
  runApp(RightPanelApp(controller: c, features: features));
}

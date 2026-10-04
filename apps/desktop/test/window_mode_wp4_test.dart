// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_desktop/l10n/app_localizations.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/library_view.dart';
import 'package:nex_desktop/nex/shortcuts_dialog.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:nex_desktop/nex/note_detail_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('library renders single pane below 900px width', (tester) async {
    late Directory root;
    late NexFeatures features;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('nex-wp4-1pane-');
      final store = await DesktopStore.open(root.path, 'dev-1');
      features = NexFeatures(store);
      features.write('First test note');
      await Future.delayed(const Duration(milliseconds: 200));
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: NexScope(
            features: features,
            child: const Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: NexLibraryView(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TextField), findsOneWidget); // Search field
    expect(find.byType(NexNoteDetail), findsNothing);

    await tester.runAsync(() async {
      await features.store.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  testWidgets('library renders two panes at width >= 900px', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late Directory root;
    late NexFeatures features;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('nex-wp4-2pane-');
      final store = await DesktopStore.open(root.path, 'dev-2');
      features = NexFeatures(store);
      features.write('Two-pane note test');
      await Future.delayed(const Duration(milliseconds: 200));
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 700)),
          child: NexScope(
            features: features,
            child: const Scaffold(
              body: SizedBox(
                width: 1200,
                height: 700,
                child: NexLibraryView(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 100));

    // Two-pane: list on one side, empty placeholder or reader on other side
    expect(find.byIcon(Icons.article_outlined), findsOneWidget); // Empty state placeholder
    expect(find.text('No note selected'), findsOneWidget);

    await tester.runAsync(() async {
      await features.store.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  testWidgets('shortcuts dialog displays desktop keyboard shortcuts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showShortcutsDialog(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Ctrl + N'), findsOneWidget);
    expect(find.text('Ctrl + Shift + N'), findsOneWidget);
    expect(find.text('Ctrl + F'), findsOneWidget);
    expect(find.text('Ctrl + L'), findsOneWidget);
    expect(find.text('Ctrl + ,'), findsOneWidget);
    expect(find.text('Delete'), findsNWidgets(2)); // Key combo and action label
  });
}

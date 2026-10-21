import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_desktop/core/controller.dart';
import 'package:nex_desktop/core/native.dart';
import 'package:nex_desktop/main.dart';
import 'package:nex_desktop/nex/features_state.dart';
import 'package:nex_desktop/nex/intelligence/controller.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Native extends NativeHost {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _Secrets implements AiSecrets {
  @override
  Future<String?> read(String key) async =>
      key == 'ai.key.openai' ? 'test-key' : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Future<void> _wait(WidgetTester t, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets(
    'assistant settings keep scope and actions require the Apply button',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'ai.enabled': true,
        'ai.cloud_opt_in': true,
        'ai.provider': 'openai',
      });
      t.view.physicalSize = const Size(1200, 950);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final root = (await t.runAsync(
        () => Directory.systemTemp.createTemp('nex-ai-ui-'),
      ))!;
      final store = (await t.runAsync(
        () => DesktopStore.open(root.path, 'test'),
      ))!;
      final features = (await t.runAsync(
        () async => NexFeatures(
          store,
          intelligenceFactory: (store) => DesktopIntelligence(
            store,
            secrets: _Secrets(),
            clientFactory: () => MockClient(
              (request) async => request.method == 'GET'
                  ? http.Response(
                      jsonEncode({
                        'data': [
                          {'id': 'gpt-test-alpha'},
                          {'id': 'gpt-test-beta'},
                        ],
                      }),
                      200,
                    )
                  : http.Response(
                      jsonEncode({
                        'choices': [
                          {
                            'message': {
                              'content':
                                  'A proposed note.\n```nex\n{"action":"create","text":"A confirmed idea"}\n```',
                            },
                            'finish_reason': 'stop',
                          },
                        ],
                      }),
                      200,
                    ),
            ),
          ),
        ),
      ))!;
      final panel = PanelController(nativeHost: _Native());
      await panel.bootstrap(
        preset: Settings()
          ..windowMode = 'window'
          ..language = 'en',
        useNative: false,
      );
      panel.selectWindowSection('assistant');
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        panel.dispose();
        await t.runAsync(() async {
          await features.close();
          await root.delete(recursive: true);
        });
      });
      await t.pumpWidget(RightPanelApp(controller: panel, features: features));
      await _wait(t, find.byKey(const ValueKey('assistant-input')));
      await t.tap(find.byTooltip('AI settings'));
      await t.pumpAndSettle();
      expect(find.text('AI settings'), findsWidgets);
      expect(t.takeException(), isNull);
      final providerLink = find.byKey(const ValueKey('ai-provider-open'));
      await t.ensureVisible(providerLink);
      await t.tap(providerLink);
      await t.pumpAndSettle();
      final picker = find.byKey(const ValueKey('ai-model-picker'));
      await t.ensureVisible(picker);
      await t.tap(picker);
      await _wait(t, find.text('gpt-test-beta'));
      await t.enterText(find.byKey(const ValueKey('ai-model-search')), 'beta');
      await t.pump();
      expect(find.text('gpt-test-alpha'), findsNothing);
      await t.tap(find.text('gpt-test-beta'));
      await t.pumpAndSettle();
      expect(find.text('gpt-test-beta'), findsOneWidget);
      // Picking an ID edits the candidate; it never activates an untested model.
      expect(features.intelligence.config.model, isEmpty);
      await t.tap(find.byIcon(Icons.close).last);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('assistant-input')),
        'Create an idea',
      );
      await t.pump();
      await t.tap(find.byTooltip('Send'));
      await _wait(t, find.text('Apply these changes'));
      expect(
        await t.runAsync(() => store.call<List<Note>>('timeline')),
        isEmpty,
      );
      await t.tap(find.text('Apply these changes'));
      await _wait(t, find.text('Changes applied'));
      final notes = (await t.runAsync(
        () => store.call<List<Note>>('timeline'),
      ))!;
      expect(notes.single.content, 'A confirmed idea');
      expect(t.takeException(), isNull);
    },
  );
}

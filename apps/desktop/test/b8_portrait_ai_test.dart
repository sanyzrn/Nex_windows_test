import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nex_core/nex_core.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/nex/intelligence/controller.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets implements AiSecrets {
  @override
  Future<String?> read(String key) async =>
      key.endsWith('.custom') ? 'synthetic-key' : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'portrait uses only live note samples and requires current AI/read consent',
    () async {
      SharedPreferences.setMockInitialValues({
        'ai.enabled': true,
        'ai.cloud_opt_in': true,
        'ai.provider': 'custom',
        'ai.baseUrl.custom': 'https://example.test/v1/chat/completions',
        'ai.model.custom': 'fixture-model',
      });
      final root = await Directory.systemTemp.createTemp('nex-portrait-test-');
      final db = NexDatabase.open('${root.path}/nex.sqlite');
      final notes = SqliteNoteRepository(db);
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 40; i++) {
        final at = now.subtract(Duration(days: i));
        notes.insert(
          Note(
            id: 'note-$i',
            type: NoteType.text,
            content: 'Synthetic writing sample $i',
            createdAt: at,
            updatedAt: at,
            deviceId: 'fixture',
            rev: 1,
            syncState: SyncState.pending,
          ),
        );
      }
      SqliteCycleRepository(db).saveDay(
        CycleDayLog(day: CycleDate.of(now), note: 'PRIVATE-CYCLE-FIXTURE'),
      );
      db.close();
      final store = await DesktopStore.open(root.path, 'portrait-test');
      var requests = 0;
      final ai = DesktopIntelligence(
        store,
        secrets: _Secrets(),
        clientFactory: () => MockClient((request) async {
          requests++;
          expect(request.body, contains('Synthetic writing sample'));
          expect(request.body, isNot(contains('PRIVATE-CYCLE-FIXTURE')));
          final reply = jsonEncode({
            'headline': 'A thoughtful writer',
            'portrait': 'You return to your ideas and make room for them.',
            'traits': [
              for (var i = 0; i < 5; i++)
                {
                  'name': 'Trait $i',
                  'score': 60,
                  'line': 'A repeated pattern.',
                },
            ],
            'strengths': ['Clarity'],
            'invitation': 'Keep a small space for unfinished ideas.',
          });
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': reply},
                  'finish_reason': 'stop',
                },
              ],
            }),
            200,
          );
        }),
      );
      try {
        final portrait = await ai.writePortrait();
        expect(portrait?.basedOn, 40);
        expect(ai.writtenPortrait?.headline, 'A thoughtful writer');
        expect(requests, 1);
        await ai.setValue('ai.readNotes', false);
        expect(await ai.writePortrait(), isNull);
        expect(requests, 1);
        expect(ai.writtenPortrait, isNotNull);
        await ai.removeWrittenPortrait();
        expect(ai.writtenPortrait, isNull);
      } finally {
        await ai.close();
        await store.close();
        await root.delete(recursive: true);
      }
    },
  );
}

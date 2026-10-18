import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nex_ai/cloud.dart';
import 'package:nex_data/nex_data.dart';
import 'package:nex_desktop/nex/intelligence/controller.dart';
import 'package:nex_desktop/nex/intelligence/worker.dart';
import 'package:nex_desktop/nex/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets implements AiSecrets {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Credential store failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _DelayedTimeline implements DesktopStore {
  _DelayedTimeline(this.delegate);
  final DesktopStore delegate;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  String get mediaDir => delegate.mediaDir;
  @override
  Future<T> call<T>(
    String command, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (command == 'timeline') {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return delegate.call<T>(command, args);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

http.Response _answer(String text) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': text},
        'finish_reason': 'stop',
      },
    ],
  }),
  200,
);
Note _note(String id, String text) => Note(
  id: id,
  type: NoteType.text,
  content: text,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  deviceId: 'test',
  rev: 1,
  syncState: SyncState.pending,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DesktopStore store;
  late DesktopIntelligence ai;
  late _Secrets secrets;
  var reply = 'ok';
  final seen = <http.Request>[];
  const config = AiProviderConfig(
    provider: AiProvider.openai,
    apiKey: 'test-secret',
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('nex-ai-test-');
    store = await DesktopStore.open(root.path, 'test');
    secrets = _Secrets();
    seen.clear();
    reply = 'ok';
    ai = DesktopIntelligence(
      store,
      secrets: secrets,
      clientFactory: () => MockClient((r) async {
        seen.add(r);
        return _answer(reply);
      }),
    );
    await ai.initialize();
  });
  tearDown(() async {
    await ai.close();
    await store.close();
    await root.delete(recursive: true);
  });
  Future<void> enable() async {
    await ai.setValue('ai.cloud_opt_in', true);
    expect((await ai.verify(config)).success, isTrue);
    await ai.saveProvider(config);
    await ai.setValue('ai.enabled', true);
    seen.clear();
  }

  test(
    'master and consent default off; no request escapes before opt in',
    () async {
      expect(ai.enabled, isFalse);
      await expectLater(ai.send('hello'), throwsStateError);
      await expectLater(ai.verify(config), throwsStateError);
      expect(seen, isEmpty);
    },
  );
  test('activation requires a test of this exact model and key', () async {
    await ai.setValue('ai.cloud_opt_in', true);
    await expectLater(ai.saveProvider(config), throwsStateError);
    await ai.verify(config);
    await expectLater(
      ai.saveProvider(
        const AiProviderConfig(
          provider: AiProvider.openai,
          apiKey: 'other-key',
        ),
      ),
      throwsStateError,
    );
    await ai.saveProvider(config);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().map(prefs.get).join(),
      isNot(contains('test-secret')),
    );
    expect(secrets.values['ai.key.openai'], 'test-secret');
  });
  test('failed secure write never activates the new provider', () async {
    await ai.setValue('ai.cloud_opt_in', true);
    await ai.verify(config);
    secrets.fail = true;
    await expectLater(ai.saveProvider(config), throwsStateError);
    expect(ai.config.provider, AiProvider.none);
    secrets.fail = false;
    await ai.saveProvider(const AiProviderConfig());
    expect(ai.config.provider, AiProvider.none);
  });
  test('each provider retains its own nonsecret configuration', () async {
    await enable();
    const router = AiProviderConfig(
      provider: AiProvider.openrouter,
      apiKey: 'router-key',
      model: 'vendor/model',
    );
    await ai.verify(router);
    await ai.saveProvider(router);
    expect(ai.config.provider, AiProvider.openrouter);
    expect(ai.configFor(AiProvider.openai).apiKey, 'test-secret');
    expect(ai.config.model, 'vendor/model');
  });
  test(
    'read permission keeps private note content out of chat requests',
    () async {
      await store.call<Note>('capture', {'text': 'UNIQUE_PRIVATE_CONTENT'});
      await enable();
      await ai.setValue('ai.readNotes', false);
      await ai.send('hello');
      expect(seen.single.body, isNot(contains('UNIQUE_PRIVATE_CONTENT')));
      expect(ai.turns.length, 2);
    },
  );
  test('named notes expose their body to chat and writing tools', () async {
    final original = await store.call<Note>('capture', {
      'text': 'SUBSTANTIVE_BODY_CONTENT',
    });
    await store.call<List<String>>('aiActions', {
      'actions': [
        AssistantAction(
          kind: AssistantActionKind.title,
          noteId: original.id,
          text: 'A short title',
        ),
      ],
    });
    final named = (await store.call<Note?>('get', {'id': original.id}))!;
    expect(named.displayText, 'A short title');
    await enable();
    ai.newConversation(note: named);
    await ai.send('Explain the note');
    expect(seen.last.body, contains('SUBSTANTIVE_BODY_CONTENT'));
    await ai.process(named, 'rewrite');
    expect(seen.last.body, contains('SUBSTANTIVE_BODY_CONTENT'));
  });
  test('a proposed write changes nothing until confirmation', () async {
    await enable();
    reply =
        'A new note.\n```nex\n[{"action":"create","text":"Planned note"}]\n```';
    await ai.send('Create a note');
    expect(ai.pending, hasLength(1));
    expect(await store.call<List<Note>>('timeline'), isEmpty);
    await ai.applyPending(applySetting: (_) async {});
    expect(
      (await store.call<List<Note>>('timeline')).single.content,
      'Planned note',
    );
    expect(ai.pending, isEmpty);
  });
  test('revoking write permission discards a pending proposal', () async {
    await enable();
    ai.pending = [
      const AssistantAction(
        kind: AssistantActionKind.create,
        text: 'Do not save',
      ),
    ];
    await ai.setValue('ai.allowActions', false);
    expect(ai.pending, isEmpty);
    await expectLater(
      ai.applyPending(applySetting: (_) async {}),
      throwsStateError,
    );
    expect(await store.call<List<Note>>('timeline'), isEmpty);
  });
  test(
    'an invalid settings value preflights before any database change',
    () async {
      await enable();
      ai.pending = [
        const AssistantAction(
          kind: AssistantActionKind.create,
          text: 'No partial save',
        ),
        const AssistantAction(
          kind: AssistantActionKind.setting,
          settingKey: 'text_size',
          settingValue: 'enormous',
        ),
      ];
      await expectLater(
        ai.applyPending(applySetting: (_) async {}),
        throwsStateError,
      );
      expect(await store.call<List<Note>>('timeline'), isEmpty);
    },
  );
  test('failed generation keeps the previous successful result', () async {
    await enable();
    ai.result = 'Keep this preview';
    reply = '';
    await expectLater(
      ai.process(_note('n', 'Hello'), 'rewrite'),
      throwsStateError,
    );
    expect(ai.result, 'Keep this preview');
  });
  test(
    'automatic brief is cached and manual refresh remains unrestricted',
    () async {
      await store.call<Note>('capture', {'text': 'Make tea'});
      await enable();
      reply = 'A clear plan';
      await ai.refreshBrief();
      expect(ai.brief, 'A clear plan');
      final count = seen.length;
      await ai.refreshBrief();
      expect(seen.length, count);
      await store.call<Note>('capture', {'text': 'Make coffee'});
      await ai.refreshBrief();
      expect(seen.length, count);
      reply = 'A newer plan';
      await ai.refreshBrief(manual: true);
      expect(ai.brief, 'A newer plan');
      expect(seen.length, count + 1);
    },
  );
  test('manual brief refreshes coalesce while notes are loading', () async {
    await store.call<Note>('capture', {'text': 'A real plan'});
    await enable();
    await ai.close();
    final delayed = _DelayedTimeline(store);
    ai = DesktopIntelligence(
      delayed,
      secrets: secrets,
      clientFactory: () => MockClient((r) async {
        seen.add(r);
        return _answer('Plan');
      }),
    );
    await ai.initialize();
    final first = ai.refreshBrief(manual: true);
    await delayed.entered.future;
    final second = ai.refreshBrief(manual: true);
    delayed.release.complete();
    await Future.wait([first, second]);
    expect(seen, hasLength(1));
  });
  test(
    'revoked consent prevents a brief from sending after its database read',
    () async {
      await store.call<Note>('capture', {'text': 'PRIVATE_CONTEXT'});
      await enable();
      await ai.close();
      final delayed = _DelayedTimeline(store);
      ai = DesktopIntelligence(
        delayed,
        secrets: secrets,
        clientFactory: () => MockClient((r) async {
          seen.add(r);
          return _answer('No');
        }),
      );
      await ai.initialize();
      final task = ai.refreshBrief(manual: true);
      await delayed.entered.future;
      await ai.setValue('ai.cloud_opt_in', false);
      delayed.release.complete();
      await task;
      expect(seen, isEmpty);
      expect(ai.brief, isEmpty);
    },
  );
  test(
    'cancelled voice input never starts an upload after reading the file',
    () async {
      await enable();
      final file = File('${root.path}/question.wav');
      await file.writeAsBytes([1, 2, 3]);
      final task = ai.transcribeQuestion(file.path);
      while (!ai.busy) {
        await Future<void>.delayed(Duration.zero);
      }
      ai.cancel();
      await expectLater(task, throwsStateError);
      expect(seen, isEmpty);
    },
  );
  test('semantic spaces never mix after switching embedding models', () async {
    final n = await store.call<Note>('capture', {'text': 'Meaning'});
    await store.call<void>('aiEmbedding', {
      'id': n.id,
      'space': 'old-model',
      'values': [1.0, 0.0],
    });
    expect(
      await store.call<List<Note>>('aiNearest', {
        'space': 'new-model',
        'values': [1.0, 0.0],
      }),
      isEmpty,
    );
  });
  test('private cycle lookup uses the shared start_day schema', () async {
    final text = await store.call<String>('aiCycleContext');
    expect(jsonDecode(text), {'periods': []});
  });
  test(
    'cancelled in-flight reply cannot reappear in another conversation',
    () async {
      await enable();
      await ai.close();
      final completion = Completer<http.Response>();
      ai = DesktopIntelligence(
        store,
        secrets: secrets,
        clientFactory: () => MockClient((_) => completion.future),
      );
      await ai.initialize();
      final task = ai.send('old conversation');
      while (!ai.busy) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      ai.newConversation();
      completion.complete(_answer('stale reply'));
      await task;
      expect(ai.turns, isEmpty);
      expect(ai.busy, isFalse);
    },
  );
  test('worker validates every target before a batch writes', () {
    final db = NexDatabase.openInMemory();
    final repo = SqliteNoteRepository(db);
    repo.insert(_note('valid', 'Original'));
    expect(
      () => executeDesktopAiActions(db, 'test', [
        const AssistantAction(
          kind: AssistantActionKind.edit,
          noteId: 'valid',
          text: 'Changed',
        ),
        const AssistantAction(
          kind: AssistantActionKind.delete,
          noteId: 'missing',
        ),
      ]),
      throwsStateError,
    );
    expect(repo.getById('valid')!.content, 'Original');
    db.close();
  });
  test('worker rolls back earlier writes if a later operation fails', () {
    final db = NexDatabase.openInMemory();
    final repo = SqliteNoteRepository(db);
    repo.insert(_note('valid', 'Original'));
    expect(
      () => executeDesktopAiActions(db, 'test', [
        const AssistantAction(
          kind: AssistantActionKind.edit,
          noteId: 'valid',
          text: 'Changed',
        ),
        const AssistantAction(
          kind: AssistantActionKind.toChecklist,
          noteId: 'valid',
        ),
        const AssistantAction(
          kind: AssistantActionKind.thread,
          threadName: 'test',
          noteIds: ['valid'],
        ),
        const AssistantAction(kind: AssistantActionKind.commitment),
      ]),
      throwsA(anything),
    );
    expect(repo.getById('valid')!.content, 'Original');
    expect(repo.getById('valid')!.type, NoteType.text);
    expect(SqliteThreadRepository(db, repo).list(), isEmpty);
    db.close();
  });
}

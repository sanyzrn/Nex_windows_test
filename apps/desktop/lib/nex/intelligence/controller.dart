import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:nex_ai/cloud.dart';
import 'package:nex_core/nex_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../store.dart';

abstract interface class AiSecrets {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class WindowsAiSecrets implements AiSecrets {
  const WindowsAiSecrets();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: 'nex.windows.$key');
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: 'nex.windows.$key', value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: 'nex.windows.$key');
}

/// Windows presentation of the exact Android cloud adapters and action protocol.
/// Secrets are never placed in preferences, logs, prompts or portable backups.
class DesktopIntelligence extends ChangeNotifier {
  DesktopIntelligence(this.store, {AiSecrets? secrets, this.clientFactory})
    : secrets = secrets ?? const WindowsAiSecrets();
  final DesktopStore store;
  final AiSecrets secrets;
  final http.Client Function()? clientFactory;
  SharedPreferences? _prefs;
  Future<void>? _initializing;
  final _keys = <String, String>{};
  bool ready = false, secureAvailable = true, busy = false;
  bool _closed = false, _applying = false;
  int _generation = 0;
  CloudAIAdapter? _active;
  http.Client? _activeClient;
  String? error, result;
  String brief = '';
  List<ChatMessage> turns = [];
  List<AssistantAction> pending = [];
  List<String> suggestions = [];
  Map<String, dynamic> conversations = {};
  String conversationId = newUuidV7();
  AiProviderConfig? _verified, _detected;
  AiCapabilityCheck? capabilityCheck;
  // Credentials participate only in this in-memory cache. Never persist them.
  final _checks = <String, AiCapabilityCheck>{};

  String _checkIdentity(AiProviderConfig value) =>
      jsonEncode([value.capabilityFingerprint, value.apiKey]);

  AiCapabilityCheck? checkFor(AiProviderConfig candidate) {
    final cached = _checks[_checkIdentity(candidate)];
    if (cached != null) return cached;
    if (candidate.apiKey != _keys[candidate.provider.wireName] ||
        candidate.checkedTime == null) {
      return null;
    }
    try {
      final raw =
          jsonDecode(
                string('ai.capabilityReport.${candidate.provider.wireName}'),
              )
              as Map;
      if (raw['fingerprint'] != candidate.capabilityFingerprint) return null;
      final results = raw['results'] as Map;
      return AiCapabilityCheck(
        at: DateTime.parse(raw['at'] as String),
        results: {
          for (final capability in AiCapability.values)
            if (results[capability.name] case final Map value)
              capability: AiProbeResult(
                AiProbeVerdict.values.byName(value['verdict'] as String),
                status: value['status'] as int?,
                detail: value['detail'] as String?,
              ),
        },
      );
    } catch (_) {
      return null;
    }
  }

  String _capabilityReport(AiProviderConfig candidate) => jsonEncode({
    'fingerprint': candidate.capabilityFingerprint,
    'at': capabilityCheck!.at.toUtc().toIso8601String(),
    'results': {
      for (final entry in capabilityCheck!.results.entries)
        entry.key.name: {
          'verdict': entry.value.verdict.name,
          'status': entry.value.status,
          'detail': entry.value.detail?.replaceAll(
            candidate.apiKey.isEmpty ? '\u0000' : candidate.apiKey,
            '…',
          ),
        },
    },
  });

  Future<List<String>> models(AiProviderConfig candidate) async {
    await initialize();
    if (!flag('ai.cloud_opt_in')) throw StateError('Cloud consent is required');
    if (busy) throw StateError('Another request is running');
    final generation = ++_generation;
    busy = true;
    _notify();
    try {
      final models = await _adapter(candidate).listModels();
      return generation == _generation ? models : const [];
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Note? focusedNote;
  final attachments = <NexChatAttachment>[];

  Future<void> initialize() => _initializing ??= _load();
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    for (final provider in AiProvider.values.where(
      (p) => p != AiProvider.none,
    )) {
      try {
        _keys[provider.wireName] =
            await secrets.read('ai.key.${provider.wireName}') ?? '';
      } catch (_) {
        secureAvailable = false;
      }
    }
    try {
      conversations = Map<String, dynamic>.from(
        jsonDecode(string('ai.windows.conversations', '{}')) as Map,
      );
    } catch (_) {
      conversations = {};
    }
    brief = string('ai.windows.brief');
    NexDisclosureLog.configure(Directory(store.mediaDir).parent.path);
    ready = true;
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  bool flag(String key, [bool fallback = false]) =>
      _prefs?.getBool(key) ?? fallback;
  String string(String key, [String fallback = '']) =>
      _prefs?.getString(key) ?? fallback;
  int number(String key, [int fallback = 20]) =>
      _prefs?.getInt(key) ?? fallback;
  bool get enabled =>
      flag('ai.enabled') && flag('ai.cloud_opt_in') && config.isUsable;
  bool get canRead => flag('ai.readNotes', true);
  bool get canAct => flag('ai.allowActions', true);
  AiProviderConfig configFor(AiProvider provider) => AiProviderConfig.fromMap({
    'provider': provider.wireName,
    'apiKey': _keys[provider.wireName] ?? '',
    for (final key in const AiProviderConfig().toMap().keys)
      if (key != 'provider' && key != 'apiKey')
        key: string('ai.$key.${provider.wireName}'),
  });
  AiProviderConfig get config =>
      configFor(AiProviderWire.fromWire(string('ai.provider')));
  Future<void> setValue(String key, Object value) async {
    await initialize();
    if ((!key.startsWith('ai.') && key != 'cycle.assistant_access') ||
        key.contains('key.')) {
      throw ArgumentError('Unsupported preference');
    }
    final saved = switch (value) {
      bool v => await _prefs!.setBool(key, v),
      int v => await _prefs!.setInt(key, v),
      double v => await _prefs!.setDouble(key, v),
      String v => await _prefs!.setString(key, v),
      _ => false,
    };
    if (!saved) throw StateError('Could not save preferences');
    if (value == false &&
        const {
          'ai.enabled',
          'ai.cloud_opt_in',
          'ai.readNotes',
          'ai.allowActions',
          'ai.summary',
          'ai.ocr',
          'ai.transcription',
          'ai.tags',
          'ai.semantic',
          'cycle.assistant_access',
        }.contains(key)) {
      if (key == 'ai.cloud_opt_in') {
        _verified = null;
        _detected = null;
        capabilityCheck = null;
        _checks.clear();
      }
      cancel();
    }
    _notify();
  }

  CloudAIAdapter _adapter([AiProviderConfig? value]) {
    _activeClient = clientFactory?.call();
    return _active = CloudAIAdapter(
      config: value ?? config,
      outputLanguage: AiOutputLanguage.fromWire(string('ai.outputLanguage')),
      client: _activeClient,
    );
  }

  void _finishAdapter() {
    _active?.close();
    _activeClient?.close();
    _active = null;
    _activeClient = null;
  }

  Future<AiTestResult> verify(
    AiProviderConfig candidate, {
    bool recheck = false,
  }) async {
    await initialize();
    if (!flag('ai.cloud_opt_in')) throw StateError('Cloud consent is required');
    if (busy) throw StateError('Another request is running');
    final generation = ++_generation;
    busy = true;
    error = null;
    _verified = null;
    _detected = null;
    capabilityCheck = null;
    _notify();
    try {
      final tested = await _adapter(candidate).test();
      if (generation != _generation) {
        return const AiTestResult.failed('Cancelled');
      }
      if (tested.success) {
        final identity = _checkIdentity(candidate);
        var check = recheck ? null : _checks[identity];
        if (check == null) {
          // Explicit connection test only; probes contain no personal content.
          // The shared client lets cancellation close every concurrent probe.
          _finishAdapter();
          _activeClient = clientFactory?.call() ?? http.Client();
          check = await nexCheckCapabilities(candidate, client: _activeClient);
          if (generation != _generation || _closed) {
            return const AiTestResult.failed('Cancelled');
          }
          if (_checks.length >= 16) _checks.clear();
          _checks[identity] = check;
        }
        capabilityCheck = check;
        _verified = candidate;
        _detected = check.applyTo(candidate);
      }
      return tested;
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Future<void> saveProvider(AiProviderConfig value) async {
    await initialize();
    if (busy) throw StateError('Another request is running');
    if (value.provider == AiProvider.none) {
      if (!await _prefs!.setString('ai.provider', value.provider.wireName)) {
        throw StateError('Could not save provider');
      }
      cancel();
      return;
    }
    if (value.provider != AiProvider.none &&
        (_verified == null || !mapEquals(value.toMap(), _verified!.toMap()))) {
      throw StateError('Test this exact configuration before saving');
    }
    final before = configFor(value.provider);
    value = _detected ?? value;
    final wire = value.provider.wireName;
    final oldKey = await secrets.read('ai.key.$wire');
    final previous = {
      'ai.capabilityReport.$wire': _prefs!.getString(
        'ai.capabilityReport.$wire',
      ),
      for (final key in value.toMap().keys.where(
        (k) => k != 'apiKey' && k != 'provider',
      ))
        'ai.$key.$wire': _prefs!.getString('ai.$key.$wire'),
    };
    final oldSemantic = _prefs!.getBool('ai.semantic');
    final oldProvider = _prefs!.getString('ai.provider');
    try {
      if (value.apiKey.isEmpty) {
        await secrets.delete('ai.key.$wire');
      } else {
        await secrets.write('ai.key.$wire', value.apiKey);
        if (await secrets.read('ai.key.$wire') != value.apiKey) {
          throw StateError('Credential verification failed');
        }
      }
      for (final entry in value.toMap().entries) {
        if (entry.key != 'provider' && entry.key != 'apiKey') {
          if (!await _prefs!.setString('ai.${entry.key}.$wire', entry.value)) {
            throw StateError('Could not save provider');
          }
        }
      }
      if (capabilityCheck != null &&
          !await _prefs!.setString(
            'ai.capabilityReport.$wire',
            _capabilityReport(value),
          )) {
        throw StateError('Could not save capability report');
      }
      if (!await _prefs!.setString('ai.provider', wire)) {
        throw StateError('Could not activate provider');
      }
      if (nexNewlyOffered(before, value).contains(AiCapability.embeddings)) {
        // New search access must not silently start indexing the library.
        if (!await _prefs!.setBool('ai.semantic', false)) {
          throw StateError('Could not save search permission');
        }
      }
      _keys[wire] = value.apiKey;
      secureAvailable = true;
    } catch (_) {
      try {
        if (oldKey == null) {
          await secrets.delete('ai.key.$wire');
        } else {
          await secrets.write('ai.key.$wire', oldKey);
        }
        if (oldSemantic == null) {
          await _prefs!.remove('ai.semantic');
        } else {
          await _prefs!.setBool('ai.semantic', oldSemantic);
        }
        for (final entry in {...previous, 'ai.provider': oldProvider}.entries) {
          if (entry.value == null) {
            await _prefs!.remove(entry.key);
          } else {
            await _prefs!.setString(entry.key, entry.value!);
          }
        }
      } catch (_) {
        secureAvailable = false;
      }
      rethrow;
    }
    _notify();
  }

  void cancel() {
    if (_applying) return;
    _generation++;
    _finishAdapter();
    busy = false;
    pending = [];
    _notify();
  }

  void dismissPending() {
    pending = [];
    _notify();
  }

  void removeAttachment(int index) {
    attachments.removeAt(index);
    _notify();
  }

  void addAttachment(NexChatAttachment attachment) {
    attachments.add(attachment);
    _notify();
  }

  void _require([String? capability]) {
    if (!enabled) {
      throw StateError('AI is disabled or no provider is configured');
    }
    if (capability != null && !flag(capability, true)) {
      throw StateError('This capability is disabled');
    }
  }

  String contextLine(Note n) {
    final text = <String>{
      for (final part in [
        n.title,
        n.content,
        n.caption,
        n.ocrText,
        n.transcriptText,
        n.linkExcerpt,
      ])
        if (part != null && part.trim().isNotEmpty) part.trim(),
    }.join('\n');
    return jsonEncode({
      'id': n.id,
      'type': n.type.wireName,
      'text': text.substring(0, text.length.clamp(0, 1400)),
      'tags': n.tags.map((t) => t.name).toList(),
      if (n.dueAt != null) 'reminder': n.dueAt!.toIso8601String(),
      'repeat': n.dueRepeat.wireName,
      'pinned': n.pinnedAt != null,
    });
  }

  Future<String> _context(String question) async {
    if (!canRead) return '';
    if (focusedNote != null) {
      final note = focusedNote!;
      var context = contextLine(note);
      if (note.type == NoteType.file &&
          note.mediaUri != null &&
          RegExp(
            r'\.(txt|md|csv|json|log)$',
            caseSensitive: false,
          ).hasMatch(note.originalFilename ?? note.mediaUri!)) {
        final file = File(note.mediaUri!);
        if (await file.exists() && await file.length() <= 256 * 1024) {
          final text = await file.readAsString();
          context +=
              '\nAttached file text:\n${text.substring(0, text.length.clamp(0, 48000))}';
        }
      }
      return context;
    }
    final recent = await store.call<List<Note>>('timeline', {
      'limit': number('ai.notesContext').clamp(1, 200),
    });
    final matched = await store.call<List<Note>>('search', {
      'filters': SearchFilters(query: question),
    });
    final all = {
      for (final n in [
        ...matched.take(12),
        ...recent.take(number('ai.notesContext').clamp(1, 200)),
      ])
        n.id: n,
    };
    final text = all.values.map(contextLine).join('\n');
    return text.substring(0, text.length.clamp(0, 48000));
  }

  Future<void> send(String text) async {
    await initialize();
    if (busy || text.trim().isEmpty) return;
    if (pending.isNotEmpty) {
      throw StateError('Review the proposed changes first');
    }
    _require();
    final generation = ++_generation;
    busy = true;
    error = null;
    pending = [];
    _notify();
    try {
      turns.add(ChatMessage(role: ChatRole.user, content: text.trim()));
      await _saveConversation();
      final video = nexYouTubeWatchUrl(text.trim());
      if (video != null) {
        if (!config.supportsVideo) {
          throw StateError(
            'YouTube analysis requires a verified Gemini video model',
          );
        }
        final answer = await _adapter().analyzeYouTubeVideo(video);
        if (generation != _generation || _closed) return;
        if (answer == null || answer.trim().isEmpty) {
          throw StateError('The provider could not analyze this video');
        }
        turns.add(ChatMessage(role: ChatRole.assistant, content: answer));
        await _saveConversation();
        return;
      }
      var context = await _context(text);
      if (generation != _generation || _closed) return;
      final images = List<NexChatAttachment>.of(attachments);
      final focus = focusedNote;
      if (canRead &&
          focus?.type == NoteType.photo &&
          focus?.mediaUri != null &&
          config.supportsImages &&
          images.length < 4) {
        final file = File(focus!.mediaUri!);
        if (await file.exists() && await file.length() <= 8 * 1024 * 1024) {
          images.add(
            NexChatAttachment(
              bytes: await file.readAsBytes(),
              mimeType:
                  focus.mimeType ??
                  (file.path.toLowerCase().endsWith('.png')
                      ? 'image/png'
                      : 'image/jpeg'),
            ),
          );
        }
      }
      if (generation != _generation || _closed) return;
      final adapter = _adapter();
      for (var lookup = 0; lookup < 5; lookup++) {
        if (generation != _generation || _closed) return;
        final reply = await adapter.chat(
          turns,
          options: AiChatOptions(
            notesContext: context,
            canAct: canAct && canRead,
            notesOnly: flag('ai.notesOnly', true),
            creativity: AiCreativity.fromWire(string('ai.creativity')),
            length: AiAnswerLength.fromWire(string('ai.answerLength')),
            responseStyle: AiResponseStyle.fromWire(string('ai.responseStyle')),
            instruction:
                AiResponseStyle.fromWire(string('ai.responseStyle')) ==
                    AiResponseStyle.custom
                ? string('ai.instruction')
                : '',
            userName: string('ai.userName'),
            userIntroduction: string('ai.userIntroduction'),
            attachments: images,
            appGuide:
                'Nex Windows. Local notes, attachments, tags, reminders, threads and commitments. '
                'Local model is not available yet. Never claim a change ran before confirmation. '
                'Windows settable keys: theme, language, ai_language, palette, accent, text_size. '
                'Never change keys, provider, security, clipboard, backups or OS settings. '
                'Earlier action blocks are proposals. Never assume they ran; read the current library before relying on them.',
          ),
        );
        if (generation != _generation || _closed) return;
        if (reply == null || reply.trim().isEmpty) {
          throw StateError('The provider returned no complete answer');
        }
        final actions = parseAssistantActions(reply);
        if (actions.any((a) => !a.isRead) && (!canAct || !canRead)) {
          throw StateError('Assistant write access is disabled');
        }
        final reads = actions.where((a) => a.isRead).toList();
        if (reads.isNotEmpty && actions.every((a) => a.isRead) && lookup < 4) {
          if (!canRead) throw StateError('Library access is disabled');
          final answers = <String>[];
          for (final action in reads) {
            answers.add(await _lookup(action, question: text));
          }
          context += '\nLookup results:\n${answers.join('\n')}';
          if (context.length > 64000) {
            context = context.substring(context.length - 64000);
          }
          continue;
        }
        turns.add(ChatMessage(role: ChatRole.assistant, content: reply));
        pending = actions.where((a) => !a.isRead).toList();
        await _saveConversation();
        break;
      }
    } catch (e) {
      if (generation == _generation) error = e.toString();
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Future<String> _lookup(
    AssistantAction action, {
    required String question,
  }) async {
    switch (action.kind) {
      case AssistantActionKind.search:
        var notes = await store.call<List<Note>>('search', {
          'filters': SearchFilters(query: action.text ?? ''),
        });
        if (action.tagName != null) {
          notes = notes
              .where(
                (n) => n.tags.any(
                  (t) => t.name.toLowerCase() == action.tagName!.toLowerCase(),
                ),
              )
              .toList();
        }
        if (action.threadName != null) {
          final threads = await store.call<List<NoteThread>>('threads');
          final thread = threads
              .where(
                (t) => t.name.toLowerCase() == action.threadName!.toLowerCase(),
              )
              .firstOrNull;
          final members = thread == null
              ? <Note>[]
              : await store.call<List<Note>>('threadNotes', {
                  'thread': thread.id,
                });
          final ids = members.map((n) => n.id).toSet();
          notes = notes.where((n) => ids.contains(n.id)).toList();
        }
        return notes.take(40).map(contextLine).join('\n');
      case AssistantActionKind.threads:
        return (await store.call<List<NoteThread>>(
          'threads',
        )).map((t) => '${t.id}: ${t.name}').join('\n');
      case AssistantActionKind.tags:
        return (await store.call<List<Tag>>(
          'tags',
        )).map((t) => '${t.name}: ${t.color}').join('\n');
      case AssistantActionKind.commitments:
        return (await store.call<List<NexCommitment>>(
          'commitments',
        )).map((c) => '${c.title}: ${c.dueAt.toIso8601String()}').join('\n');
      case AssistantActionKind.deleted:
        return (await store.call<List<Note>>(
          'trash',
        )).take(30).map(contextLine).join('\n');
      case AssistantActionKind.cycle:
        if (!flag('cycle.assistant_access') ||
            !looksLikeCycleQuestion(question)) {
          return 'Private cycle access is off. Ask the user to enable it in AI permissions.';
        }
        return await store.call<String>('aiCycleContext');
      default:
        return '';
    }
  }

  Future<void> _saveConversation() async {
    conversations[conversationId] = {
      'at': DateTime.now().toUtc().toIso8601String(),
      'turns': turns
          .skip((turns.length - 200).clamp(0, turns.length))
          .map((t) => {'role': t.role.name, 'text': t.content})
          .toList(),
    };
    while (conversations.length > 50) {
      conversations.remove(conversations.keys.first);
    }
    await _prefs!.setString(
      'ai.windows.conversations',
      jsonEncode(conversations),
    );
    _notify();
  }

  void newConversation({Note? note}) {
    if (_applying) return;
    cancel();
    focusedNote = note;
    turns = [];
    result = null;
    error = null;
    attachments.clear();
    conversationId = newUuidV7();
    _notify();
  }

  void openConversation(String id) {
    newConversation();
    conversationId = id;
    final raw = conversations[id] as Map?;
    turns = [
      for (final t in (raw?['turns'] as List? ?? []))
        ChatMessage(
          role: t['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
          content: t['text'] as String,
        ),
    ];
    _notify();
  }

  Future<void> deleteConversation(String id) async {
    conversations.remove(id);
    if (conversationId == id) newConversation();
    await _prefs!.setString(
      'ai.windows.conversations',
      jsonEncode(conversations),
    );
    _notify();
  }

  Future<List<String>> applyPending({
    required Future<void> Function(AssistantAction) applySetting,
  }) async {
    _require();
    if (!canAct || !canRead || busy) {
      throw StateError('Assistant write access is disabled');
    }
    const settings = {
      'theme',
      'language',
      'ai_language',
      'palette',
      'accent',
      'text_size',
    };
    final actions = List<AssistantAction>.of(pending);
    if (actions.any(
      (a) =>
          a.kind == AssistantActionKind.setting &&
          !settings.contains(a.settingKey),
    )) {
      throw StateError(
        'This Windows setting is not available to the assistant',
      );
    }
    for (final a in actions.where(
      (a) => a.kind == AssistantActionKind.setting,
    )) {
      final value = a.settingValue;
      final valid = switch (a.settingKey) {
        'theme' => const {'system', 'light', 'dark'}.contains(value),
        'language' => const {'system', 'en', 'fa'}.contains(value),
        'ai_language' => const {'auto', 'en', 'fa'}.contains(value),
        'text_size' => const {
          'small',
          'default',
          'large',
          'larger',
        }.contains(value),
        'palette' => const {
          'classic',
          'paper',
          'autumn',
          'blossom',
          'forest',
          'turquoise',
          'saffron',
          'midnight',
          'ocean',
          'graphite',
          'bauhaus',
          'porcelain',
          'circuit',
          'afterimage',
        }.contains(value),
        'accent' =>
          value == 'default' ||
              RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value ?? ''),
        _ => false,
      };
      if (!valid) throw StateError('Invalid Windows setting value');
    }
    _applying = true;
    busy = true;
    _notify();
    try {
      final writes = actions
          .where((a) => a.kind != AssistantActionKind.setting)
          .toList();
      final changed = writes.isEmpty
          ? <String>[]
          : await store.call<List<String>>('aiActions', {'actions': writes});
      // A settings failure must never replay the already committed note writes.
      pending = actions
          .where((a) => a.kind == AssistantActionKind.setting)
          .toList();
      for (final a in List<AssistantAction>.of(pending)) {
        await applySetting(a);
        pending.remove(a);
      }
      return changed;
    } finally {
      _applying = false;
      busy = false;
      _notify();
    }
  }

  Future<void> saveResult(Note note, String task) async {
    if (result == null || result!.trim().isEmpty) return;
    if (!const {'summary', 'ocr', 'transcribe'}.contains(task)) {
      throw ArgumentError('Unsupported result');
    }
    await store.call<void>('aiEnrich', {
      'id': note.id,
      'field': task,
      'text': result,
    });
  }

  Future<List<Note>> semanticSearch(String query) async {
    await initialize();
    _require('ai.semantic');
    if (!canRead || !config.supportsEmbeddings || busy) {
      throw StateError('Semantic search is unavailable');
    }
    final generation = ++_generation;
    busy = true;
    _notify();
    try {
      final vector = await (_adapter().embed(query) ?? Future.value(null));
      if (generation != _generation || vector == null) return [];
      return await store.call<List<Note>>('aiNearest', {
        'space': config.embeddingSpace,
        'values': vector.values,
      });
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  int indexed = 0;
  Future<void> indexNotes() async {
    await initialize();
    _require('ai.semantic');
    if (!canRead || !config.supportsEmbeddings || busy) {
      throw StateError('Semantic search is unavailable');
    }
    final generation = ++_generation;
    busy = true;
    indexed = 0;
    _notify();
    try {
      final notes = await store.call<List<Note>>('timeline', {'limit': 200});
      if (generation != _generation) return;
      final adapter = _adapter();
      for (final note in notes.take(200)) {
        if (generation != _generation) return;
        final text = note.searchableDerivedText ?? note.aiSourceText ?? '';
        if (text.trim().isEmpty) continue;
        final vector =
            await (adapter.embed(
                  text.substring(0, text.length.clamp(0, 12000)),
                ) ??
                Future.value(null));
        if (generation != _generation) return;
        if (vector == null) throw StateError('Embedding request failed');
        await store.call<void>('aiEmbedding', {
          'id': note.id,
          'space': config.embeddingSpace,
          'values': vector.values,
        });
        indexed++;
        _notify();
      }
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Future<String> process(
    Note note,
    String task, {
    AiOutputLanguage target = AiOutputLanguage.persian,
    NexRewriteStyle? style,
  }) async {
    await initialize();
    _require(switch (task) {
      'ocr' => 'ai.ocr',
      'transcribe' => 'ai.transcription',
      'tags' => 'ai.tags',
      'summary' => 'ai.summary',
      _ => null,
    });
    if (busy) throw StateError('Another request is running');
    final generation = ++_generation;
    busy = true;
    error = null;
    suggestions = [];
    _notify();
    try {
      final adapter = _adapter();
      final text = note.type == NoteType.checklist
          ? note.content ?? ''
          : note.aiSourceText ?? note.caption ?? '';
      final String? output;
      switch (task) {
        case 'summary':
          output =
              (await (adapter.summarize(note) ?? Future.value(null)))?.text;
        case 'translate':
          output = await adapter.translate(text, target: target);
        case 'rewrite':
          output = await adapter.rewrite(
            text,
            style: style ?? NexRewriteStyle.fix,
          );
        case 'tags':
          suggestions =
              (await (adapter.suggestTags(note) ??
                      Future.value(<TagSuggestion>[])))
                  .map((t) => t.name)
                  .toList();
          output = suggestions.join(', ');
        case 'ocr':
          if (!config.supportsImages || note.mediaUri == null) {
            throw StateError('Image reading is unavailable');
          }
          final f = File(note.mediaUri!);
          if (await f.length() > 8 * 1024 * 1024) {
            throw StateError('Image exceeds 8 MB');
          }
          output =
              (await (adapter.ocr(
                        ImageRef(
                          mediaUri: f.path,
                          bytes: await f.readAsBytes(),
                        ),
                      ) ??
                      Future.value(null)))
                  ?.text;
        case 'transcribe':
          if (!config.supportsTranscription || note.mediaUri == null) {
            throw StateError('Audio transcription is unavailable');
          }
          final f = File(note.mediaUri!);
          if (await f.length() > 24 * 1024 * 1024) {
            throw StateError('Audio exceeds 24 MB');
          }
          output =
              (await (adapter.transcribe(
                        AudioRef(
                          mediaUri: f.path,
                          bytes: await f.readAsBytes(),
                        ),
                      ) ??
                      Future.value(null)))
                  ?.text;
        default:
          throw ArgumentError('Unsupported operation');
      }
      if (generation != _generation) throw StateError('Cancelled');
      if (output == null || output.trim().isEmpty) {
        throw StateError('No complete result was returned');
      }
      result = output;
      return output;
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Future<String> transcribeQuestion(String path) async {
    await initialize();
    _require('ai.transcription');
    if (busy || !config.supportsTranscription) {
      throw StateError('Transcription is unavailable');
    }
    final generation = ++_generation;
    busy = true;
    _notify();
    try {
      final file = File(path);
      if (await file.length() > 24 * 1024 * 1024) {
        throw StateError('Audio exceeds 24 MB');
      }
      final bytes = await file.readAsBytes();
      if (generation != _generation) throw StateError('Cancelled');
      _require('ai.transcription');
      final transcript =
          await (_adapter().transcribe(
                AudioRef(mediaUri: path, bytes: bytes),
              ) ??
              Future.value(null));
      if (generation != _generation ||
          transcript == null ||
          transcript.text.trim().isEmpty) {
        throw StateError('No complete transcript');
      }
      return transcript.text;
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Future<void> refreshBrief({bool manual = false}) async {
    await initialize();
    if (!enabled || !canRead || !flag('ai.summary', true) || busy) return;
    final generation = ++_generation;
    busy = true;
    _notify();
    try {
      final notes = await store.call<List<Note>>('timeline');
      if (generation != _generation ||
          _closed ||
          !enabled ||
          !canRead ||
          !flag('ai.summary', true)) {
        return;
      }
      final fingerprint =
          '${config.provider.wireName}|${config.resolvedModel}|${string('ai.outputLanguage')}|${notes.take(30).map((n) => '${n.id}:${n.updatedAt.toIso8601String()}').join('|')}';
      final now = DateTime.now();
      final success = DateTime.tryParse(string('ai.windows.brief.success'));
      final attempt = DateTime.tryParse(string('ai.windows.brief.attempt'));
      if (!manual &&
          (fingerprint == string('ai.windows.brief.fingerprint') ||
              success != null &&
                  now.difference(success) < const Duration(hours: 1) ||
              attempt != null &&
                  now.difference(attempt) < const Duration(minutes: 15))) {
        return;
      }
      if (!await _prefs!.setString(
        'ai.windows.brief.attempt',
        now.toIso8601String(),
      )) {
        throw StateError('Could not save refresh state');
      }
      if (generation != _generation ||
          _closed ||
          !enabled ||
          !canRead ||
          !flag('ai.summary', true)) {
        return;
      }
      final answer = await _adapter().digest(
        notes.take(30).map(contextLine).join('\n'),
      );
      if (generation != _generation ||
          answer == null ||
          answer.trim().isEmpty) {
        return;
      }
      brief = answer;
      await _prefs!.setString('ai.windows.brief', answer);
      await _prefs!.setString('ai.windows.brief.fingerprint', fingerprint);
      await _prefs!.setString(
        'ai.windows.brief.success',
        now.toIso8601String(),
      );
    } finally {
      if (generation == _generation) {
        _finishAdapter();
        busy = false;
        _notify();
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    cancel();
    // Initialization only reads preferences/credentials. Shutdown must not wait
    // on a platform credential request; late reads cannot notify disposed UI.
    dispose();
  }
}

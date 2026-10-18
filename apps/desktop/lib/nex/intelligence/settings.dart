import 'package:flutter/material.dart';
import 'package:nex_ai/cloud.dart';
import '../../l10n/intelligence_strings.dart';
import '../features_state.dart';
import 'controller.dart';

Future<void> showIntelligenceSettings(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => NexScope(
    features: NexScope.of(context),
    child: Dialog(
      child: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: DesktopIntelligenceSettings(),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class DesktopIntelligenceSettings extends StatefulWidget {
  const DesktopIntelligenceSettings({super.key});
  @override
  State<DesktopIntelligenceSettings> createState() => _SettingsState();
}

class _SettingsState extends State<DesktopIntelligenceSettings> {
  DesktopIntelligence? _ai;
  AiProvider _provider = AiProvider.none;
  final _key = TextEditingController(),
      _url = TextEditingController(),
      _model = TextEditingController();
  final _extra = <String, String>{};
  AiProviderConfig? _tested;
  String? _status;
  bool _obscure = true, _loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ai ??= NexScope.of(context).intelligence;
    if (!_loaded) {
      _loaded = true;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    await _ai!.initialize();
    if (mounted) setState(() => _select(_ai!.config.provider));
  }

  void _select(AiProvider p) {
    final c = _ai!.configFor(p);
    _provider = p;
    _key.text = c.apiKey;
    _url.text = c.baseUrl;
    _model.text = c.model;
    _extra
      ..clear()
      ..addAll(c.toMap());
    _tested = null;
    _status = null;
  }

  AiProviderConfig get _current => AiProviderConfig.fromMap({
    ..._extra,
    'provider': _provider.wireName,
    'apiKey': _key.text,
    'baseUrl': _provider.needsBaseUrl ? _url.text : '',
    'model': _model.text,
  });
  @override
  void dispose() {
    _key.dispose();
    _url.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _status = AiStrings.of(context).t('failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = _ai!;
    final s = AiStrings.of(context);
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        if (!ai.ready) return const Center(child: CircularProgressIndicator());
        Widget toggle(String title, String key, [bool fallback = false]) =>
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t(title)),
              value: ai.flag(key, fallback),
              onChanged: (v) => _run(() => ai.setValue(key, v)),
            );
        Widget field(
          String key, {
          TextEditingController? controller,
          bool secret = false,
        }) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: TextFormField(
            key: ValueKey('ai-field-$_provider-$key'),
            controller: controller,
            initialValue: controller == null ? _extra[key] : null,
            obscureText: secret && _obscure,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: !secret,
            decoration: InputDecoration(
              labelText: s.t(key),
              suffixIcon: secret
                  ? IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    )
                  : null,
            ),
            onChanged: (v) => setState(() {
              if (controller == null) _extra[key] = v;
              _tested = null;
              _status = null;
            }),
          ),
        );
        Widget option(
          String title,
          String pref,
          List<String> values,
          String fallback,
        ) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonFormField<String>(
            initialValue: values.contains(ai.string(pref))
                ? ai.string(pref)
                : fallback,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.t(title)),
            items: values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(s.t(v == 'brief' ? 'briefLength' : v)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) _run(() => ai.setValue(pref, v));
            },
          ),
        );
        return Material(
          color: theme.colorScheme.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.t('settings'),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.t('privacy'),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 12),
              toggle('enabled', 'ai.enabled'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(s.t('cloudConsent')),
                value: ai.flag('ai.cloud_opt_in'),
                onChanged: (v) =>
                    _run(() => ai.setValue('ai.cloud_opt_in', v ?? false)),
              ),
              const Divider(height: 40),
              DropdownButtonFormField<AiProvider>(
                key: ValueKey('provider-$_provider'),
                initialValue: _provider,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.t('provider')),
                items: AiProvider.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p == AiProvider.none ? s.t('none') : p.label,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: ai.busy
                    ? null
                    : (p) {
                        if (p != null) setState(() => _select(p));
                      },
              ),
              if (_provider != AiProvider.none) ...[
                field('apiKey', controller: _key, secret: true),
                if (_provider.needsBaseUrl) field('endpoint', controller: _url),
                field('model', controller: _model),
                Text(_provider.defaultModel, style: theme.textTheme.labelSmall),
                Text(s.t('connectHint'), style: theme.textTheme.bodySmall),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(s.t('advanced')),
                  children: [
                    for (final name in [
                      'transcriptionModel',
                      'transcriptionUrl',
                      'embeddingModelId',
                      'embeddingUrl',
                    ])
                      field(name),
                    for (final key in ['images', 'audio', 'embeddings'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('$_provider-$key'),
                          initialValue: _extra[key] ?? 'automatic',
                          decoration: InputDecoration(labelText: s.t(key)),
                          items: AiCapabilityMode.values
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.name,
                                  child: Text(
                                    s.t(
                                      v == AiCapabilityMode.enabled
                                          ? 'on'
                                          : v.name,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _extra[key] = v!;
                            _tested = null;
                          }),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (_provider != AiProvider.none)
                    OutlinedButton.icon(
                      onPressed: ai.busy || !ai.flag('ai.cloud_opt_in')
                          ? null
                          : () => _run(() async {
                              final candidate = _current;
                              final tested = await ai.verify(candidate);
                              if (mounted) {
                                setState(() {
                                  _tested = tested.success ? candidate : null;
                                  _status = tested.detail;
                                });
                              }
                            }),
                      icon: const Icon(Icons.network_check),
                      label: Text(s.t('test')),
                    ),
                  FilledButton.icon(
                    onPressed:
                        ai.busy ||
                            _provider != AiProvider.none && _tested == null
                        ? null
                        : () => _run(() async {
                            await ai.saveProvider(_current);
                            if (mounted) setState(() => _status = s.t('saved'));
                          }),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(s.t('save')),
                  ),
                  if (ai.busy)
                    TextButton(onPressed: ai.cancel, child: Text(s.t('stop'))),
                ],
              ),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SelectableText(_status!),
                ),
              if (!ai.secureAvailable)
                Text(
                  s.t('securityError'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.memory_outlined),
                  title: Text(s.t('local')),
                  subtitle: Text(s.t('localHint')),
                  trailing: const Icon(Icons.lock_clock_outlined),
                ),
              ),
              const Divider(height: 40),
              Text(s.t('permissions'), style: theme.textTheme.titleMedium),
              toggle('readNotes', 'ai.readNotes', true),
              toggle('allowActions', 'ai.allowActions', true),
              toggle('cycle', 'cycle.assistant_access'),
              DropdownButtonFormField<int>(
                initialValue:
                    [
                      10,
                      20,
                      50,
                      100,
                      200,
                    ].contains(ai.number('ai.notesContext'))
                    ? ai.number('ai.notesContext')
                    : 20,
                decoration: InputDecoration(labelText: s.t('context')),
                items: [10, 20, 50, 100, 200]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (n) =>
                    _run(() => ai.setValue('ai.notesContext', n!)),
              ),
              const Divider(height: 40),
              Text(s.t('capabilities'), style: theme.textTheme.titleMedium),
              for (final entry in {
                'summary': 'summary',
                'ocr': 'ocr',
                'transcribe': 'transcription',
                'tags': 'tags',
                'semantic': 'semantic',
              }.entries)
                toggle(entry.key, 'ai.${entry.value}', true),
              if (ai.config.supportsEmbeddings)
                OutlinedButton.icon(
                  onPressed: ai.busy ? null : () => _run(ai.indexNotes),
                  icon: const Icon(Icons.manage_search_outlined),
                  label: Text('${s.t('index')} · ${ai.indexed}'),
                ),
              const Divider(height: 40),
              option('language', 'ai.outputLanguage', [
                'auto',
                'fa',
                'en',
              ], 'auto'),
              option(
                'creativity',
                'ai.creativity',
                AiCreativity.values.map((v) => v.wireName).toList(),
                'balanced',
              ),
              option(
                'length',
                'ai.answerLength',
                AiAnswerLength.values.map((v) => v.wireName).toList(),
                'standard',
              ),
              option(
                'style',
                'ai.responseStyle',
                AiResponseStyle.values.map((v) => v.wireName).toList(),
                'natural',
              ),
              toggle('notesOnly', 'ai.notesOnly', true),
              for (final key in ['instruction', 'userName', 'userIntroduction'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: TextFormField(
                    initialValue: ai.string('ai.$key'),
                    minLines: key == 'instruction' ? 2 : 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: s.t(
                        {
                          'instruction': 'instructions',
                          'userName': 'name',
                          'userIntroduction': 'aboutYou',
                        }[key]!,
                      ),
                    ),
                    onChanged: (value) =>
                        _run(() => ai.setValue('ai.$key', value)),
                  ),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(s.t('activity')),
                children: [
                  Text(s.t('disclosureHint'), style: theme.textTheme.bodySmall),
                  FutureBuilder<List<DisclosureEntry>>(
                    future: NexDisclosureLog.read(),
                    builder: (context, snap) => Column(
                      children: [
                        for (final e
                            in (snap.data ?? <DisclosureEntry>[]).reversed.take(
                              20,
                            ))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${e.provider} · ${e.host}'),
                            subtitle: Text(
                              '${e.at.toLocal()} · ${e.purpose.name} · ${e.bytes} B',
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _run(() async {
                      await NexDisclosureLog.clear();
                      if (mounted) setState(() {});
                    }),
                    child: Text(s.t('clearActivity')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nex_ai/cloud.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/desktop_strings.dart';
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
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AiStrings.of(context).t('settings'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
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
  bool _obscure = true, _loaded = false, _providerPage = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ai ??= NexScope.of(context).intelligence;
    if (!_loaded) {
      _loaded = true;
      _initialize();
    }
  }

  void _showProvider(bool show) {
    setState(() => _providerPage = show);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.maybeOf(context)?.position.jumpTo(0);
    });
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
        final d = DesktopStrings.of(context);
        final c = theme.colorScheme;
        Widget section(String title, IconData icon, List<Widget> children) =>
            NexSoftCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: Icon(icon, color: c.primary),
                title: Text(title, style: theme.textTheme.titleMedium),
                children: children,
              ),
            );
        Widget ability(
          String title,
          String pref,
          String hint,
          IconData icon,
          bool supported,
        ) => NexFeatureCard(
          icon: icon,
          title: s.t(title),
          description: d.t(
            supported || !ai.config.isUsable ? hint : 'notSupported',
          ),
          value: supported && ai.flag(pref, true),
          onChanged: supported ? (v) => _run(() => ai.setValue(pref, v)) : null,
        );
        final content = <Widget>[
          if (_providerPage) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _showProvider(false),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(s.t('settings')),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.t('provider'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(d.t('providerHint'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 22),
            NexResponsiveGrid(
              minWidth: 280,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final provider in AiProvider.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: _provider == provider
                              ? theme.colorScheme.primary.withValues(alpha: .12)
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          child: ListTile(
                            key: ValueKey(
                              'provider-choice-${provider.wireName}',
                            ),
                            selected: _provider == provider,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            leading: Icon(
                              provider == AiProvider.none
                                  ? Icons.cloud_off_outlined
                                  : Icons.cloud_outlined,
                            ),
                            title: Text(
                              provider == AiProvider.none
                                  ? s.t('none')
                                  : provider.label,
                            ),
                            subtitle: provider == AiProvider.none
                                ? null
                                : Text(ai.configFor(provider).resolvedModel),
                            trailing: _provider == provider
                                ? const Icon(Icons.check_circle_rounded)
                                : null,
                            onTap: ai.busy
                                ? null
                                : () => setState(() => _select(provider)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    NexSoftCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.memory_outlined),
                        title: Text(s.t('local')),
                        subtitle: Text(s.t('localHint')),
                        trailing: Text(s.t('soon')),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
                NexSoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_provider != AiProvider.none) ...[
                        field('apiKey', controller: _key, secret: true),
                        if (_provider.needsBaseUrl)
                          field('endpoint', controller: _url),
                        field('model', controller: _model),
                        Text(
                          _provider.defaultModel,
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          s.t('connectHint'),
                          style: theme.textTheme.bodySmall,
                        ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('$_provider-$key'),
                                  initialValue: _extra[key] ?? 'automatic',
                                  decoration: InputDecoration(
                                    labelText: s.t(key),
                                  ),
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
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(s.t('cloudConsent')),
                        value: ai.flag('ai.cloud_opt_in'),
                        onChanged: (v) => _run(
                          () => ai.setValue('ai.cloud_opt_in', v ?? false),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                                          _tested = tested.success
                                              ? candidate
                                              : null;
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
                                    _provider != AiProvider.none &&
                                        _tested == null
                                ? null
                                : () => _run(() async {
                                    await ai.saveProvider(_current);
                                    if (mounted) {
                                      setState(() => _status = s.t('saved'));
                                    }
                                  }),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(s.t('save')),
                          ),
                          if (ai.busy)
                            TextButton(
                              onPressed: ai.cancel,
                              child: Text(s.t('stop')),
                            ),
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
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            NexSoftCard(
              accent: c.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const NexIconBadge(
                        icon: Icons.auto_awesome_rounded,
                        size: 54,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.t(ai.enabled ? 'aiStatusOn' : 'aiStatusOff'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.t('aiStatusHint'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: s.t('enabled'),
                        child: Switch.adaptive(
                          value: ai.flag('ai.enabled'),
                          onChanged: (v) =>
                              _run(() => ai.setValue('ai.enabled', v)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(s.t('cloudConsent')),
                    value: ai.flag('ai.cloud_opt_in'),
                    onChanged: (v) =>
                        _run(() => ai.setValue('ai.cloud_opt_in', v ?? false)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            NexSoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  NexSettingsLink(
                    key: const ValueKey('ai-provider-open'),
                    icon: Icons.key_outlined,
                    title: s.t('provider'),
                    subtitle: ai.config.provider == AiProvider.none
                        ? s.t('configure')
                        : '${ai.config.provider.label} · ${ai.config.resolvedModel}',
                    onTap: () => _showProvider(true),
                  ),
                  const Divider(height: 1, indent: 58),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(s.t('activity')),
                    children: [
                      Text(
                        s.t('disclosureHint'),
                        style: theme.textTheme.bodySmall,
                      ),
                      FutureBuilder<List<DisclosureEntry>>(
                        future: NexDisclosureLog.read(),
                        builder: (context, snap) => Column(
                          children: [
                            for (final e
                                in (snap.data ?? <DisclosureEntry>[]).reversed
                                    .take(20))
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
            ),
            const SizedBox(height: 26),
            Text(
              d.t('abilities'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            NexResponsiveGrid(
              children: [
                ability(
                  'transcribe',
                  'ai.transcription',
                  'transcriptionHint',
                  Icons.graphic_eq_rounded,
                  ai.config.isUsable && ai.config.supportsTranscription,
                ),
                ability(
                  'ocr',
                  'ai.ocr',
                  'imageHint',
                  Icons.image_search_outlined,
                  ai.config.isUsable && ai.config.supportsImages,
                ),
                ability(
                  'summary',
                  'ai.summary',
                  'summaryHint',
                  Icons.summarize_outlined,
                  ai.config.isUsable,
                ),
                ability(
                  'tags',
                  'ai.tags',
                  'tagsHint',
                  Icons.label_outline_rounded,
                  ai.config.isUsable,
                ),
                ability(
                  'semantic',
                  'ai.semantic',
                  'semanticHint',
                  Icons.manage_search_rounded,
                  ai.config.isUsable && ai.config.supportsEmbeddings,
                ),
                NexFeatureCard(
                  icon: Icons.hub_outlined,
                  title: d.t('related'),
                  description: d.t('paused'),
                  value: false,
                  onChanged: null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (ai.config.supportsEmbeddings) ...[
              NexSoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('semantic'), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(d.t('semanticHint')),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: ai.busy ? null : () => _run(ai.indexNotes),
                      icon: const Icon(Icons.manage_search_outlined),
                      label: Text('${s.t('index')} · ${ai.indexed}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            section(d.t('access'), Icons.shield_outlined, [
              Text(d.t('accessHint')),
              const SizedBox(height: 12),
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
                onChanged: (n) {
                  if (n != null) _run(() => ai.setValue('ai.notesContext', n));
                },
              ),
            ]),
            const SizedBox(height: 18),
            section(d.t('response'), Icons.tune_rounded, [
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
            ]),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: c.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.t('privacy'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.6,
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ];
        return Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          ),
        );
      },
    );
  }
}

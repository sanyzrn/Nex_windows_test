# Windows 0.20.0: intelligence and chromatic workspace

## Phased implementation

1. Audit Android 2.1.6 (`67930daa7230273055107ac210faa8b86167e540`), reuse its
   provider adapters, action parser, budgets and pure-Dart AI contracts.
2. Add Windows credential storage, exact-configuration verification, scoped
   context, cancellable requests, conversations and explicit action review.
3. Build note tools, image/voice input, semantic indexing/search, source links,
   an hourly automatic brief cache and an unrestricted manual refresh.
4. Replace the wide library list with a virtualized colored gallery, separate
   pinned shelf and focused reader; retain list, filters and multi-selection.
5. Analyze, exercise regressions, review Windows golden screenshots, run native
   smoke/build/installer checks and publish through the existing trusted CI.

## Shared behavior and Windows boundaries

| Capability | Windows 0.20.0 |
| --- | --- |
| Providers | Anthropic, OpenAI, Gemini, OpenRouter, custom OpenAI-compatible |
| Per-provider config | Model, URL, transcription and embedding endpoints/models, capability overrides |
| Credentials | Windows secure storage; read-back verified before provider activation |
| Permissions | Master off, separate cloud consent, note context, proposed writes, private cycle access off |
| Assistant | History, selected-note/recent context, keyword lookups, source chips, image attachments, voice questions |
| Note tools | Summary, translation, six rewrite styles, tag suggestions, OCR, transcription |
| Proposed edits | Preview and explicit Apply; preflight targets, transactional database batch |
| Semantic search | Manual index of up to 200 recent notes; model-space invalidation prevents incompatible vectors mixing |
| Brief | Previous successful text retained; automatic refresh requires changed context and waits 1 hour after success / 15 minutes after attempt |
| Local model | Visible coming-later placeholder; no model download or inference |
| Backups | Existing shared library/appearance contract retained; AI keys/history are device-local |
| Synchronization | Backup interchange only; no live multi-device sync |

Media requests are explicit. Chat can send a focused image or chosen image
attachments; text-file context is bounded. OCR accepts at most 8 MB and audio
24 MB. Voice questions produce editable composer text before Send. Provider
capabilities decide which media/search controls are available. Network and
model failures keep the previous generated preview; original writing is only
replaced after an explicit confirmation.

Android wire names and provider request policies are reused directly, including
Gemini naming and OpenAI reasoning-token behavior. Windows exposes a constrained
setting-action whitelist (theme, language, answer language, palette, accent and
text size), not OS integration, credentials or arbitrary settings. Cycle tables
remain outside ordinary note context and require their own explicit permission.
The local disclosure log records hosts, purpose and request size, never API keys
or prompt bodies. Clearing it does not clear conversations or notes.

## Design

The oldest colored tag gives each note its full card fill. Tag order and renames
do not change that choice. Tints are bounded independently for light/dark themes
and reduced where needed to retain readable secondary text. Untagged notes use
the palette surface; high-contrast mode keeps a neutral fill and stronger edge.
The gallery and compact list retain keyboard focus, Ctrl/Shift selection,
context menus, search, filters, pagination and trash recovery. Large text grows
cards rather than clipping metadata.

## Validation

The release is gated on desktop tests and Windows screenshot comparisons,
shared UI/core/data/cloud-AI tests, native smoke, a Windows release build,
installer packaging and checksum verification. The removable-runtime proof
removes the on-device binding and LiteRT dependency while retaining functional
cloud adapters. Current-run evidence is recorded after CI completes.

Physical microphone quality, real provider-account quotas/billing, clean-machine
installation and a future local runtime require validation on their respective
devices/services; deterministic HTTP tests do not assert those properties.

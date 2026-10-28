import '../../l10n/desktop_format.dart';
import '../../l10n/app_localizations.dart';
import 'package:nex_ui/nex_ui.dart';
import '../../l10n/utility_strings.dart';
import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../../core/models.dart';
import '../flyout.dart';
import '../widgets.dart';

/// Clipboard history: text and images, search, pins that survive restarts.
class ClipboardView extends StatefulWidget {
  const ClipboardView({super.key});

  @override
  State<ClipboardView> createState() => _ClipboardViewState();
}

class _ClipboardViewState extends State<ClipboardView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    final q = _search.text.toLowerCase();

    final pinnedImages = c.clips.where((x) => x.isImage && x.pinned).toList();
    final pinnedText = c.clipboard.favorites.where((x) => !x.isImage).toList();
    final rest = c.clips.where((x) => !x.pinned).toList();
    final list = [...pinnedImages, ...pinnedText, ...rest]
        .where((x) => x.isImage || (x.text ?? '').toLowerCase().contains(q))
        .toList();

    return Panel(
      children: [
        Head(
          // The panel header above already titles this view (audit defect 5
          // family: the flyout header is the single title bar).
          onBack: () => _backToMore(c),
          trailing: LinkButton(
            label: utilityLabel(context, 'utility2'),
            onTap: () {
              // Pinned entries survive a clear; only unpinned history goes.
              c.clipboard.clear();
            },
          ),
        ),
        Field(
          controller: _search,
          hint: utilityLabel(context, 'utility3'),
          autofocusDelayed: true,
          onChanged: (_) => setState(() {}),
        ),
        if (c.clipboard.saving) Text(AppLocalizations.of(context)!.saving),
        if (c.clipboard.error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.clipboardSaveFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: c.clipboard.retry,
                child: Text(AppLocalizations.of(context)!.clipboardRetry),
              ),
            ],
          ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: c.isWindowMode ? 560 : 300),
          child: list.isEmpty
              ? Empty(utilityLabel(context, 'utility0'))
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final item in list)
                        if (item.isImage)
                          _ImageClipItem(entry: item)
                        else
                          _TextClipItem(entry: item),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _backToMore(PanelController c) {
    c.backToTools();
  }
}

class _TextClipItem extends StatelessWidget {
  const _TextClipItem({required this.entry});

  final ClipEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = LiquidScope.panelOf(context);
    final text = (entry.text ?? '').replaceAll(RegExp(r'\s+'), ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ItemRow(
        pinned: entry.pinned,
        sub: Text(
          '${entry.pinned ? AppLocalizations.of(context)!.pinned : ago(context, entry.time)} · ${desktopDigits(context, AppLocalizations.of(context)!.characters((entry.text ?? '').length))}',
        ),
        onTap: () => c.deliver(entry.text ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ItemAction(
              tooltip: entry.pinned
                  ? AppLocalizations.of(context)!.unpin
                  : AppLocalizations.of(context)!.pin,
              child: Icon(
                entry.pinned ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              onTap: () => c.togglePinClip(entry),
            ),
            ItemAction(
              tooltip: AppLocalizations.of(context)!.delete,
              child: const Icon(Icons.delete_outline_rounded),
              onTap: () => c.removeClip(entry),
            ),
          ],
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: nexDirectionOf(text),
        ),
      ),
    );
  }
}

class _ImageClipItem extends StatelessWidget {
  const _ImageClipItem({required this.entry});

  final ClipEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final c = LiquidScope.panelOf(context);
    final img = entry.image!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ItemRow(
        pinned: entry.pinned,
        plain: true,
        onTap: () {
          c.copyImage(img);
          c.close();
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ItemAction(
              tooltip: entry.pinned
                  ? AppLocalizations.of(context)!.unpin
                  : AppLocalizations.of(context)!.pin,
              child: Icon(
                entry.pinned ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              onTap: () => c.togglePinClip(entry),
            ),
            ItemAction(
              tooltip: AppLocalizations.of(context)!.delete,
              child: const Icon(Icons.delete_outline_rounded),
              onTap: () => c.removeClip(entry),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: p.soft2,
                alignment: Alignment.center,
                constraints: const BoxConstraints(maxHeight: 120),
                child: RgbaImage(
                  rgba: img.rgba,
                  w: img.w,
                  h: img.h,
                  maxExtent: 240,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${AppLocalizations.of(context)!.image} · ${img.w}×${img.h} · ${entry.pinned ? AppLocalizations.of(context)!.pinned : ago(context, entry.time)}',
              style: TextStyle(
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                fontFamilyFallback: const ['Segoe UI'],
                fontSize: 10,
                color: p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String ago(BuildContext context, DateTime t) {
  final l = AppLocalizations.of(context)!;
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return l.justNow;
  if (s < 3600) return desktopDigits(context, l.minutesAgo(s ~/ 60));
  if (s < 86400) return desktopDigits(context, l.hoursAgo(s ~/ 3600));
  return desktopDigits(context, l.daysAgo(s ~/ 86400));
}

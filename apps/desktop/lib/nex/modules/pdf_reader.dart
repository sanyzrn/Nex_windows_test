import 'dart:async';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/desktop_format.dart';
import '../features_state.dart';

/// PDFium is a native build asset, not a runtime download. Only local files
/// enter this view; no URI loader or provider request is involved.
class DesktopPdfReader extends StatefulWidget {
  const DesktopPdfReader({super.key, required this.features, this.initialPath});
  final NexFeatures features;
  final String? initialPath;
  @override
  State<DesktopPdfReader> createState() => _DesktopPdfReaderState();
}

class _DesktopPdfReaderState extends State<DesktopPdfReader> {
  final controller = PdfViewerController();
  late final searcher = PdfTextSearcher(controller)..addListener(_changed);
  final query = TextEditingController();
  late String? path = widget.initialPath;
  int page = 1, count = 0, revision = 0;
  bool failed = false;
  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> choose() async {
    final l = AppLocalizations.of(context)!;
    try {
      final files =
          await widget.features.pickFiles?.call([
            XTypeGroup(label: l.modulePdf, extensions: const ['pdf']),
          ]) ??
          await openFiles(
            acceptedTypeGroups: [
              XTypeGroup(label: l.modulePdf, extensions: const ['pdf']),
            ],
          );
      if (!mounted || files.isEmpty) return;
      setState(() {
        path = files.first.path;
        page = 1;
        count = 0;
        failed = false;
        revision++;
      });
      query.clear();
      searcher.resetTextSearch();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Duration get duration => NexMotion.of(context, NexMotion.standard);
  Future<void> turn(int value) async {
    if (!controller.isReady || value < 1 || value > count) return;
    await controller.goToPage(
      pageNumber: value,
      anchor: PdfPageAnchor.center,
      duration: duration,
    );
  }

  Future<String?> password() async {
    if (!mounted) return null;
    final l = AppLocalizations.of(context)!;
    final input = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.pdfPassword),
          content: TextField(
            controller: input,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.moduleCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text),
              child: Text(l.moduleOpen),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<void> jump() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => DesktopPdfPagePicker(count: count, current: page),
    );
    if (mounted && selected != null) await turn(selected);
  }

  @override
  void dispose() {
    searcher.removeListener(_changed);
    searcher.dispose();
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final file = path;
    final ready = controller.isReady && count > 0;
    return Padding(
      padding: const EdgeInsets.all(NexSpacing.sm),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: choose,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(l.pdfChoose),
            ),
          ),
          if (failed) Text(l.pdfFailed, style: TextStyle(color: scheme.error)),
          if (file == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(NexSpacing.lg),
                  child: Text(l.pdfChooseHint),
                ),
              ),
            )
          else ...[
            TextField(
              key: const ValueKey('pdf-search'),
              controller: query,
              decoration: InputDecoration(
                labelText: l.pdfSearch,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.clearSelection,
                        onPressed: () {
                          query.clear();
                          searcher.resetTextSearch();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (text) {
                searcher.startTextSearch(text);
                setState(() {});
              },
              onSubmitted: (text) =>
                  searcher.startTextSearch(text, searchImmediately: true),
            ),
            if (query.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: NexSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        searcher.isSearching
                            ? l.moduleLoading
                            : searcher.matches.isEmpty
                            ? l.pdfSearchEmpty
                            : l.pdfMatch(
                                desktopDigits(
                                  context,
                                  (searcher.currentIndex ?? 0) + 1,
                                ),
                                desktopDigits(context, searcher.matches.length),
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l.previousPage,
                      onPressed: !searcher.hasMatches
                          ? null
                          : () => searcher.goToPrevMatch(),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      tooltip: l.nextPage,
                      onPressed: !searcher.hasMatches
                          ? null
                          : () => searcher.goToNextMatch(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: NexSpacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NexRadius.md),
                child: PdfViewer.file(
                  file,
                  key: ValueKey((file, revision)),
                  controller: controller,
                  passwordProvider: password,
                  params: PdfViewerParams(
                    backgroundColor: scheme.surfaceContainerLow,
                    pageDropShadow: null,
                    pageAnchor: PdfPageAnchor.center,
                    underflowAnchor: PdfPageAnchor.center,
                    scrollHorizontallyByMouseWheel: true,
                    maxImageBytesCachedOnMemory: 32 * 1024 * 1024,
                    // Localized Material copy/selection controls are supplied by the
                    // pre-migration pdfrx line compatible with Flutter 3.44.8.
                    forceEnableTextSemantics: true,
                    matchTextColor: scheme.secondaryContainer.withValues(
                      alpha: .65,
                    ),
                    activeMatchTextColor: scheme.tertiaryContainer.withValues(
                      alpha: .8,
                    ),
                    pagePaintCallbacks: [searcher.pageTextMatchPaintCallback],
                    layoutPages: (pages, params) {
                      final height =
                          pages.fold(0.0, (h, p) => math.max(h, p.height)) +
                          params.margin * 2;
                      var x = params.margin;
                      final boxes = <Rect>[];
                      // Mirror the document's page sequence with the interface.
                      final rtl =
                          Directionality.of(context) == TextDirection.rtl;
                      final order = rtl ? pages.reversed : pages;
                      for (final p in order) {
                        boxes.add(
                          Rect.fromLTWH(
                            x,
                            (height - p.height) / 2,
                            p.width,
                            p.height,
                          ),
                        );
                        x += p.width + params.margin;
                      }
                      return PdfPageLayout(
                        pageLayouts: rtl ? boxes.reversed.toList() : boxes,
                        documentSize: Size(x, height),
                      );
                    },
                    onViewerReady: (document, _) {
                      if (!mounted) return;
                      setState(() {
                        count = document.pages.length;
                        failed = false;
                      });
                      if (query.text.isNotEmpty)
                        searcher.startTextSearch(query.text);
                    },
                    onPageChanged: (value) {
                      if (mounted && value != null)
                        setState(() => page = value);
                    },
                    loadingBannerBuilder: (_, _, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorBannerBuilder: (_, _, _, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(NexSpacing.md),
                            child: Text(l.pdfFailed),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              count = 0;
                              revision++;
                            }),
                            child: Text(l.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: NexSpacing.xs),
            Wrap(
              spacing: NexSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('pdf-previous'),
                  tooltip: l.previousPage,
                  onPressed: ready && page > 1 ? () => turn(page - 1) : null,
                  icon: const Icon(Icons.navigate_before),
                ),
                TextButton(
                  key: const ValueKey('pdf-page-picker'),
                  onPressed: ready ? jump : null,
                  child: Text(
                    l.pdfPage(
                      desktopDigits(context, page),
                      desktopDigits(context, count),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('pdf-next'),
                  tooltip: l.nextPage,
                  onPressed: ready && page < count
                      ? () => turn(page + 1)
                      : null,
                  icon: const Icon(Icons.navigate_next),
                ),
                IconButton(
                  tooltip: l.pdfZoom,
                  onPressed: ready
                      ? () => controller.zoomUp(duration: duration)
                      : null,
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  tooltip: l.pdfResetZoom,
                  onPressed: ready ? () => turn(page) : null,
                  icon: const Icon(Icons.zoom_out_map),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Replaces a tiny imprecise slider with direct, virtualized page numbers.
class DesktopPdfPagePicker extends StatefulWidget {
  const DesktopPdfPagePicker({
    super.key,
    required this.count,
    required this.current,
  });
  final int count, current;
  @override
  State<DesktopPdfPagePicker> createState() => _DesktopPdfPagePickerState();
}

class _DesktopPdfPagePickerState extends State<DesktopPdfPagePicker> {
  ScrollController? scroll;
  @override
  void dispose() {
    scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.pdfJump),
      content: SizedBox(
        width: 480,
        height: 360,
        child: LayoutBuilder(
          builder: (context, box) {
            final columns =
                (box.maxWidth /
                        (64 * MediaQuery.textScalerOf(context).scale(1)))
                    .floor()
                    .clamp(1, 8);
            return GridView.builder(
              controller: scroll ??= ScrollController(
                initialScrollOffset: ((widget.current - 1) ~/ columns) * 64.0,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 64,
              ),
              itemCount: widget.count,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.all(NexSpacing.xs),
                child: Semantics(
                  selected: i + 1 == widget.current,
                  child: OutlinedButton(
                    style: i + 1 == widget.current
                        ? OutlinedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          )
                        : null,
                    onPressed: () => Navigator.pop(context, i + 1),
                    child: Text(desktopDigits(context, i + 1)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.moduleCancel),
        ),
      ],
    );
  }
}

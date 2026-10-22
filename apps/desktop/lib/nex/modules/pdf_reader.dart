import 'dart:async';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nex_ui/nex_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/desktop_format.dart';
import '../features_state.dart';

bool desktopPdfWebLink(Uri uri) =>
    const {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty;

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
  var controller = PdfViewerController();
  PdfTextSearcher? searcher;
  final query = TextEditingController();
  final searchFocus = FocusNode();
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
      searcher?.removeListener(_changed);
      searcher?.dispose();
      searcher = null;
      setState(() {
        path = files.first.path;
        // A retiring keyed viewer detaches its controller on disposal. Give
        // the replacement its own controller so it cannot be detached by it.
        controller = PdfViewerController();
        page = 1;
        count = 0;
        failed = false;
        revision++;
      });
      query.clear();
      searcher?.resetTextSearch();
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
    searcher?.removeListener(_changed);
    searcher?.dispose();
    query.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final file = path;
    final ready = controller.isReady && count > 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            unawaited(choose()),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.keyG, control: true): () {
          if (ready) unawaited(jump());
        },
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(NexSpacing.sm),
          child: Column(
            children: [
              if (file != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: choose,
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(l.pdfChoose),
                  ),
                ),
              if (file != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexSpacing.sm,
                    vertical: NexSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        color: scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: NexSpacing.sm),
                      Expanded(
                        child: Tooltip(
                          message: file,
                          child: Text(
                            file.split(RegExp(r'[\\/]')).last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (failed)
                Text(l.pdfFailed, style: TextStyle(color: scheme.error)),
              if (file == null)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Card(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NexEmptyState(
                              icon: Icons.picture_as_pdf_outlined,
                              message: l.pdfChooseHint,
                              action: FilledButton.tonalIcon(
                                onPressed: choose,
                                icon: const Icon(Icons.file_open_outlined),
                                label: Text(l.pdfChoose),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                TextField(
                  key: const ValueKey('pdf-search'),
                  focusNode: searchFocus,
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
                              searcher?.resetTextSearch();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (text) {
                    searcher?.startTextSearch(text);
                    setState(() {});
                  },
                  onSubmitted: (text) =>
                      searcher?.startTextSearch(text, searchImmediately: true),
                ),
                if (query.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: NexSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (searcher?.isSearching ?? false)
                                ? l.moduleLoading
                                : (searcher?.matches.isEmpty ?? true)
                                ? l.pdfSearchEmpty
                                : l.pdfMatch(
                                    desktopDigits(
                                      context,
                                      (searcher?.currentIndex ?? 0) + 1,
                                    ),
                                    desktopDigits(
                                      context,
                                      (searcher?.matches.length ?? 0),
                                    ),
                                  ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: l.previousPage,
                          onPressed: !(searcher?.hasMatches ?? false)
                              ? null
                              : () => searcher?.goToPrevMatch(),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: l.nextPage,
                          onPressed: !(searcher?.hasMatches ?? false)
                              ? null
                              : () => searcher?.goToNextMatch(),
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
                        linkHandlerParams: PdfLinkHandlerParams(
                          linkColor: scheme.primary.withValues(alpha: .12),
                          onLinkTap: (link) {
                            if (link.dest != null) {
                              unawaited(
                                controller.goToDest(
                                  link.dest,
                                  duration: duration,
                                ),
                              );
                            } else if (link.url != null &&
                                desktopPdfWebLink(link.url!)) {
                              final native = NexPanelScope.maybeOf(
                                context,
                              )?.native;
                              if (native != null) {
                                unawaited(
                                  widget.features.guard(
                                    () => native.launch(link.url.toString()),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        matchTextColor: scheme.secondaryContainer.withValues(
                          alpha: .65,
                        ),
                        activeMatchTextColor: scheme.tertiaryContainer
                            .withValues(alpha: .8),
                        pagePaintCallbacks: [
                          if (searcher != null)
                            searcher!.pageTextMatchPaintCallback,
                        ],
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
                        onViewerReady: (document, activeController) {
                          if (!mounted ||
                              !identical(activeController, controller)) {
                            return;
                          }
                          searcher?.removeListener(_changed);
                          searcher?.dispose();
                          // pdfrx 2.4 requires an attached, ready controller here.
                          searcher = PdfTextSearcher(controller)
                            ..addListener(_changed);
                          setState(() {
                            count = document.pages.length;
                            failed = false;
                          });
                          if (query.text.isNotEmpty) {
                            searcher?.startTextSearch(query.text);
                          }
                        },
                        onPageChanged: (value) {
                          if (mounted && value != null) {
                            setState(() => page = value);
                          }
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
                                  searcher?.removeListener(_changed);
                                  searcher?.dispose();
                                  searcher = null;
                                  controller = PdfViewerController();
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
                      onPressed: ready && page > 1
                          ? () => turn(page - 1)
                          : null,
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
        ),
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

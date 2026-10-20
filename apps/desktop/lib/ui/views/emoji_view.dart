import '../../l10n/app_localizations.dart';
import '../../l10n/utility_strings.dart';
import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../../core/data.dart';
import '../flyout.dart';
import '../widgets.dart';

/// Emoji picker: search, categories, recents, magnify-on-hover grid.
class EmojiView extends StatefulWidget {
  const EmojiView({super.key});

  @override
  State<EmojiView> createState() => _EmojiViewState();
}

class _EmojiViewState extends State<EmojiView> {
  final _search = TextEditingController();
  String cat = '🕘';

  bool _catInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_catInit) {
      _catInit = true;
      cat = LiquidScope.panelOf(context).S.recentEmoji.isEmpty ? '😀' : '🕘';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _list {
    final c = LiquidScope.panelOf(context);
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      return kAllEmoji
          .where((e) => e.keywords.contains(q))
          .map((e) => e.emoji)
          .toList();
    }
    if (cat == '🕘') return c.S.recentEmoji;
    return kAllEmoji
        .where((e) => e.category == cat)
        .map((e) => e.emoji)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    final list = _list;
    return Panel(
      children: [
        Row(
          children: [
            PanelBackButton(onTap: () => _backToMore(c), size: 34),
            const SizedBox(width: 4),
            Expanded(
              child: Field(
                controller: _search,
                hint: utilityLabel(context, 'utility12'),
                autofocusDelayed: true,
                onChanged: (_) => setState(() {}),
                onEnter: (_) {},
              ),
            ),
          ],
        ),
        Row(
          children: [
            for (final key in ['🕘', ...kEmojiCategories.keys])
              _CatButton(
                emoji: key,
                on: _search.text.isEmpty && cat == key,
                onTap: () => setState(() {
                  cat = key;
                  _search.clear();
                }),
              ),
          ],
        ),
        SizedBox(
          height: 220,
          child: list.isEmpty
              ? Empty(
                  _search.text.isNotEmpty
                      ? AppLocalizations.of(context)!.noEmojiFound
                      : AppLocalizations.of(context)!.nothingYet,
                )
              : Stack(
                  children: [
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: GridView.count(
                        crossAxisCount: 7,
                        childAspectRatio: 36 / 36,
                        padding: const EdgeInsets.only(bottom: 10),
                        children: [
                          for (final e in list) _EmojiButton(emoji: e),
                        ],
                      ),
                    ),
                    // Audit defect 10: the last row dissolved into a hard
                    // cut; the fade now shows the grid continues.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 24,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [p.liquid.withValues(alpha: 0), p.liquid],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _backToMore(PanelController c) {
    c.backToTools();
  }
}

class _CatButton extends StatefulWidget {
  const _CatButton({
    required this.emoji,
    required this.on,
    required this.onTap,
  });

  final String emoji;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_CatButton> createState() => _CatButtonState();
}

class _CatButtonState extends State<_CatButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: DesktopAction(
          label:
              '${AppLocalizations.of(context)!.emojiCategory} ${widget.emoji}',
          selected: widget.on,
          excludeSemantics: true,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: (widget.on || _hover)
                  ? (widget.on ? p.soft2 : p.soft)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Opacity(
                // Audit defect 10: half-strength icons failed contrast.
                opacity: (widget.on || _hover) ? 1 : .72,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI Emoji',
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  const _EmojiButton({required this.emoji});

  final String emoji;

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    final c = LiquidScope.panelOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DesktopAction(
        label: widget.emoji,
        excludeSemantics: true,
        onTap: () {
          c.pushRecentEmoji(widget.emoji);
          c.deliver(widget.emoji);
        },
        child: AnimatedScale(
          scale: _hover ? 1.22 : 1,
          duration: const Duration(milliseconds: 350),
          curve: kPop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _hover ? p.soft2 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            height: 36,
            child: Center(
              child: Text(
                widget.emoji,
                style: const TextStyle(
                  fontFamily: 'Segoe UI Emoji',
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

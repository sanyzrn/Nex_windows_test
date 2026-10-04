import '../../l10n/utility_strings.dart';

import 'package:flutter/material.dart';

import '../../core/controller.dart';
import '../../core/data.dart';
import '../../core/registry.dart';
import '../flyout.dart';
import '../svg_icon.dart';
import '../widgets.dart';


// ================= Folders =================

class FoldersView extends StatelessWidget {
  const FoldersView({super.key});

  @override
  Widget build(BuildContext context) {
    final (p, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(title: utilityLabel(context, 'utility33'), onBack: () => _back(c)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in kFolders)
              SizedBox(
                width: 84,
                child: _FolderTile(
                  name: f[0],
                  target: f[1],
                  onTap: () {
                    c.close();
                    c.native.launch(f[1]);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.backToTools();
  }
}

class _FolderTile extends StatefulWidget {
  const _FolderTile({
    required this.name,
    required this.target,
    required this.onTap,
  });

  final String name;
  final String target;
  final VoidCallback onTap;

  @override
  State<_FolderTile> createState() => _FolderTileState();
}

class _FolderTileState extends State<_FolderTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = LiquidScope.paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: kPop,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hover ? p.soft2 : p.soft,
            borderRadius: BorderRadius.circular(_hover ? 18 : 14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: Center(
                  child: SvgIcon(
                    kTools['folders']!.svg!,
                    size: 22,
                    strokeWidth: 1.7,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                utilityLabelForText(context, widget.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.fontFamily,
                  fontFamilyFallback: const ['Segoe UI'],
                  fontSize: 11,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= Snippets =================

class SnippetsView extends StatefulWidget {
  const SnippetsView({super.key});

  @override
  State<SnippetsView> createState() => _SnippetsViewState();
}

class _SnippetsViewState extends State<SnippetsView> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (_, c, _) = LiquidScope.of(context);
    return Panel(
      children: [
        Head(
          onBack: () => _back(c),
          trailing: Hint(utilityLabel(context, 'utility27')),
        ),
        Field(
          controller: _input,
          hint: utilityLabel(context, 'utility35'),
          autofocusDelayed: true,
          onSubmit: (v) {
            if (v.trim().isNotEmpty) {
              c.S.snippets.insert(0, v.trim());
              _input.clear();
              c.save();
              c.refresh();
            }
          },
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: c.S.snippets.isEmpty
              ? Empty(utilityLabel(context, 'utility28'))
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < c.S.snippets.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ItemRow(
                            onTap: () => c.deliver(c.S.snippets[i]),
                            trailing: ItemAction(
                              child: const Text('×'),
                              onTap: () {
                                c.S.snippets.removeAt(i);
                                c.save();
                                c.refresh();
                              },
                            ),
                            child: Text(
                              c.S.snippets[i]
                                          .replaceAll(RegExp(r'\s+'), ' ')
                                          .length >
                                      100
                                  ? c.S.snippets[i]
                                        .replaceAll(RegExp(r'\s+'), ' ')
                                        .substring(0, 100)
                                  : c.S.snippets[i].replaceAll(
                                      RegExp(r'\s+'),
                                      ' ',
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  void _back(PanelController c) {
    c.backToTools();
  }
}


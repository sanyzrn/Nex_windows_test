// Part of the PanelController split (see controller.dart). Members
// below are spliced into the class body; do not import this file directly.
part of 'controller.dart';

/// Clipboard history operations and the dock/More widget manager.

/// Clipboard history operations and the dock/More widget manager.
mixin PanelClipboardOps on PanelStateBase {
  // ---- clipboard history ops ----
  @override
  void deliver(String text) {
    if (S.paste) {
      close();
      unawaited(native.pasteIntoPrevious(text).catchError((_) {}));
    } else {
      copy(text);
    }
  }

  @override
  void copy(String text, [String? msg]) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    toast(msg ?? 'Copied');
  }

  void togglePinClip(ClipEntry c) {
    clipboard.togglePin(c);
    S.pins = clipboard.pinnedTexts;
    save();
  }

  void removeClip(ClipEntry c) {
    clipboard.remove(c);
    S.pins = clipboard.pinnedTexts;
    save();
  }

  void copyImage(ClipImage img) {
    unawaited(
      native.setClipboardImage(img.w, img.h, img.rgba).catchError((_) {}),
    );
    toast('Image copied');
  }

  // ---- widget manager (drag & drop) ----
  @override
  void moveWidget(String id, String list, int idx, {bool withHidden = false}) {
    if (list == 'more' && (kTools[id]?.dockOnly ?? false)) return;
    final wasHidden = S.hidden.contains(id);
    final target = list == 'dock' ? S.dock! : S.more!;
    final visible = target
        .where((x) => x != id && (withHidden || !S.hidden.contains(x)))
        .toList();
    final anchor = idx < visible.length ? visible[idx] : null;
    S.dock = S.dock!.where((x) => x != id).toList();
    S.more = S.more!.where((x) => x != id).toList();
    final dest = list == 'dock' ? S.dock! : S.more!;
    var at = anchor != null ? dest.indexOf(anchor) : dest.length;
    if (at < 0) at = dest.length;
    dest.insert(at, id);
    if (wasHidden && !withHidden) {
      S.hidden = S.hidden.where((x) => x != id).toList();
    }
    save();
    notifyListeners();
    if (list == 'dock' && panel == 'more') {
      toast(
        message('{value} → dock', {
          'value': utilityForLocale(S.language, ToolInfo.of(id).name),
        }),
      );
    }
  }

  void toggleHidden(String id) {
    if (S.hidden.contains(id)) {
      S.hidden = S.hidden.where((x) => x != id).toList();
    } else {
      S.hidden = [...S.hidden, id];
    }
    save();
    notifyListeners();
  }

  void removeApp(String id) {
    S.hidden.remove(id);
    S.apps = S.apps.where((x) => x.id != id).toList();
    S.dock = S.dock!.where((x) => x != id).toList();
    S.more = S.more!.where((x) => x != id).toList();
    ToolInfo.controllerApps = S.apps;
    save();
    notifyListeners();
  }
}

// Part of the PanelController split (see controller.dart). Members
// below are spliced into the class body; do not import this file directly.
part of 'controller.dart';

/// Native channel wiring: connects WinNativeHost callbacks to controller
/// members. Split from the lifecycle mixin to keep files under 500 lines.
mixin PanelWiring on PanelStateBase {
  @override
  void _wireNative() {
    if (native is WinNativeHost) {
      (native as WinNativeHost).events = NativeEvents(
        onPlacement: (map) async {
          placement = Placement.fromMap(map);
          S.edge = placement!.onLeft ? 'left' : 'right';
          S.monitor = (map['monitor'] as num?)?.toInt() ?? S.monitor;
          try {
            screens = await native.screens();
          } catch (_) {}
          if (!_disposed) notifyListeners();
        },
        onClipText: clip,
        onClipImage: (img) => addClipImage(img),
        onTray: onTray,
        onBlur: blur,
        onFilesDropped: onFilesDropped,
        onPickedColor: onPickedColor,
        onPickedCustomColor: onPickedCustomColor,
        onPickedApp: (path) => appAdded(path: path),
        onPickerState: setPickerActive,
        onAppIcon: iconFor,
      );
    }
  }
}

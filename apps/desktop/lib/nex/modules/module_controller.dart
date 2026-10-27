import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'private_session.dart';
import 'vault_store.dart';

enum DesktopModule { pdf, vault, portrait, cycle }

/// Device-only switches: never imported from another device's backup.
class DesktopModules extends ChangeNotifier {
  DesktopModules({DesktopPrivateSession? privateSession, VaultStore? vault})
    : privateSession = privateSession ?? DesktopPrivateSession(),
      vault = vault ?? VaultStore();
  final DesktopPrivateSession privateSession;
  final VaultStore vault;
  SharedPreferences? _prefs;
  Future<void>? _loading;
  bool _disposed = false;
  bool get ready => _prefs != null;
  Future<void> initialize() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });
  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_disposed) notifyListeners();
  }

  /// The modules this build offers. Cycle is a phone companion and is paused
  /// on the desktop: its code, its screens and anything already stored stay
  /// whole, and it comes back by adding it here. The room it leaves is for
  /// tools made for Windows.
  static const offered = {
    DesktopModule.pdf,
    DesktopModule.vault,
    DesktopModule.portrait,
  };
  static bool isOffered(DesktopModule module) => offered.contains(module);

  bool enabled(DesktopModule module) =>
      isOffered(module) &&
      (_prefs?.getBool('windows.module.${module.name}') ?? false);
  Future<void> setEnabled(DesktopModule module, bool value) async {
    await initialize();
    if (!await _prefs!.setBool('windows.module.${module.name}', value)) {
      throw StateError('Could not save module switch');
    }
    if (!value &&
        (module == DesktopModule.vault || module == DesktopModule.cycle)) {
      privateSession.lock();
    }
    if (!_disposed) notifyListeners();
  }

  int get typicalCycle =>
      (_prefs?.getInt('cycle.typical_cycle') ?? 28).clamp(15, 60);
  int get typicalPeriod =>
      (_prefs?.getInt('cycle.typical_period') ?? 5).clamp(1, 15);
  Future<void> setTypical({required int cycle, required int period}) async {
    await initialize();
    if (cycle < 15 || cycle > 60 || period < 1 || period > 15) {
      throw ArgumentError('Invalid typical lengths');
    }
    if (!await _prefs!.setInt('cycle.typical_cycle', cycle) ||
        !await _prefs!.setInt('cycle.typical_period', period)) {
      throw StateError('Could not save cycle preferences');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> close() async {
    privateSession.lock();
    dispose();
    await vault.flushed;
  }

  @override
  void dispose() {
    _disposed = true;
    privateSession.dispose();
    super.dispose();
  }
}

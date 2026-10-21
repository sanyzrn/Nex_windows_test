import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One process-only unlock for all private tools. Activity never revives an
/// expired unlock. Backgrounding hides content without removing the grace.
class DesktopPrivateSession extends ChangeNotifier {
  DesktopPrivateSession({
    DateTime Function()? clock,
    Future<bool> Function(String)? authenticate,
  }) : clock = clock ?? DateTime.now,
       authenticate = authenticate ?? _verify;
  static const grace = Duration(minutes: 2);
  static const channel = MethodChannel('rp/native');
  final DateTime Function() clock;
  final Future<bool> Function(String) authenticate;
  DateTime? _until;
  Timer? _timer;
  Future<bool>? _unlocking;
  bool _disposed = false;
  int _generation = 0;
  bool get isOpen => _until != null && clock().isBefore(_until!);
  Duration get remaining =>
      isOpen ? _until!.difference(clock()) : Duration.zero;

  static Future<bool> _verify(String reason) async =>
      await channel.invokeMethod<bool>('privateVerify', {'reason': reason}) ??
      false;

  Future<bool> unlock(String reason) {
    if (isOpen) {
      touch();
      return Future.value(true);
    }
    return _unlocking ??= _unlock(reason).whenComplete(() => _unlocking = null);
  }

  Future<bool> _unlock(String reason) async {
    final generation = _generation;
    final accepted = await authenticate(reason);
    if (!accepted || _disposed || generation != _generation) return false;
    _until = clock().add(grace);
    _schedule();
    notifyListeners();
    return true;
  }

  void touch() {
    if (!isOpen) return;
    _until = clock().add(grace);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(remaining, () {
      if (!isOpen) {
        lock();
      } else {
        _schedule();
      }
    });
  }

  void lock() {
    _generation++;
    _until = null;
    _timer?.cancel();
    if (!_disposed) notifyListeners();
  }

  /// The native writer excludes secrets from Nex/Windows clipboard history,
  /// and clears only its own clipboard sequence after 30 seconds.
  Future<void> copy(String value) async {
    if (!isOpen) throw StateError('Private session is locked');
    touch();
    if (await channel.invokeMethod<bool>('privateClipboard', {'text': value}) !=
        true) {
      throw StateError('Private clipboard unavailable');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _until = null;
    _timer?.cancel();
    super.dispose();
  }
}

// Part of the PanelController split (see controller.dart). Members
// below are spliced into the class body; do not import this file directly.
part of 'controller.dart';

/// Timer and stopwatch engines, kept alive across panel closes.
mixin PanelTimers on PanelStateBase {
  // ---- timer / stopwatch (kept alive across panel closes) ----
  int tTotal = 300;
  int tLeft = 300;
  Timer? tRun;
  DateTime Function() timerNow = DateTime.now;
  DateTime? _timerDeadline;

  int _remainingTimerSeconds() => _timerDeadline == null
      ? tLeft
      : ((_timerDeadline!.difference(timerNow()).inMilliseconds + 999) ~/ 1000)
            .clamp(0, tTotal);

  void timerPreset(int minutes) {
    tRun?.cancel();
    tRun = null;
    _timerDeadline = null;
    tTotal = tLeft = minutes * 60;
    notifyListeners();
  }

  void timerToggle() {
    if (tRun != null) {
      tLeft = _remainingTimerSeconds();
      tRun?.cancel();
      tRun = null;
      _timerDeadline = null;
    } else {
      if (tLeft == 0) tLeft = tTotal;
      _timerDeadline = timerNow().add(Duration(seconds: tLeft));
      tRun = Timer.periodic(const Duration(seconds: 1), (_) {
        // A sleeping or suspended Windows process misses ticks. The deadline
        // remains authoritative when the event loop resumes.
        tLeft = _remainingTimerSeconds();
        if (tLeft <= 0) {
          tRun?.cancel();
          tRun = null;
          _timerDeadline = null;
          tLeft = 0;
          unawaited(native.beep().catchError((_) {}));
          sticky = true;
          open();
          _later(const Duration(milliseconds: 140), () => openWidget('timer'));
          toast('⏰ Time is up!');
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void timerReset() {
    tRun?.cancel();
    tRun = null;
    tLeft = tTotal;
    _timerDeadline = null;
    notifyListeners();
  }

  double swStart = 0;
  int swAcc = 0;
  Timer? swTimer;
  List<int> swLaps = [];
  final ValueNotifier<String> swDisplay = ValueNotifier('00:00.00');

  int get swNow =>
      swAcc +
      (swTimer != null
          ? (DateTime.now().millisecondsSinceEpoch - swStart).round()
          : 0);

  void swToggle() {
    if (swTimer != null) {
      swAcc = swNow;
      swTimer?.cancel();
      swTimer = null;
      swDisplay.value = fmtSwValue(swAcc);
    } else {
      swStart = DateTime.now().millisecondsSinceEpoch.toDouble();
      swTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        swDisplay.value = fmtSwValue(swNow);
      });
    }
    notifyListeners();
  }

  void swLapOrReset() {
    if (swTimer != null) {
      swLaps.insert(0, swNow);
    } else {
      swAcc = 0;
      swLaps = [];
      swDisplay.value = fmtSwValue(0);
    }
    notifyListeners();
  }

  static String fmtSwValue(int ms) =>
      '${(ms ~/ 60000).toString().padLeft(2, '0')}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${((ms ~/ 10) % 100).toString().padLeft(2, '0')}';

  /// Cancels the timer engines; called from [PanelStateBase.dispose] —
  /// deliberately no super.dispose() here, that would recurse.
  @override
  void disposeTimers() {
    tRun?.cancel();
    swTimer?.cancel();
    swDisplay.dispose();
  }
}

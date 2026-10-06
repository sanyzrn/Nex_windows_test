// Part of the PanelController split (see controller.dart). Members
// below are spliced into the class body; do not import this file directly.
part of 'controller.dart';

/// Timer and stopwatch engines, kept alive across panel closes.
mixin PanelTimers on PanelStateBase {
  // ---- timer / stopwatch (kept alive across panel closes) ----
  int tTotal = 300;
  int tLeft = 300;
  Timer? tRun;

  void timerPreset(int minutes) {
    tRun?.cancel();
    tRun = null;
    tTotal = tLeft = minutes * 60;
    notifyListeners();
  }

  void timerToggle() {
    if (tRun != null) {
      tRun?.cancel();
      tRun = null;
    } else {
      if (tLeft == 0) tLeft = tTotal;
      tRun = Timer.periodic(const Duration(seconds: 1), (_) {
        tLeft--;
        if (tLeft <= 0) {
          tRun?.cancel();
          tRun = null;
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
  void disposeTimers() {
    tRun?.cancel();
    swTimer?.cancel();
    swDisplay.dispose();
  }
}

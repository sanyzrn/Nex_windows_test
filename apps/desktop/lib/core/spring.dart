import 'dart:math' as math;

/// The liquid engine's spring, ported 1:1 from the original project
/// (semi-implicit Euler integration with fixed 4 ms substeps).
///
/// [v] is the current value, [t] the target, [vel] the velocity.
/// [k] is stiffness, [d] is damping. The exact constants used by the
/// original UI are kept so every animation feels identical:
///
///  * tab slide   : k = 320, d = 38   (critically damped: no overshoot)
///  * flyout grow : k = 340, d = 24   (underdamped: the "pour" bounce)
///  * flyout y    : k = 380, d = 30
///  * pill y      : k = 420, d = 26
///  * pill scale  : k = 380, d = 22
///  * icon in/out : k = 380, d = 25
///  * icon magnify: k = 500, d = 30
///  * icon press  : k = 700, d = 28
class Spring {
  double v;
  double t;
  double vel = 0;
  final double k;
  final double d;

  Spring(this.v, [this.k = 420, this.d = 34]) : t = v;

  /// Advances the spring by [dt] seconds (already clamped to 1/30 s
  /// by the frame loop) and returns the new value.
  double step(double dt) {
    final n = math.max(1, (dt / 0.004).ceil());
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      vel += (-k * (v - t) - d * vel) * h;
      v += vel * h;
    }
    return v;
  }
}

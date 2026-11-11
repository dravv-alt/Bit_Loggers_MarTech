import 'scale_tick_sound_stub.dart'
    if (dart.library.js_interop) 'scale_tick_sound_web.dart';

/// Cross-platform tactile weight-scale notch click audio facade.
class V2ScaleTickAudio {
  static void warmUp() => warmUpScaleAudio();

  static void playTick({
    bool isMajor = false,
    bool isCeiling = false,
    bool isBump = false,
  }) {
    playScaleTickSound(
      isMajor: isMajor,
      isCeiling: isCeiling,
      isBump: isBump,
    );
  }
}


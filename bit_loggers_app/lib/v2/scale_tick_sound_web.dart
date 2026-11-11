import 'dart:js_interop';

@JS('__cgWarmupScaleTick')
external void _warmUpJs();

@JS('__cgPlayScaleTick')
external void _playTickJs(JSString kind);

void warmUpScaleAudio() {
  try {
    _warmUpJs();
  } catch (_) {}
}

void playScaleTickSound({
  bool isMajor = false,
  bool isCeiling = false,
  bool isBump = false,
}) {
  try {
    final kind = isBump
        ? 'bump'
        : isCeiling
            ? 'ceiling'
            : isMajor
                ? 'major'
                : 'minor';
    _playTickJs(kind.toJS);
  } catch (_) {}
}


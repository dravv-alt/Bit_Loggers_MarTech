import 'package:flutter/services.dart';

void warmUpScaleAudio() {}

void playScaleTickSound({
  bool isMajor = false,
  bool isCeiling = false,
  bool isBump = false,
}) {
  SystemSound.play(SystemSoundType.click);
}


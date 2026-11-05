import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_loggers_app/main.dart';

void main() {
  testWidgets('Bit Loggers App smoke test', (WidgetTester tester) async {
    // Set phone viewport size (400x900 pt)
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const BitLoggersApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('campaigngrid'), findsWidgets);
  });
}

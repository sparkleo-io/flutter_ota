// App-specific widget smoke test.
//
// The full app bootstraps GetX dependency injection and platform permission
// plugins in `main()`, which are not available in the widget-test harness. This
// test instead exercises a self-contained UI component from the example so the
// example package has a real, passing test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ota_new_protocol/common/custom_button/primary_action_button.dart';

void main() {
  testWidgets('PrimaryActionButton renders its label and fires onTap', (
    WidgetTester tester,
  ) async {
    int taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PrimaryActionButton(label: 'Start OTA', onTap: () => taps++),
          ),
        ),
      ),
    );

    expect(find.text('Start OTA'), findsOneWidget);

    await tester.tap(find.text('Start OTA'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('PrimaryActionButton is inert when onTap is null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PrimaryActionButton(label: 'Disabled', onTap: null),
          ),
        ),
      ),
    );

    expect(find.text('Disabled'), findsOneWidget);
    // Tapping a disabled button must not throw.
    await tester.tap(find.text('Disabled'));
    await tester.pump();
  });
}

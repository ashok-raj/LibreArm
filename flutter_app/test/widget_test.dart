import 'package:flutter_test/flutter_test.dart';

import 'package:libre_arm/main.dart';

void main() {
  testWidgets('LibreArm app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LibreArmApp());

    // Verify that the app title is displayed
    expect(find.text('LibreArm'), findsOneWidget);
    expect(find.text('Blood Pressure'), findsOneWidget);
  });
}

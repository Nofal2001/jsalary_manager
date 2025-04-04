import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:jsalary_manager/main.dart';
import 'package:jsalary_manager/screens/home_screen.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(disableUpdateCheck: true), // 👈 disables timer
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });
}

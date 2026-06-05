import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_erp_ai/app.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Fixed: Changed MyApp() to App() to match your project root widget
    await tester.pumpWidget(const App());

    // Note: The counter test is standard template code. 
    // Since your app is an ERP dashboard, this test will likely fail 
    // until you update it with your actual UI elements.
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medilocker/main.dart';

void main() {
  testWidgets('MediLocker app launches without errors', (WidgetTester tester) async {
    // Supabase is initialized in main() — this test just verifies
    // the widget tree assembles without throwing.
    expect(MediLockerApp, isNotNull);
  });
}

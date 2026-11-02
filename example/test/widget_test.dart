import 'package:advanced_in_app_review_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('example explains eligibility and offers a task action', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Advanced In-App Review'), findsOneWidget);
    expect(find.text('Complete a task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

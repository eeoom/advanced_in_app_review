import 'dart:io';

import 'package:advanced_in_app_review/advanced_in_app_review.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native review channel resolves the real host window', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Review integration test'))),
    );
    await tester.pumpAndSettle();
    final review = AdvancedInAppReview()
      ..setMinLaunchTimes(0)
      ..setMinDaysAfterInstall(0)
      ..setMinDaysBeforeRemind(0)
      ..setMinSecondsBeforeShowDialog(0);
    addTearDown(review.dispose);
    await review.monitor();
    if (Platform.isIOS) {
      expect(await review.isAvailable(), isTrue);
      await expectLater(
        review.openStoreListing(appStoreId: 'invalid'),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'invalid_store_id',
          ),
        ),
      );
    }
    final result = await review.requestReviewIfEligible();
    if (Platform.isIOS) {
      // No assertion about visible UI: the store owns presentation and quotas.
      expect(
        result.status,
        ReviewRequestStatus.requested,
        reason: result.toString(),
      );
    } else {
      // A sideloaded Android build may not be eligible for Google Play review.
      expect(
        result.status,
        isIn([
          ReviewRequestStatus.requested,
          ReviewRequestStatus.notAvailable,
          ReviewRequestStatus.failed,
        ]),
        reason: result.toString(),
      );
    }
  });
}

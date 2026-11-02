import 'package:advanced_in_app_review/src/review_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final platform = MethodChannelReviewPlatform();
  tearDown(
    () => messenger.setMockMethodCallHandler(
      MethodChannelReviewPlatform.channel,
      null,
    ),
  );

  test(
    'request uses the owned native channel without availability preflight',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(MethodChannelReviewPlatform.channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      await platform.requestReview();
      expect(calls.map((call) => call.method), ['requestReview']);
    },
  );

  test('store ID reaches native code', () async {
    messenger.setMockMethodCallHandler(MethodChannelReviewPlatform.channel, (
      call,
    ) async {
      expect(call.method, 'openStoreListing');
      expect(call.arguments, {'appStoreId': '123456789'});
      return null;
    });
    await platform.openStoreListing(appStoreId: '123456789');
  });

  test('availability handles a missing implementation', () async {
    expect(await platform.isAvailable(), isFalse);
  });

  test('native errors propagate without claiming success', () async {
    messenger.setMockMethodCallHandler(MethodChannelReviewPlatform.channel, (
      _,
    ) async {
      throw PlatformException(code: 'no_active_window');
    });
    await expectLater(
      platform.requestReview(),
      throwsA(isA<PlatformException>()),
    );
  });
}

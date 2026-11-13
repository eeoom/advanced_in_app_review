import 'package:flutter/services.dart';

/// Native operations, separated so eligibility can be tested without a store.
abstract class ReviewPlatform {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing({String? appStoreId});
}

class MethodChannelReviewPlatform implements ReviewPlatform {
  static const channel = MethodChannel('advanced_in_app_review');

  @override
  Future<bool> isAvailable() async {
    try {
      return await channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> requestReview() => channel.invokeMethod<void>('requestReview');

  @override
  Future<void> openStoreListing({String? appStoreId}) => channel
      .invokeMethod<void>('openStoreListing', {'appStoreId': appStoreId});
}

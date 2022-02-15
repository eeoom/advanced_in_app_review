
import 'dart:async';

import 'package:advanced_in_app_review/InAppReviewManager.dart';
import 'package:flutter/services.dart';

class AdvancedInAppReview {
  static const MethodChannel _channel = MethodChannel('advanced_in_app_review');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  void monitor() {
    InAppReviewManager().monitor();
  }

  AdvancedInAppReview setMinLaunchTimes(int launchTimes) {
    InAppReviewManager().setMinLaunchTimes(launchTimes);
    return this;
  }

  AdvancedInAppReview setMinDaysAfterInstall(int days) {
    InAppReviewManager().setMinDaysAfterInstall(days);
    return this;
  }

  AdvancedInAppReview setMinDaysBeforeRemind(int days) {
    InAppReviewManager().setMinDaysBeforeRemind(days);
    return this;
  }


}

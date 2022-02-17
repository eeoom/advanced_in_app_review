
import 'dart:async';
import 'dart:ui';

import 'package:advanced_in_app_review/InAppReviewManager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AdvancedInAppReview with WidgetsBindingObserver {

  static const MethodChannel _channel = MethodChannel('advanced_in_app_review');
  final InAppReviewManager _manager = InAppReviewManager();

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// Start monitoring conditions to decide wheter a view attemp is made or not
  void monitor() {
    _manager.monitor();
    _startObserver();
  }

  /// Number of times of opening the app before a view attemp is made
  AdvancedInAppReview setMinLaunchTimes(int launchTimes) {
    _manager.setMinLaunchTimes(launchTimes);
    return this;
  }

  /// Minimum number of days to wait after install before a view attemp is made
  AdvancedInAppReview setMinDaysAfterInstall(int days) {
    _manager.setMinDaysAfterInstall(days);
    return this;
  }

  /// Minimum number of days after a view attemp was made to try again
  AdvancedInAppReview setMinDaysBeforeRemind(int days) {
    _manager.setMinDaysBeforeRemind(days);
    return this;
  }

  _startObserver() {
    WidgetsBinding.instance?.addObserver(this);
    _afterLaunch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _afterLaunch();
    }
  }

  void _afterLaunch() {
    _manager.applicationWasLaunched();
    _manager.showRateDialogIfMeetsConditions();
  }

}



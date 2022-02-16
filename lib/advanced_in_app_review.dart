
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

  void monitor() {
    _manager.monitor();
    startObserver();
  }

  AdvancedInAppReview setMinLaunchTimes(int launchTimes) {
    _manager.setMinLaunchTimes(launchTimes);
    return this;
  }

  AdvancedInAppReview setMinDaysAfterInstall(int days) {
    _manager.setMinDaysAfterInstall(days);
    return this;
  }

  AdvancedInAppReview setMinDaysBeforeRemind(int days) {
    _manager.setMinDaysBeforeRemind(days);
    return this;
  }

  startObserver() {
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



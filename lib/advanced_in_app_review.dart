import 'dart:async';

import 'package:flutter/widgets.dart';

import 'in_app_review_manager.dart';
import 'src/review_platform.dart';
import 'src/review_result.dart';

export 'src/review_result.dart';

/// Create one instance in your root widget and dispose it with that widget.
class AdvancedInAppReview with WidgetsBindingObserver {
  AdvancedInAppReview({this.onResult}) {
    _manager = InAppReviewManager(
      isActive: () =>
          !_disposed &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  final ValueChanged<ReviewRequestResult>? onResult;
  late final InAppReviewManager _manager;
  bool _disposed = false;
  bool _observing = false;
  bool _automaticallyRequestReview = false;
  Future<void>? _monitoring;
  DateTime? _backgroundedAt;
  Duration _sessionGap = const Duration(minutes: 30);

  @Deprecated(
    'Platform versions are unrelated to review availability. Use isAvailable().',
  )
  static Future<String?> get platformVersion => MethodChannelReviewPlatform
      .channel
      .invokeMethod<String>('getPlatformVersion');

  /// Initializes storage and records the first session once per instance.
  /// By default requests are explicit, so the app can choose a suitable moment.
  Future<void> monitor({bool automaticallyRequestReview = false}) {
    _ensureUsable();
    if (_monitoring != null) return _monitoring!;
    _automaticallyRequestReview = automaticallyRequestReview;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    return _monitoring = _start();
  }

  Future<void> _start() async {
    try {
      await _manager.monitor();
      if (_disposed) return;
      await _manager.applicationWasLaunched();
      if (_automaticallyRequestReview && !_disposed) {
        unawaited(requestReviewIfEligible());
      }
    } catch (_) {
      _monitoring = null;
      rethrow;
    }
  }

  AdvancedInAppReview setMinLaunchTimes(int value) {
    _manager.setMinLaunchTimes(value);
    return this;
  }

  /// Days since the first use of this package, not the OS installation date.
  AdvancedInAppReview setMinDaysAfterInstall(int value) {
    _manager.setMinDaysAfterInstall(value);
    return this;
  }

  AdvancedInAppReview setMinDaysBeforeRemind(int value) {
    _manager.setMinDaysBeforeRemind(value);
    return this;
  }

  AdvancedInAppReview setMinSecondsBeforeShowDialog(int value) {
    _manager.setMinSecondsBeforeShowDialog(value);
    return this;
  }

  AdvancedInAppReview setMinSignificantEvents(int value) {
    _manager.setMinSignificantEvents(value);
    return this;
  }

  /// Adds an asynchronous gate evaluated once per eligible attempt, after the
  /// configured delay. All registered gates must return true. Applies to both
  /// explicit and automatic requests; registration order is preserved.
  AdvancedInAppReview addCustomConditionBeforeShowDialog(
    Future<bool> Function() condition,
  ) {
    _ensureUsable();
    _manager.addCustomConditionBeforeShowDialog(condition);
    return this;
  }

  AdvancedInAppReview setMinSessionGap(Duration value) {
    if (value.isNegative) throw ArgumentError.value(value, 'value');
    _sessionGap = value;
    return this;
  }

  Future<void> recordSignificantEvent() async {
    _ensureUsable();
    await monitor();
    await _manager.recordSignificantEvent();
  }

  Future<ReviewRequestResult> requestReviewIfEligible() async {
    _ensureUsable();
    ReviewRequestResult result;
    try {
      await monitor();
      result = await _manager.requestReviewIfEligible();
    } catch (error) {
      result = ReviewRequestResult(
        ReviewRequestStatus.failed,
        errorCode: 'initialization_failed',
        message: error.toString(),
      );
    }
    if (!_disposed) onResult?.call(result);
    return result;
  }

  Future<bool> isAvailable() => _manager.isAvailable();

  Future<void> openStoreListing({String? appStoreId}) =>
      _manager.openStoreListing(appStoreId: appStoreId);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state != AppLifecycleState.resumed) _manager.cancelPendingRequest();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >= _sessionGap) {
        unawaited(_resumeSession());
      }
    }
  }

  Future<void> _resumeSession() async {
    try {
      await monitor();
      if (_disposed) return;
      await _manager.applicationWasLaunched();
      if (_automaticallyRequestReview && !_disposed) {
        await requestReviewIfEligible();
      }
    } catch (error) {
      if (!_disposed) {
        onResult?.call(
          ReviewRequestResult(
            ReviewRequestStatus.failed,
            errorCode: 'session_failed',
            message: error.toString(),
          ),
        );
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _manager.dispose();
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('This review instance has been disposed.');
  }
}

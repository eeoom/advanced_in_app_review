import 'dart:async';

import 'package:flutter/services.dart';

import 'src/review_platform.dart';
import 'src/review_result.dart';
import 'src/review_store.dart';

/// Eligibility and scheduling, independent of Flutter widget lifecycle.
class InAppReviewManager {
  InAppReviewManager({
    ReviewStore? store,
    ReviewPlatform? platform,
    DateTime Function()? now,
    bool Function()? isActive,
  }) : _store = store ?? PreferencesReviewStore(),
       _platform = platform ?? MethodChannelReviewPlatform(),
       _now = now ?? DateTime.now,
       _isActive = isActive ?? (() => true);

  // Coordinate instances in the same isolate: no lost counter updates and no
  // overlapping store requests. Instantiate the package on the main isolate.
  static Future<void> _storageTail = Future<void>.value();
  static bool _requestPending = false;

  final ReviewStore _store;
  final ReviewPlatform _platform;
  final DateTime Function() _now;
  final bool Function() _isActive;
  bool _initialized = false;
  bool _disposed = false;
  int _generation = 0;
  int? _lastAttempt;
  Timer? _timer;
  Completer<void>? _delay;
  int _minLaunchTimes = 2;
  int _minDaysAfterInstall = 2;
  int _minDaysBeforeRemind = 90;
  int _minSecondsBeforeShowDialog = 1;
  int _minSignificantEvents = 0;

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    await _store.initialize();
    if (await _store.readInt(PreferencesReviewStore.installKey) == null) {
      await _store.writeInt(
        PreferencesReviewStore.installKey,
        _now().millisecondsSinceEpoch,
      );
    }
    _initialized = true;
  }

  Future<void> monitor() => _serialize(_initialize);

  Future<void> applicationWasLaunched() =>
      _increment(PreferencesReviewStore.launchesKey);

  Future<void> recordSignificantEvent() =>
      _increment(PreferencesReviewStore.eventsKey);

  Future<void> _increment(String key) => _serialize(() async {
    _ensureUsable();
    await _initialize();
    await _store.writeInt(key, (await _store.readInt(key) ?? 0) + 1);
  });

  Future<bool> _meetsConditions() => _serialize(() async {
    await _initialize();
    final launches =
        await _store.readInt(PreferencesReviewStore.launchesKey) ?? 0;
    final events = await _store.readInt(PreferencesReviewStore.eventsKey) ?? 0;
    final installed = await _store.readInt(PreferencesReviewStore.installKey);
    final storedAttempt = await _store.readInt(
      PreferencesReviewStore.attemptKey,
    );
    final attempted = switch ((_lastAttempt, storedAttempt)) {
      (final int local, final int stored) => local > stored ? local : stored,
      (final int local, null) => local,
      (null, final int stored) => stored,
      _ => null,
    };
    final now = _now().millisecondsSinceEpoch;
    return launches >= _minLaunchTimes &&
        events >= _minSignificantEvents &&
        installed != null &&
        now - installed >=
            Duration(days: _minDaysAfterInstall).inMilliseconds &&
        (attempted == null ||
            now - attempted >=
                Duration(days: _minDaysBeforeRemind).inMilliseconds);
  });

  /// Checks conditions, waits, rechecks, then asks the operating system.
  /// Only [ReviewRequestStatus.requested] advances the reminder timestamp.
  Future<ReviewRequestResult> requestReviewIfEligible() async {
    if (_disposed) {
      return const ReviewRequestResult(ReviewRequestStatus.cancelled);
    }
    if (_requestPending) {
      return const ReviewRequestResult(ReviewRequestStatus.alreadyPending);
    }
    _requestPending = true;
    final generation = _generation;
    try {
      if (!_isActive()) {
        return const ReviewRequestResult(ReviewRequestStatus.appNotActive);
      }
      if (!await _meetsConditions()) {
        return const ReviewRequestResult(ReviewRequestStatus.conditionsNotMet);
      }
      if (_minSecondsBeforeShowDialog > 0) {
        final delay = Completer<void>();
        _delay = delay;
        _timer = Timer(Duration(seconds: _minSecondsBeforeShowDialog), () {
          if (!delay.isCompleted) delay.complete();
        });
        // Cancellation may have happened during an earlier storage await.
        if (_disposed || generation != _generation) cancelPendingRequest();
        await delay.future;
      }
      if (_disposed || generation != _generation) {
        return const ReviewRequestResult(ReviewRequestStatus.cancelled);
      }
      if (!_isActive()) {
        return const ReviewRequestResult(ReviewRequestStatus.appNotActive);
      }
      if (!await _meetsConditions()) {
        return const ReviewRequestResult(ReviewRequestStatus.conditionsNotMet);
      }
      if (_disposed || generation != _generation) {
        return const ReviewRequestResult(ReviewRequestStatus.cancelled);
      }
      if (!_isActive()) {
        return const ReviewRequestResult(ReviewRequestStatus.appNotActive);
      }
      // Do not call isAvailable first: on Android that used to request and
      // discard a ReviewInfo before requesting another one for the real flow.
      await _platform.requestReview();
      _lastAttempt = _now().millisecondsSinceEpoch;
      await _serialize(
        () => _store.writeInt(PreferencesReviewStore.attemptKey, _lastAttempt!),
      );
      return const ReviewRequestResult(ReviewRequestStatus.requested);
    } on MissingPluginException catch (error) {
      return ReviewRequestResult(
        ReviewRequestStatus.notAvailable,
        errorCode: 'missing_plugin',
        message: error.message,
      );
    } on PlatformException catch (error) {
      final status = switch (error.code) {
        'unavailable' => ReviewRequestStatus.notAvailable,
        'app_not_active' => ReviewRequestStatus.appNotActive,
        'no_active_window' => ReviewRequestStatus.noActiveWindow,
        'already_pending' => ReviewRequestStatus.alreadyPending,
        _ => ReviewRequestStatus.failed,
      };
      return ReviewRequestResult(
        status,
        errorCode: error.code,
        message: error.message,
      );
    } catch (error) {
      return ReviewRequestResult(
        ReviewRequestStatus.failed,
        errorCode: 'request_failed',
        message: error.toString(),
      );
    } finally {
      _timer?.cancel();
      _timer = null;
      _delay = null;
      _requestPending = false;
    }
  }

  /// Compatibility wrapper. True means a native request completed, not shown.
  Future<bool> showRateDialogIfMeetsConditions() async =>
      (await requestReviewIfEligible()).status == ReviewRequestStatus.requested;

  Future<bool> isAvailable() => _platform.isAvailable();

  /// For a user-initiated rate button; errors are propagated to the caller.
  Future<void> openStoreListing({String? appStoreId}) =>
      _platform.openStoreListing(appStoreId: appStoreId);

  void setMinLaunchTimes(int value) => _minLaunchTimes = _nonNegative(value);
  void setMinDaysAfterInstall(int value) =>
      _minDaysAfterInstall = _nonNegative(value);
  void setMinDaysBeforeRemind(int value) =>
      _minDaysBeforeRemind = _nonNegative(value);
  void setMinSecondsBeforeShowDialog(int value) =>
      _minSecondsBeforeShowDialog = _nonNegative(value);
  void setMinSignificantEvents(int value) =>
      _minSignificantEvents = _nonNegative(value);

  int _nonNegative(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative');
    }
    return value;
  }

  void cancelPendingRequest() {
    _generation++;
    _timer?.cancel();
    final delay = _delay;
    if (delay != null && !delay.isCompleted) delay.complete();
  }

  void dispose() {
    _disposed = true;
    cancelPendingRequest();
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('This review manager has been disposed.');
  }
}

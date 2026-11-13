import 'dart:async';

import 'package:advanced_in_app_review/advanced_in_app_review.dart';
import 'package:advanced_in_app_review/in_app_review_manager.dart';
import 'package:advanced_in_app_review/src/review_platform.dart';
import 'package:advanced_in_app_review/src/review_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class MemoryStore implements ReviewStore {
  final values = <String, int>{};
  Completer<void>? initializing;
  bool failWrites = false;

  @override
  Future<void> initialize() async {
    await initializing?.future;
  }

  @override
  Future<int?> readInt(String key) async => values[key];
  @override
  Future<void> writeInt(String key, int value) async {
    if (failWrites) throw StateError('disk error');
    values[key] = value;
  }
}

class FakePlatform implements ReviewPlatform {
  int requests = 0;
  Completer<void>? requesting;
  PlatformException? error;

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<void> requestReview() async {
    requests++;
    if (error != null) throw error!;
    await requesting?.future;
  }

  @override
  Future<void> openStoreListing({String? appStoreId}) async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late FakePlatform platform;
  late InAppReviewManager manager;
  late DateTime now;
  bool active = true;

  setUp(() {
    now = DateTime.utc(2026, 11, 2);
    active = true;
    store = MemoryStore();
    platform = FakePlatform();
    manager =
        InAppReviewManager(
            store: store,
            platform: platform,
            now: () => now,
            isActive: () => active,
          )
          ..setMinLaunchTimes(1)
          ..setMinDaysAfterInstall(0)
          ..setMinSecondsBeforeShowDialog(0);
  });
  tearDown(() => manager.dispose());

  test('first use initializes before incrementing and checking', () async {
    await manager.applicationWasLaunched();
    expect(
      store.values[PreferencesReviewStore.installKey],
      now.millisecondsSinceEpoch,
    );
    expect(
      (await manager.requestReviewIfEligible()).status,
      ReviewRequestStatus.requested,
    );
    expect(platform.requests, 1);
  });

  test(
    'days, launches, events and exact reminder boundary are respected',
    () async {
      manager
        ..setMinLaunchTimes(2)
        ..setMinDaysAfterInstall(2)
        ..setMinSignificantEvents(2);
      await manager.applicationWasLaunched();
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      now = now.add(const Duration(days: 2));
      await manager.applicationWasLaunched();
      await manager.recordSignificantEvent();
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      await manager.recordSignificantEvent();
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
      now = now
          .add(const Duration(days: 90))
          .subtract(const Duration(milliseconds: 1));
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      now = now.add(const Duration(milliseconds: 1));
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
    },
  );

  test('concurrent instances do not lose session increments', () async {
    final other = InAppReviewManager(store: store, now: () => now);
    addTearDown(other.dispose);
    await Future.wait(
      List.generate(
        20,
        (index) => (index.isEven ? manager : other).applicationWasLaunched(),
      ),
    );
    expect(store.values[PreferencesReviewStore.launchesKey], 20);
  });

  test('overlapping requests across instances are rejected', () async {
    await manager.applicationWasLaunched();
    platform.requesting = Completer<void>();
    final first = manager.requestReviewIfEligible();
    final other = InAppReviewManager(store: store, platform: platform);
    addTearDown(other.dispose);
    expect(
      (await other.requestReviewIfEligible()).status,
      ReviewRequestStatus.alreadyPending,
    );
    platform.requesting!.complete();
    expect((await first).status, ReviewRequestStatus.requested);
    expect(platform.requests, 1);
  });

  test('backgrounding cancels the delayed request', () async {
    await manager.applicationWasLaunched();
    manager.setMinSecondsBeforeShowDialog(5);
    final request = manager.requestReviewIfEligible();
    await Future<void>.delayed(Duration.zero);
    active = false;
    manager.cancelPendingRequest();
    expect((await request).status, ReviewRequestStatus.cancelled);
    expect(platform.requests, 0);
  });

  test(
    'cancellation while storage initializes prevents native request',
    () async {
      store.initializing = Completer<void>();
      manager.setMinLaunchTimes(0);
      final request = manager.requestReviewIfEligible();
      manager.dispose();
      store.initializing!.complete();
      expect((await request).status, ReviewRequestStatus.cancelled);
      expect(platform.requests, 0);
    },
  );

  test('inactive app never requests or advances cooldown', () async {
    active = false;
    expect(
      (await manager.requestReviewIfEligible()).status,
      ReviewRequestStatus.appNotActive,
    );
    expect(platform.requests, 0);
    expect(store.values[PreferencesReviewStore.attemptKey], isNull);
  });

  for (final entry in {
    'unavailable': ReviewRequestStatus.notAvailable,
    'no_active_window': ReviewRequestStatus.noActiveWindow,
    'app_not_active': ReviewRequestStatus.appNotActive,
    'already_pending': ReviewRequestStatus.alreadyPending,
    'request_failed': ReviewRequestStatus.failed,
  }.entries) {
    test('${entry.key} is diagnosed without advancing cooldown', () async {
      await manager.applicationWasLaunched();
      platform.error = PlatformException(code: entry.key, message: 'test');
      final result = await manager.requestReviewIfEligible();
      expect(result.status, entry.value);
      expect(result.errorCode, entry.key);
      expect(store.values[PreferencesReviewStore.attemptKey], isNull);
      platform.error = null;
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
    });
  }

  test(
    'storage error is reported and does not poison the operation queue',
    () async {
      store.failWrites = true;
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.failed,
      );
      store.failWrites = false;
      await manager.applicationWasLaunched();
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
    },
  );

  test(
    'newer attempts from another instance override local cached attempts',
    () async {
      await manager.applicationWasLaunched();
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
      now = now.add(const Duration(days: 90));
      final other =
          InAppReviewManager(store: store, platform: platform, now: () => now)
            ..setMinLaunchTimes(1)
            ..setMinDaysAfterInstall(0)
            ..setMinSecondsBeforeShowDialog(0);
      addTearDown(other.dispose);
      expect(
        (await other.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      expect(platform.requests, 2);
    },
  );

  test(
    'custom gates run in order once and short circuit without cooldown',
    () async {
      await manager.applicationWasLaunched();
      final calls = <int>[];
      bool allow = false;
      manager.addCustomConditionBeforeShowDialog(() async {
        calls.add(1);
        return allow;
      });
      manager.addCustomConditionBeforeShowDialog(() async {
        calls.add(2);
        // Storage writes inside a callback must not deadlock the storage queue.
        await manager.recordSignificantEvent();
        return true;
      });
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      expect(calls, [1]);
      expect(platform.requests, 0);
      expect(store.values[PreferencesReviewStore.attemptKey], isNull);
      allow = true;
      calls.clear();
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.requested,
      );
      expect(calls, [1, 2]);
      expect(platform.requests, 1);
    },
  );

  test('ineligible requests do not run custom gates', () async {
    var calls = 0;
    manager.addCustomConditionBeforeShowDialog(() async {
      calls++;
      return true;
    });
    expect(
      (await manager.requestReviewIfEligible()).status,
      ReviewRequestStatus.conditionsNotMet,
    );
    expect(calls, 0);
  });

  for (final asynchronous in [false, true]) {
    test(
      'custom gate failure is diagnosed and releases lock (async=$asynchronous)',
      () async {
        await manager.applicationWasLaunched();
        var fail = true;
        manager.addCustomConditionBeforeShowDialog(() {
          if (fail) {
            final error = PlatformException(code: 'unavailable');
            if (asynchronous) return Future<bool>.error(error);
            throw error;
          }
          return Future.value(true);
        });
        final result = await manager.requestReviewIfEligible();
        expect(result.status, ReviewRequestStatus.failed);
        expect(result.errorCode, 'custom_condition_failed');
        expect(platform.requests, 0);
        expect(store.values[PreferencesReviewStore.attemptKey], isNull);
        fail = false;
        expect(
          (await manager.requestReviewIfEligible()).status,
          ReviewRequestStatus.requested,
        );
      },
    );
  }

  for (final dispose in [false, true]) {
    test(
      'cancellation stops waiting for a custom gate (dispose=$dispose)',
      () async {
        await manager.applicationWasLaunched();
        final entered = Completer<void>();
        final gate = Completer<bool>();
        manager.addCustomConditionBeforeShowDialog(() {
          entered.complete();
          return gate.future;
        });
        final request = manager.requestReviewIfEligible();
        await entered.future;
        expect(
          (await manager.requestReviewIfEligible()).status,
          ReviewRequestStatus.alreadyPending,
        );
        if (dispose) {
          manager.dispose();
        } else {
          manager.cancelPendingRequest();
        }
        expect((await request).status, ReviewRequestStatus.cancelled);
        expect(platform.requests, 0);
        expect(store.values[PreferencesReviewStore.attemptKey], isNull);
        // A late callback error must not escape or trigger a native request.
        gate.completeError(StateError('late callback failure'));
        await Future<void>.delayed(Duration.zero);
        final other = InAppReviewManager(store: store, platform: platform)
          ..setMinDaysAfterInstall(0)
          ..setMinLaunchTimes(0)
          ..setMinSecondsBeforeShowDialog(0);
        addTearDown(other.dispose);
        expect(
          (await other.requestReviewIfEligible()).status,
          ReviewRequestStatus.requested,
        );
      },
    );
  }

  test(
    'app activity and built-in eligibility are rechecked after custom gates',
    () async {
      await manager.applicationWasLaunched();
      var deactivate = true;
      manager.addCustomConditionBeforeShowDialog(() async {
        if (deactivate) {
          active = false;
        } else {
          manager.setMinSignificantEvents(1);
        }
        return true;
      });
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.appNotActive,
      );
      active = true;
      deactivate = false;
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      expect(platform.requests, 0);
    },
  );

  test('custom gates run after the configured delay', () async {
    await manager.applicationWasLaunched();
    manager.setMinSecondsBeforeShowDialog(2);
    var calls = 0;
    manager.addCustomConditionBeforeShowDialog(() async {
      calls++;
      return true;
    });
    final request = manager.requestReviewIfEligible();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls, 0);
    expect(platform.requests, 0);
    expect((await request).status, ReviewRequestStatus.requested);
    expect(calls, 1);
  });

  test(
    'conditions added during an attempt apply on the next attempt',
    () async {
      await manager.applicationWasLaunched();
      manager.setMinDaysBeforeRemind(0);
      final entered = Completer<void>();
      final gate = Completer<bool>();
      var first = true;
      manager.addCustomConditionBeforeShowDialog(() {
        if (first) {
          first = false;
          entered.complete();
          return gate.future;
        }
        return Future.value(true);
      });
      final request = manager.requestReviewIfEligible();
      await entered.future;
      manager.addCustomConditionBeforeShowDialog(() async => false);
      gate.complete(true);
      expect((await request).status, ReviewRequestStatus.requested);
      expect(
        (await manager.requestReviewIfEligible()).status,
        ReviewRequestStatus.conditionsNotMet,
      );
      expect(platform.requests, 1);
    },
  );

  test('negative configuration is rejected', () {
    expect(() => manager.setMinLaunchTimes(-1), throwsArgumentError);
    expect(() => manager.setMinDaysAfterInstall(-1), throwsArgumentError);
    expect(() => manager.setMinDaysBeforeRemind(-1), throwsArgumentError);
    expect(() => manager.setMinSignificantEvents(-1), throwsArgumentError);
    expect(
      () => manager.setMinSecondsBeforeShowDialog(-1),
      throwsArgumentError,
    );
  });

  group('real preferences migration and lifecycle', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    for (final automatic in [false, true]) {
      test(
        'public custom gates apply to requests (automatic=$automatic)',
        () async {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          var nativeRequests = 0;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            MethodChannelReviewPlatform.channel,
            (call) async {
              if (call.method == 'requestReview') nativeRequests++;
              return null;
            },
          );
          addTearDown(
            () => messenger.setMockMethodCallHandler(
              MethodChannelReviewPlatform.channel,
              null,
            ),
          );
          var result = Completer<ReviewRequestResult>();
          var allowed = false;
          final review =
              AdvancedInAppReview(onResult: (value) => result.complete(value))
                ..setMinDaysAfterInstall(0)
                ..setMinLaunchTimes(0)
                ..setMinSecondsBeforeShowDialog(0);
          addTearDown(review.dispose);
          expect(
            review.addCustomConditionBeforeShowDialog(() async => allowed),
            same(review),
          );
          await review.monitor(automaticallyRequestReview: automatic);
          if (!automatic) await review.requestReviewIfEligible();
          expect(
            (await result.future).status,
            ReviewRequestStatus.conditionsNotMet,
          );
          expect(nativeRequests, 0);
          allowed = true;
          result = Completer<ReviewRequestResult>();
          if (automatic) {
            review.setMinSessionGap(Duration.zero);
            review.didChangeAppLifecycleState(AppLifecycleState.paused);
            review.didChangeAppLifecycleState(AppLifecycleState.resumed);
          } else {
            await review.requestReviewIfEligible();
          }
          expect((await result.future).status, ReviewRequestStatus.requested);
          expect(nativeRequests, 1);
          review.dispose();
          expect(
            () => review.addCustomConditionBeforeShowDialog(() async => true),
            throwsStateError,
          );
        },
      );
    }

    test('only plugin keys migrate; existing async values survive', () async {
      SharedPreferences.setMockInitialValues({
        PreferencesReviewStore.installKey: 100,
        PreferencesReviewStore.launchesKey: 7,
        PreferencesReviewStore.attemptKey: 200,
        'unrelated_application_setting': 42,
      });
      final asyncPrefs = SharedPreferencesAsync();
      await asyncPrefs.setInt(PreferencesReviewStore.launchesKey, 9);
      final preferences = PreferencesReviewStore();
      await preferences.initialize();
      expect(await preferences.readInt(PreferencesReviewStore.installKey), 100);
      expect(await preferences.readInt(PreferencesReviewStore.launchesKey), 9);
      expect(await preferences.readInt(PreferencesReviewStore.attemptKey), 200);
      expect(await asyncPrefs.getInt('unrelated_application_setting'), isNull);
      await preferences.writeInt(PreferencesReviewStore.attemptKey, 300);
      await preferences.initialize();
      expect(await preferences.readInt(PreferencesReviewStore.attemptKey), 300);
    });

    test(
      'monitor is idempotent; brief resumes and system overlays do not count',
      () async {
        final review = AdvancedInAppReview();
        addTearDown(review.dispose);
        await Future.wait([review.monitor(), review.monitor()]);
        review.didChangeAppLifecycleState(AppLifecycleState.inactive);
        review.didChangeAppLifecycleState(AppLifecycleState.resumed);
        review.didChangeAppLifecycleState(AppLifecycleState.paused);
        review.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(
          await SharedPreferencesAsync().getInt(
            PreferencesReviewStore.launchesKey,
          ),
          1,
        );
      },
    );

    test('a new session is recorded after the configured gap', () async {
      final review = AdvancedInAppReview()..setMinSessionGap(Duration.zero);
      addTearDown(review.dispose);
      await review.monitor();
      review.didChangeAppLifecycleState(AppLifecycleState.paused);
      review.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Queue an event behind the resumed-session update.
      await review.recordSignificantEvent();
      expect(
        await SharedPreferencesAsync().getInt(
          PreferencesReviewStore.launchesKey,
        ),
        2,
      );
    });

    test(
      'monitor does not automatically request a review by default',
      () async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        int calls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannelReviewPlatform.channel, (
              call,
            ) async {
              calls++;
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                MethodChannelReviewPlatform.channel,
                null,
              ),
        );
        final review = AdvancedInAppReview()
          ..setMinDaysAfterInstall(0)
          ..setMinLaunchTimes(0)
          ..setMinSecondsBeforeShowDialog(0);
        addTearDown(review.dispose);
        await review.monitor();
        expect(calls, 0);
        expect(
          (await review.requestReviewIfEligible()).status,
          ReviewRequestStatus.requested,
        );
        expect(calls, 1);
      },
    );
  });
}

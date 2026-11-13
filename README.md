# advanced_in_app_review

> **Version 2.0 includes breaking changes for 1.x apps.** Read [Migration from 1.x](#migration-from-1x) before upgrading.
> See the [2.0.0 release notes](https://github.com/eeoom/advanced_in_app_review/releases/tag/2.0.0).

Native in-app review requests for **Android and iOS**, with persistent conditions,
session counting, significant events, cancellation and diagnostic results.
The package owns its StoreKit and Google Play integration; it does not depend on
`in_app_review`.

## Requirements

- Flutter 3.47 / Dart 3.13 or newer.
- Android API 24+, with Google Play Store for in-app reviews.
- iOS 13+ at plugin level; your Flutter version may require a newer iOS target.
- iOS supports both Swift Package Manager and CocoaPods.

Add `advanced_in_app_review` to your Flutter dependencies. No manual Play Review
Gradle dependencies or review-specific iOS permissions are needed.

## Choose a suitable moment

Initialize one instance in your root widget. After a meaningful completed task,
record the event and ask the package to check eligibility:

```dart
final review = AdvancedInAppReview(
  onResult: (result) => debugPrint(result.toString()),
)
  ..setMinDaysAfterInstall(7)
  ..setMinLaunchTimes(5)
  ..setMinSignificantEvents(3)
  ..setMinDaysBeforeRemind(90)
  ..setMinSecondsBeforeShowDialog(2);

await review.monitor();

// At a natural pause after completing a task:
await review.recordSignificantEvent();
final result = await review.requestReviewIfEligible();

// In your root widget's dispose():
review.dispose();
```

`monitor()` initializes and counts sessions; **it does not request a review by
default**. The first call counts one session. Subsequent foreground transitions
count a new session only after at least 30 minutes in the background. Configure
that interval with `setMinSessionGap(Duration(...))`. System overlays and short
app switches do not inflate the session count. Significant events accumulate
across sessions and are not reset after an attempt.

## Automatic setup in `main.dart`

For automatic review attempts, initialize the package once in the `State` of your
root widget in `main.dart` and enable `automaticallyRequestReview`. This Material
UI example requires `material_ui: ^1.0.0` in your app dependencies (supported from
Flutter 3.47 onward):

```dart
import 'package:advanced_in_app_review/advanced_in_app_review.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _review = AdvancedInAppReview(
    onResult: (result) => debugPrint(result.toString()),
  )
    ..setMinDaysAfterInstall(7)
    ..setMinLaunchTimes(5)
    ..setMinDaysBeforeRemind(90)
    ..setMinSecondsBeforeShowDialog(2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startReviewMonitoring();
    });
  }

  Future<void> _startReviewMonitoring() async {
    try {
      await _review.monitor(automaticallyRequestReview: true);
    } catch (error) {
      debugPrint('Review initialization failed: $error');
    }
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: Text('My app'))),
  );
}
```

In this example, an attempt is eligible after at least **7 days since first use**
and **5 sessions**, with at least **90 days between completed native requests**.
All conditions must be met. The package checks after initialization and after a
new session, then waits 2 seconds before requesting a review. It does not run a
continuous timer or trigger exactly when the configured number of days elapses.
A new session normally requires at least 30 minutes in the background.

No calls to `recordSignificantEvent()` or `requestReviewIfEligible()` are needed
for this setup. If you additionally configure `setMinSignificantEvents(...)`, you
must record those events yourself. Call `monitor()` once with the intended mode.
The operating system still decides whether to display a dialog. On iOS,
TestFlight does not display review requests; use a development build to test
presentation.

For finer control over the moment of the request, use the explicit setup above
after a completed task instead.

## Lifecycle and configuration

Keep one instance on the main isolate, await initialization and event writes, and
dispose it with its owning widget. Configuration is per instance. Negative
configuration values are rejected. Pending delays are cancelled when the app
becomes inactive or the instance is disposed. An already submitted native request
cannot be withdrawn by the Dart timer.

## Results and diagnostics

| Status | Meaning |
| --- | --- |
| `requested` | The native request completed. This does **not** confirm presentation or a rating. |
| `conditionsNotMet` | The configured time, session, event or reminder threshold is not met. |
| `alreadyPending` | Another review attempt is already in progress. |
| `appNotActive` | The app or Android Activity is not in the foreground. |
| `noActiveWindow` | iOS cannot find an attached, active window for this Flutter view. |
| `notAvailable` | The platform integration or required store is unavailable. |
| `cancelled` | A scheduled attempt was cancelled before invoking the native API. |
| `failed` | A storage/native operation failed; inspect `errorCode` and `message`. |

The reminder timestamp advances after a completed native request, even if the
system silently suppresses the UI. Unavailable/failed requests do not advance it.
The default reminder interval is 90 days. `isAvailable()` checks basic capability,
not quota or whether the user will see a dialog; it is not required before a
request. On Android it does not create and discard an extra review flow.

iOS resolves the requesting Flutter view's attached window at call time and uses
its active scene. It never picks an arbitrary `connectedScenes.first`. StoreKit
calls execute on the main actor. Android rechecks Activity readiness after the
asynchronous Play request and ignores late callbacks after detachment.

## A permanent “Rate this app” button

Use the store listing rather than a quota-limited in-app request:

```dart
await review.openStoreListing(appStoreId: 'YOUR_NUMERIC_APP_STORE_ID');
```

The ID is required only on iOS. Android uses the application package name and
falls back to its HTTPS Play listing if the Play Store app cannot be opened.
Handle exceptions from this method to provide feedback when opening fails.

## Migration from 1.x

**A dependency version update alone does not preserve automatic review requests.**
`monitor()` initializes the plugin but no longer requests a review by default.
For automatic attempts, replace the old call with:

```dart
await review.monitor(automaticallyRequestReview: true);
```

Use the complete root-widget example above for initialization after the first
frame, error handling and disposal. All configured conditions must be met before
an attempt; the operating system still decides whether a dialog appears.

- Upgrade to Flutter 3.47 / Dart 3.13 or newer, Android API 24+ and iOS 13+
  (your Flutter version may require a higher iOS target).
- Remove any manually added `com.google.android.play:review` / `review-ktx`
  dependencies that existed only for this package.
- Await `monitor()`, which now returns `Future<void>`.
- Trigger `requestReviewIfEligible()` after a suitable completed task, or opt
  into automatic requests as described above.
- The default reminder interval changes from 1 day to 90 days.
- App launches now mean sessions, rather than every `resumed` lifecycle event.
- Setters are instance-specific rather than modifying global singleton state.
- Existing first-use date, launch count and last-attempt timestamp migrate to
  `SharedPreferencesAsync`. Only this package's keys are migrated; existing
  destination values are preserved. Event counting starts at zero.
- “Days after install” actually means days since this package's first use, as in
  1.x. Backup/restore behavior is determined by the app and OS storage settings.
- `platformVersion` is retained for compatibility but deprecated.
- Android/iOS are the supported targets; macOS and web are not implemented.

## Testing

```sh
flutter analyze
flutter test
cd example
flutter test test/widget_test.dart
flutter build apk --debug
cd android
./gradlew :advanced_in_app_review:testDebugUnitTest
cd ..
flutter build ios --simulator --debug
flutter test integration_test/native_review_test.dart -d <device-id>
```

GitHub Actions checks Flutter **3.47.0** and **3.50.0**, including analysis,
Dart/widget tests, Android builds and native tests, and iOS builds with both
SwiftPM and CocoaPods. The SwiftPM jobs also run the iOS integration test.

The example uses AGP 9.3.1, Gradle 9.5.0 and Kotlin 2.4.20. The plugin itself
does not pin the consuming app's Android build-tool versions.

Dart tests cover eligibility, migration, overlapping requests and lifecycle
cancellation. Android tests cover native asynchronous errors, late callbacks and
single replies. The integration test exercises the real native channel and the
iOS host window; it does not assert that the system dialog appears.

For Android review presentation, use Google Play internal testing or internal app
sharing and an eligible Play account. A sideloaded debug build is insufficient to
prove production presentation. On iOS use development-device testing; TestFlight
does not display the review request. Store quotas and user settings still apply.

See [Google Play testing](https://developer.android.com/guide/playcore/in-app-review/test)
and [Apple review requests](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews).

Native integration was reworked with reference to the MIT-licensed
`in_app_review` project. Attribution is included in `THIRD_PARTY_NOTICES`.

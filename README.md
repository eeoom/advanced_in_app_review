# advanced_in_app_review

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

For the legacy automatic behavior, explicitly opt in with
`await review.monitor(automaticallyRequestReview: true)`. Automatic requests happen
after initialization and new sessions, so an explicit request after a completed
task is generally preferable. Call `monitor()` once with the intended mode.

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

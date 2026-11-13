## 2.0.0

First stable release of the native Android/iOS integration tested in the 2.0
prereleases. No additional runtime changes since 2.0.0-dev.2.

### Breaking changes from 1.x

* Require Flutter 3.47 / Dart 3.13, Android API 24+ and iOS 13+ (Flutter may
  require a newer iOS deployment target).
* `monitor()` now returns `Future<void>` and initializes without requesting a
  review by default. Await `monitor(automaticallyRequestReview: true)` for
  automatic attempts, or explicitly call `requestReviewIfEligible()`.
* Count foreground sessions with a default 30-minute background gap instead of
  counting every resume. Change the default reminder interval from 1 to 90 days.
* Make configuration instance-specific rather than global singleton state.
* Own the native integration directly; remove manual Play Review dependencies
  that were added solely for this package. Android and iOS are supported.

### Improvements

* Use the requesting Flutter view's active iOS window and guard StoreKit APIs
  for the declared iOS deployment target.
* Serialize storage updates, migrate existing package preferences, prevent
  overlapping requests and cancel pending delays on backgrounding/disposal.
* Add diagnostic results, significant-event conditions and store listing links.
* Support Swift Package Manager, CocoaPods and Android built-in Kotlin.
* Verify Flutter 3.47.0 and 3.50.0 in CI, including Android builds/native tests,
  iOS SwiftPM/CocoaPods builds and iOS simulator integration tests.

See the README migration guide for setup and behavior changes.

## 2.0.0-dev.2

* Fix the iOS 13 StoreKit fallback so SwiftPM builds honor the declared minimum
  deployment target without calling the iOS 14-only scene overload.
* Check Flutter 3.47.0 and 3.50.0 in CI across Dart tests, Android builds/native
  tests and iOS SwiftPM/CocoaPods builds and simulator integration tests.
* Update the Android example to AGP 9.3.1, Gradle 9.5.0 and Kotlin 2.4.20 for
  Flutter 3.50 compatibility; keep the plugin minimum at Flutter 3.47.
* Migrate the example and README Material imports to the standalone material_ui
  package to avoid Flutter 3.50 deprecation diagnostics.

## 2.0.0-dev.1

* Integrate native StoreKit and Google Play Review directly; remove in_app_review.
* Resolve the active iOS window from the requesting Flutter view and run StoreKit
  on the main actor; report missing-window and inactive-app errors explicitly.
* Handle Android callback exceptions, detached activities and late/duplicate replies.
* Await and serialize initialization and counter writes. Prevent overlapping
  requests and cancel pending delays on backgrounding/disposal.
* Add explicit eligibility requests, significant events, diagnostics and store links.
* Default to explicit requests, 30-minute session gaps and a 90-day reminder.
* Migrate existing plugin preferences to SharedPreferencesAsync without touching
  unrelated application data; make configuration instance-specific.
* Add SwiftPM/Privacy Manifest support and modernize Android Kotlin/Gradle builds.
* Require Flutter 3.47/Dart 3.13, Android API 24+ and iOS 13+ (Flutter may require newer).
* Add Dart, Android native and device integration tests and CI build checks.

## 1.5.0

* targetSDK up to 36

## 1.4.0

* libraries and dependencies updated

## 1.3.0

* gradle settings

## 1.2.1

* namespace added for Android.

## 1.2.0

* important install instructions for Android added.

## 1.1.3

* set kotlin-gradle-plugin version back to 1.7.20 as it may cause compilation errors.

## 1.1.2

* feature setMinSecondsBeforeShowDialog added.

## 1.1.1

* kotlin-gradle-plugin version upgraded to 1.7.20.

## 1.1.0

* support for Flutter 3.0

## 1.0.5

* typo in one key value corrected.

## 1.0.4

* project structure

## 1.0.3

* code style

## 1.0.2

* readme updated

## 1.0.1

* Some changes to project settings

## 1.0.0

* First version.








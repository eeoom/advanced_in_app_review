# advanced_in_app_review

> **Version 2.0 is in active development.** The [2.0.0-dev.2 prerelease](https://pub.dev/packages/advanced_in_app_review/versions/2.0.0-dev.2) is available on pub.dev.
> See the [new implementation and migration guide for 2.0](https://github.com/eeoom/advanced_in_app_review/tree/2.0.0-dev.2#readme) and the [GitHub prerelease](https://github.com/eeoom/advanced_in_app_review/releases/tag/2.0.0-dev.2).
> Version 2.0 includes its own native Android/iOS integration, improved review scheduling and diagnostics, and support for built-in Kotlin and Swift Package Manager. Requires Flutter 3.47 / Dart 3.13 or newer; tested with Flutter 3.47.0 and 3.50.0.
>
> The documentation below describes the stable 1.x version. For 2.0 setup and migration, follow the 2.0 README linked above.

# Description
A Flutter plugin that lets you show a review pop up where users can leave a review for your app without needing to leave your app.

The average end-user will only write a review if something is wrong with your App. This leads to an unfairly negative skew in the ratings, when the majority of satisfied customers don’t leave reviews and only the dissatisfied ones do. In order to counter-balance the negatives, advanced_in_app_review prompts the user to write a review, but only after the developer knows they are satisfied. For example, you may only show the popup if the user has been using it for more than a week, and has done at least 5 significant events (the core functionality of your App). The rules are fully customizable for your App and easy to setup.

It uses the [In-App Review](https://developer.android.com/guide/playcore/in-app-review) API on Android and the [SKStoreReviewController](https://developer.apple.com/documentation/storekit/skstorereviewcontroller) on iOS/MacOS.

# Setup (Android only)

The Play In-App Review library is a part of the Google Play Core libraries. Please include the following Gradle dependency to integrate the Play In-App Review Library. More info see [Android doc](https://developer.android.com/guide/playcore/in-app-review/kotlin-java).

 ```
 // In your app’s build.gradle file:
 ...
 dependencies {
     // This dependency is downloaded from the Google’s Maven repository.
     // So, make sure you also include that repository in your project's build.gradle file.
     implementation 'com.google.android.play:review:2.0.1'
     // For Kotlin users also add the Kotlin extensions library for Play In-App Review:
     implementation 'com.google.android.play:review-ktx:2.0.1'
     ...
 }
 ```

## Usage

### Simple 1-line Setup

```dart
@override
void initState() {
  super.initState();
  initPlatformState();
  AdvancedInAppReview()
      .setMinDaysBeforeRemind(7)
      .setMinDaysAfterInstall(2)
      .setMinLaunchTimes(2)
      .setMinSecondsBeforeShowDialog(4)
      .monitor();
}
```

## Important notes for Android

Google encourages developers not to spam users with review requests right when they first start an app, instead asking studios to prompt people only after they've used the application for a while. Developers also shouldn't interrupt users in the middle of a task. After leaving a review or aborting, people should be able to continue whatever they were doing seamlessly.

Android decides when and if such a review view will be presented to the user. So please do not wonder if the view is not presented during debugging. As Google also noted, it will not be working in debug mode. Please see https://developer.android.com/guide/playcore/in-app-review/test

# Requirements
## Android
Requires Android 5 Lollipop (API 21) or higher and the Google Play Store to be installed.
## IOS
Requires iOS version 10.3

Issues & pull requests are more than welcome!

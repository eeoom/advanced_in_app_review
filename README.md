# advanced_in_app_review

# Description
A Flutter plugin that lets you show a review pop up where users can leave a review for your app without needing to leave your app.

The average end-user will only write a review if something is wrong with your App. This leads to an unfairly negative skew in the ratings, when the majority of satisfied customers don’t leave reviews and only the dissatisfied ones do. In order to counter-balance the negatives, advanced_in_app_review prompts the user to write a review, but only after the developer knows they are satisfied. For example, you may only show the popup if the user has been using it for more than a week, and has done at least 5 significant events (the core functionality of your App). The rules are fully customizable for your App and easy to setup.

It uses the [In-App Review](https://developer.android.com/guide/playcore/in-app-review) API on Android and the [SKStoreReviewController](https://developer.apple.com/documentation/storekit/skstorereviewcontroller) on iOS/MacOS.

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

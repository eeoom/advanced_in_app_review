#import "AdvancedInAppReviewPlugin.h"
#if __has_include(<advanced_in_app_review/advanced_in_app_review-Swift.h>)
#import <advanced_in_app_review/advanced_in_app_review-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "advanced_in_app_review-Swift.h"
#endif

@implementation AdvancedInAppReviewPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAdvancedInAppReviewPlugin registerWithRegistrar:registrar];
}
@end

import Flutter
import StoreKit
import UIKit

public class AdvancedInAppReviewPlugin: NSObject, FlutterPlugin {
    private weak var registrar: FlutterPluginRegistrar?
    private var requesting = false

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "advanced_in_app_review", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(AdvancedInAppReviewPlugin(registrar: registrar), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // UIKit and StoreKit must run on the main thread, including scene lookup.
        DispatchQueue.main.async { [self] in
            switch call.method {
            case "getPlatformVersion":
                result("iOS " + UIDevice.current.systemVersion)
            case "isAvailable":
                result(true) // Supported OS, not a guarantee of presentation.
            case "requestReview":
                requestReview(result)
            case "openStoreListing":
                let arguments = call.arguments as? [String: Any]
                openStoreListing(arguments?["appStoreId"] as? String, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @MainActor
    private func requestReview(_ result: @escaping FlutterResult) {
        guard !requesting else {
            result(FlutterError(code: "already_pending", message: "A review request is already running.", details: nil))
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            result(FlutterError(code: "app_not_active", message: "The application is not active.", details: nil))
            return
        }
        // Resolve the host at request time: it may not exist during registration.
        // Never fall back to an unrelated connected scene in a multi-window app.
        guard let window = registrar?.viewController?.viewIfLoaded?.window else {
            result(FlutterError(code: "no_active_window", message: "The Flutter view is not attached to a window yet.", details: nil))
            return
        }
        guard let scene = window.windowScene,
              scene.activationState == .foregroundActive,
              !window.isHidden else {
            result(FlutterError(code: "no_active_window", message: "The Flutter window scene is not active.", details: nil))
            return
        }
        requesting = true
        defer { requesting = false }
        if #available(iOS 16.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        // This confirms API invocation only. StoreKit does not report display.
        result(nil)
    }

    @MainActor
    private func openStoreListing(_ storeID: String?, result: @escaping FlutterResult) {
        guard let storeID = storeID, !storeID.isEmpty,
              storeID.allSatisfy({ $0.isASCII && $0.isNumber }),
              let url = URL(string: "https://apps.apple.com/app/id\(storeID)?action=write-review") else {
            result(FlutterError(code: "invalid_store_id", message: "Pass the numeric App Store ID as appStoreId.", details: nil))
            return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
            if opened { result(nil) }
            else { result(FlutterError(code: "store_open_failed", message: "Could not open the App Store.", details: nil)) }
        }
    }
}

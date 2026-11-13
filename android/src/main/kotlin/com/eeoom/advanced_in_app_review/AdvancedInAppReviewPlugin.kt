package com.eeoom.advanced_in_app_review

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

/** Native store operations. Completion does not prove the review UI appeared. */
class AdvancedInAppReviewPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    internal var activity: Activity? = null
    internal var managerFactory: (Context) -> ReviewManager = { ReviewManagerFactory.create(it) }
    private var pending: Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "advanced_in_app_review").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        failPending("engine_detached", "Flutter engine detached during review request.")
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        activity = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activity = null
        failPending("app_not_active", "Activity detached during review request.")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "isAvailable" -> result.success(storeAvailable())
            "requestReview" -> requestReview(result)
            "openStoreListing" -> openStoreListing(result)
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun storeAvailable(): Boolean {
        val appContext = context ?: activity?.applicationContext ?: return false
        return try {
            appContext.packageManager.getApplicationInfo("com.android.vending", 0).enabled
        } catch (_: PackageManager.NameNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun activeActivity(): Activity? = activity?.takeIf {
        !it.isFinishing && !it.isDestroyed && it.hasWindowFocus()
    }

    private fun requestReview(result: Result) {
        if (pending != null) {
            result.error("already_pending", "A review request is already running.", null)
            return
        }
        if (activeActivity() == null) {
            result.error("app_not_active", "A focused foreground Activity is required.", null)
            return
        }
        if (!storeAvailable()) {
            result.error("unavailable", "Google Play Store is not available.", null)
            return
        }
        pending = result
        try {
            val manager = managerFactory(context ?: activity!!.applicationContext)
            manager.requestReviewFlow().addOnCompleteListener { task ->
                if (pending !== result) return@addOnCompleteListener
                // The outer try cannot catch exceptions thrown by this callback.
                try {
                    val currentActivity = activeActivity()
                    if (currentActivity == null) {
                        finish(result, "app_not_active", "Activity is no longer active.")
                    } else if (!task.isSuccessful) {
                        finish(result, "request_failed", task.exception?.message ?: "Review request failed.")
                    } else {
                        manager.launchReviewFlow(currentActivity, task.result)
                            .addOnCompleteListener { flow ->
                                if (flow.isSuccessful) finish(result)
                                else finish(result, "request_failed", flow.exception?.message ?: "Review flow failed.")
                            }
                    }
                } catch (error: Exception) {
                    finish(result, "request_failed", error.message ?: "Could not launch review flow.")
                }
            }
        } catch (error: Exception) {
            finish(result, "request_failed", error.message ?: "Could not request review flow.")
        }
    }

    // Ignore late callbacks after detach; reply to every channel call only once.
    private fun finish(result: Result, code: String? = null, message: String? = null) {
        if (pending !== result) return
        pending = null
        if (code == null) result.success(null) else result.error(code, message, null)
    }

    private fun failPending(code: String, message: String) {
        pending?.let { finish(it, code, message) }
    }

    private fun openStoreListing(result: Result) {
        val currentActivity = activeActivity()
        if (currentActivity == null) {
            result.error("app_not_active", "A focused foreground Activity is required.", null)
            return
        }
        val packageName = currentActivity.packageName
        try {
            val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
                .setPackage("com.android.vending")
            try {
                currentActivity.startActivity(market)
            } catch (_: android.content.ActivityNotFoundException) {
                currentActivity.startActivity(Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$packageName")))
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("store_open_failed", error.message, null)
        }
    }
}

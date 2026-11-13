package com.eeoom.advanced_in_app_review

import android.app.Activity
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.tasks.Tasks
import com.google.android.play.core.review.ReviewInfo
import com.google.android.play.core.review.ReviewManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AdvancedInAppReviewPluginTest {
    class FocusedActivity : Activity() {
        override fun hasWindowFocus() = true
    }

    class Reply : MethodChannel.Result {
        var count = 0
        var code: String? = null
        var value: Any? = null
        override fun success(result: Any?) { count++; value = result }
        override fun error(errorCode: String, message: String?, details: Any?) {
            count++; code = errorCode
        }
        override fun notImplemented() { count++; code = "not_implemented" }
    }

    private lateinit var plugin: AdvancedInAppReviewPlugin
    private lateinit var manager: ReviewManager
    private lateinit var request: TaskCompletionSource<ReviewInfo>

    @Before fun setup() {
        val activity = Robolectric.buildActivity(FocusedActivity::class.java).setup().get()
        val info = PackageInfo().apply {
            packageName = "com.android.vending"
            applicationInfo = ApplicationInfo().apply { enabled = true }
        }
        shadowOf(activity.packageManager).installPackage(info)
        manager = mock(ReviewManager::class.java)
        request = TaskCompletionSource()
        `when`(manager.requestReviewFlow()).thenReturn(request.task)
        plugin = AdvancedInAppReviewPlugin().also {
            it.activity = activity
            it.managerFactory = { manager }
        }
    }

    private fun call(method: String): Reply = Reply().also {
        plugin.onMethodCall(MethodCall(method, null), it)
    }

    private fun finishRequest() {
        request.setResult(mock(ReviewInfo::class.java))
        shadowOf(android.os.Looper.getMainLooper()).idle()
    }

    @Test fun availabilityDoesNotRequestReviewInfo() {
        assertEquals(true, call("isAvailable").value)
        verifyNoInteractions(manager)
    }

    @Test fun backgroundedActivityIsRejected() {
        plugin.activity = null
        assertEquals("app_not_active", call("requestReview").code)
        verifyNoInteractions(manager)
    }

    @Test fun concurrentRequestIsRejected() {
        val first = call("requestReview")
        assertEquals("already_pending", call("requestReview").code)
        plugin.onDetachedFromActivity()
        assertEquals(1, first.count)
    }

    @Test fun detachRepliesOnceAndIgnoresLateCallback() {
        val reply = call("requestReview")
        plugin.onDetachedFromActivityForConfigChanges()
        finishRequest()
        assertEquals("app_not_active", reply.code)
        assertEquals(1, reply.count)
        verify(manager, never()).launchReviewFlow(any(), any())
    }

    @Test fun asynchronousLaunchExceptionsAreReported() {
        `when`(manager.launchReviewFlow(any(), any())).thenThrow(IllegalStateException("test"))
        val reply = call("requestReview")
        finishRequest()
        assertEquals("request_failed", reply.code)
        assertEquals(1, reply.count)
    }

    @Test fun successfulFlowRepliesExactlyOnce() {
        `when`(manager.launchReviewFlow(any(), any())).thenReturn(Tasks.forResult(null))
        val reply = call("requestReview")
        finishRequest()
        assertNull(reply.code)
        assertEquals(1, reply.count)
    }
}

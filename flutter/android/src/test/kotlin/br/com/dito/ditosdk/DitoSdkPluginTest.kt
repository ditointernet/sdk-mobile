package br.com.dito.ditosdk

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import org.mockito.Mockito

internal class DitoSdkPluginTest {
    @Test
    fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
        val plugin = DitoSdkPlugin()

        val call = MethodCall("getPlatformVersion", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
    }

    @Test
    fun onMethodCall_logout_callsNativeLogoutAndReturnsSuccess() {
        var logoutCalled = false
        val plugin = DitoSdkPlugin().apply {
            logoutHandler = { logoutCalled = true }
        }

        val call = MethodCall("logout", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        assertEquals(true, logoutCalled)
        Mockito.verify(mockResult).success(null)
    }

    @Test
    fun operationStatusMap_sent_returnsSentStatus() {
        val plugin = DitoSdkPlugin()

        val result = plugin.operationStatusMap(DitoOperationStatus.SENT)

        assertEquals(mapOf("status" to "sent"), result)
    }

    @Test
    fun operationStatusMap_savedLocally_returnsSavedLocallyStatus() {
        val plugin = DitoSdkPlugin()

        val result = plugin.operationStatusMap(DitoOperationStatus.SAVED_LOCALLY)

        assertEquals(mapOf("status" to "saved_locally"), result)
    }

    @Test
    fun requireOperationStatus_nullStatus_failsExplicitly() {
        val plugin = DitoSdkPlugin()

        assertFailsWith<IllegalArgumentException> {
            plugin.requireOperationStatus(null)
        }
    }
}

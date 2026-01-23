package br.com.dito.ditosdk

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.tracking.Tracker
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.lang.reflect.Field
import kotlin.test.assertFailsWith

@RunWith(RobolectricTestRunner::class)
class DitoTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        resetDitoState()
    }

    @After
    fun tearDown() {
        resetDitoState()
    }

    private fun resetDitoState() {
        try {
            val optionsField = Dito::class.java.getDeclaredField("options")
            optionsField.isAccessible = true
            optionsField.set(null, null)
        } catch (e: Exception) {
        }
    }

    @Test
    fun `init should throw exception when API_KEY is missing`() {
        val mockContext = mockk<Context>(relaxed = true)
        val mockPackageManager = mockk<PackageManager>(relaxed = true)
        val mockAppInfo = mockk<ApplicationInfo>(relaxed = true)
        val mockMetaData = android.os.Bundle().apply {
            putString("br.com.dito.API_SECRET", "secret")
        }

        every { mockContext.packageManager } returns mockPackageManager
        every { mockContext.packageName } returns "test.package"
        every { mockPackageManager.getApplicationInfo(any(), any()) } returns mockAppInfo
        mockAppInfo.metaData = mockMetaData

        assertFailsWith<RuntimeException> {
            Dito.init(mockContext, null)
        }
    }

    @Test
    fun `init should throw exception when API_SECRET is missing`() {
        val mockContext = mockk<Context>(relaxed = true)
        val mockPackageManager = mockk<PackageManager>(relaxed = true)
        val mockAppInfo = mockk<ApplicationInfo>(relaxed = true)
        val mockMetaData = android.os.Bundle().apply {
            putString("br.com.dito.API_KEY", "key")
        }

        every { mockContext.packageManager } returns mockPackageManager
        every { mockContext.packageName } returns "test.package"
        every { mockPackageManager.getApplicationInfo(any(), any()) } returns mockAppInfo
        mockAppInfo.metaData = mockMetaData

        assertFailsWith<RuntimeException> {
            Dito.init(mockContext, null)
        }
    }

    @Test
    fun `init should set options`() {
        val mockContext = mockk<Context>(relaxed = true)
        val mockPackageManager = mockk<PackageManager>(relaxed = true)
        val mockAppInfo = mockk<ApplicationInfo>(relaxed = true)
        val mockMetaData = android.os.Bundle().apply {
            putString("br.com.dito.API_KEY", "key")
            putString("br.com.dito.API_SECRET", "secret")
        }
        val options = Options(retry = 10)

        every { mockContext.packageManager } returns mockPackageManager
        every { mockContext.packageName } returns "test.package"
        every { mockPackageManager.getApplicationInfo(any(), any()) } returns mockAppInfo
        mockAppInfo.metaData = mockMetaData

        Dito.init(mockContext, options)

        assertThat(Dito.options).isEqualTo(options)
    }

    @Test
    fun `identify should create Identify object with all parameters`() = runBlocking {
        initializeDito()

        val customData = mapOf(
            "key1" to "value1",
            "key2" to 42,
            "key3" to 3.14,
            "key4" to true
        )

        Dito.identify("user123", "John Doe", "john@example.com", customData)

        delay(100)
    }

    @Test
    fun `identify should handle null parameters`() = runBlocking {
        initializeDito()

        Dito.identify("user123", null, null, null)

        delay(100)
    }

    @Test
    fun `identify should handle empty customData`() = runBlocking {
        initializeDito()

        Dito.identify("user123", "John", "john@example.com", emptyMap())

        delay(100)
    }

    @Test
    fun `track should create Event with action and data`() = runBlocking {
        initializeDito()

        val data = mapOf("product_id" to "123", "price" to 99.99)
        Dito.track("purchase", data)

        delay(100)
    }

    @Test
    fun `track should handle null data`() = runBlocking {
        initializeDito()

        Dito.track("view", null)

        delay(100)
    }

    @Test
    fun `registerDevice should not call API when token is null`() = runBlocking {
        initializeDito()

        Dito.registerDevice(null)

        delay(100)
    }

    @Test
    fun `registerDevice should not call API when token is empty`() = runBlocking {
        initializeDito()

        Dito.registerDevice("")

        delay(100)
    }

    @Test
    fun `registerDevice should call API with valid token`() = runBlocking {
        initializeDito()

        Dito.registerDevice("token123")

        delay(100)
    }

    @Test
    fun `unregisterDevice should not call API when token is null`() = runBlocking {
        initializeDito()

        Dito.unregisterDevice(null)

        delay(100)
    }

    @Test
    fun `unregisterDevice should not call API when token is empty`() = runBlocking {
        initializeDito()

        Dito.unregisterDevice("")

        delay(100)
    }

    @Test
    fun `unregisterDevice should call API with valid token`() = runBlocking {
        initializeDito()

        Dito.unregisterDevice("token123")

        delay(100)
    }

    @Test
    fun `notificationRead should process valid userInfo`() = runBlocking {
        initializeDito()

        val userInfo = mapOf(
            "notification" to "notif123",
            "reference" to "ref123",
            "log_id" to "log123",
            "notification_name" to "Test Notification",
            "user_id" to "user123"
        )

        Dito.notificationRead(userInfo)

        delay(100)
    }

    @Test
    fun `notificationRead should not process when reference is empty`() = runBlocking {
        initializeDito()

        val userInfo = mapOf(
            "notification" to "notif123",
            "reference" to ""
        )

        Dito.notificationRead(userInfo)

        delay(100)
    }

    @Test
    fun `notificationRead should not process when notification is empty`() = runBlocking {
        initializeDito()

        val userInfo = mapOf(
            "notification" to "",
            "reference" to "ref123"
        )

        Dito.notificationRead(userInfo)

        delay(100)
    }

    @Test
    fun `notificationClick should return NotificationResult`() = runBlocking {
        initializeDito()

        val userInfo = mapOf(
            "notification" to "notif123",
            "reference" to "ref123",
            "deeplink" to "https://example.com"
        )
        var callbackInvoked = false

        val result = Dito.notificationClick(userInfo) { deepLink ->
            callbackInvoked = true
            assertThat(deepLink).isEqualTo("https://example.com")
        }

        delay(100)
        assertThat(result.notificationId).isEqualTo("notif123")
        assertThat(result.reference).isEqualTo("ref123")
        assertThat(result.deepLink).isEqualTo("https://example.com")
        assertThat(callbackInvoked).isTrue()
    }

    @Test
    fun `notificationClick should handle null callback`() = runBlocking {
        initializeDito()

        val userInfo = mapOf(
            "notification" to "notif123",
            "reference" to "ref123",
            "deeplink" to "https://example.com"
        )

        val result = Dito.notificationClick(userInfo, null)

        assertThat(result.notificationId).isEqualTo("notif123")
        assertThat(result.reference).isEqualTo("ref123")
    }

    @Test
    fun `notificationClick should handle missing deeplink`() = runBlocking {
        initializeDito()

        val userInfo = mapOf(
            "notification" to "notif123",
            "reference" to "ref123"
        )

        val result = Dito.notificationClick(userInfo)

        assertThat(result.deepLink).isEmpty()
    }

    @Test
    fun `isInitialized should return false when not initialized`() {
        resetDitoState()
        assertThat(Dito.isInitialized()).isFalse()
    }

    @Test
    fun `getHibridMode should return default value`() {
        val mockContext = mockk<Context>(relaxed = true)
        val mockPackageManager = mockk<PackageManager>(relaxed = true)
        val mockAppInfo = mockk<ApplicationInfo>(relaxed = true)
        val mockMetaData = android.os.Bundle().apply {
            putString("br.com.dito.API_KEY", "key")
            putString("br.com.dito.API_SECRET", "secret")
            putString("br.com.dito.HIBRID_MODE", "ON")
        }

        every { mockContext.packageManager } returns mockPackageManager
        every { mockContext.packageName } returns "test.package"
        every { mockPackageManager.getApplicationInfo(any(), any()) } returns mockAppInfo
        mockAppInfo.metaData = mockMetaData

        Dito.init(mockContext, null)

        assertThat(Dito.getHibridMode()).isEqualTo("ON")
    }

    @Test
    fun `deprecated notificationRead should process valid parameters`() = runBlocking {
        initializeDito()

        Dito.notificationRead("notif123", "ref123")

        delay(100)
    }

    @Test
    fun `deprecated notificationRead should not process null parameters`() = runBlocking {
        initializeDito()

        Dito.notificationRead(null, null)

        delay(100)
    }

    @Test
    fun `deprecated track should process Event object`() = runBlocking {
        initializeDito()

        val event = Event("purchase")
        Dito.track(event)

        delay(100)
    }

    @Test
    fun `deprecated identify should process Identify object`() = runBlocking {
        initializeDito()

        val identify = Identify("user123").apply {
            name = "John"
            email = "john@example.com"
        }
        var callbackInvoked = false

        Dito.identify(identify) {
            callbackInvoked = true
        }

        delay(100)
    }

    @Test
    fun `convertCustomData should handle different value types`() {
        initializeDito()

        val customData = mapOf(
            "string" to "value",
            "int" to 42,
            "double" to 3.14,
            "boolean" to true,
            "other" to listOf(1, 2, 3)
        )

        Dito.identify("user123", null, null, customData)

        delay(100)
    }

    private fun initializeDito() {
        val mockContext = mockk<Context>(relaxed = true)
        val mockPackageManager = mockk<PackageManager>(relaxed = true)
        val mockAppInfo = mockk<ApplicationInfo>(relaxed = true)
        val mockMetaData = android.os.Bundle().apply {
            putString("br.com.dito.API_KEY", "test_key")
            putString("br.com.dito.API_SECRET", "test_secret")
        }

        every { mockContext.packageManager } returns mockPackageManager
        every { mockContext.packageName } returns "test.package"
        every { mockPackageManager.getApplicationInfo(any(), any()) } returns mockAppInfo
        mockAppInfo.metaData = mockMetaData

        Dito.init(mockContext, Options())
    }
}

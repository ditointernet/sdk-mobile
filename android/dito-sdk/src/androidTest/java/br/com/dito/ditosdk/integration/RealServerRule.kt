package br.com.dito.ditosdk.integration

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.Options
import java.util.UUID
import org.junit.rules.ExternalResource

internal class RealServerRule(
    private val interceptor: ProdHttpInterceptor? = null,
) : ExternalResource() {
    lateinit var userId: String
        private set

    override fun before() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        val opts = interceptor?.let {
            Options(httpClientBuilder = { addInterceptor(it) })
        }
        if (opts != null) Dito.init(ctx, TestConfig.API_KEY, TestConfig.API_SECRET, opts)
        else Dito.init(ctx, TestConfig.API_KEY, TestConfig.API_SECRET)
        userId = "test-android-${UUID.randomUUID()}"
        Thread.sleep(500)
    }

    override fun after() {
        Dito.init(ApplicationProvider.getApplicationContext(), TestConfig.API_KEY, TestConfig.API_SECRET)
    }
}

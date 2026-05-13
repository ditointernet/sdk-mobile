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
        initDito(ctx, optionsForInterceptor())
        userId = "test-android-${UUID.randomUUID()}"
        Thread.sleep(500)
    }

    override fun after() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        initDito(ctx, optionsForInterceptor())
    }

    private fun optionsForInterceptor(): Options? =
        interceptor?.let { Options(httpClientBuilder = { addInterceptor(it) }) }

    private fun initDito(ctx: Context, opts: Options?) {
        val secretTrimmed = TestConfig.API_SECRET.trim()
        if (secretTrimmed.isNotEmpty()) {
            if (opts != null) {
                Dito.init(ctx, TestConfig.API_KEY, secretTrimmed, opts)
            } else {
                Dito.init(ctx, TestConfig.API_KEY, secretTrimmed)
            }
        } else {
            if (opts != null) {
                Dito.init(ctx, TestConfig.X_API_KEY, "", opts)
            } else {
                Dito.init(ctx, TestConfig.X_API_KEY, "")
            }
        }
    }
}

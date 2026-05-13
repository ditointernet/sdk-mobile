package br.com.dito.ditosdk.integration

internal class ProdHttpInterceptor : okhttp3.Interceptor {
    private val responses = mutableListOf<Int>()
    private val lock = Any()

    override fun intercept(chain: okhttp3.Interceptor.Chain): okhttp3.Response {
        val response = chain.proceed(chain.request())
        synchronized(lock) { responses.add(response.code) }
        return response
    }

    fun lastCode(): Int = synchronized(lock) { responses.lastOrNull() ?: -1 }
    fun allCodes(): List<Int> = synchronized(lock) { responses.toList() }
    fun reset() = synchronized(lock) { responses.clear() }
}

package br.com.dito.ditosdk.tracking

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal class ConnectivityRetryTrigger(
    private val context: Context,
    /** `validated = false`: rede que não validou na carência; o reenvio deve respeitar a espera de falha. */
    private val onReconnect: (validated: Boolean) -> Unit,
    private val debounceMs: Long = 2_000,
    injectedScope: CoroutineScope? = null,
    private val unvalidatedGraceMs: Long = UNVALIDATED_GRACE_MS,
) {

    private val ownsScope = injectedScope == null
    internal val scope: CoroutineScope = injectedScope ?: CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val lock = Any()
    private var connectivityManager: ConnectivityManager? = null
    private var lastNetwork: Network? = null
    private var lastValidated = false

    // Rede sem validação que conta como online: a que não validou na carência ou já estava ativa no
    // start. A que perdeu a validação não conta: é tratada como queda.
    private var unvalidatedReady = false
    private var observing = false
    private var pending: Job? = null
    private var closed = false

    // Entrega inicial da rede já ativa (pode chegar dentro do registro): o configure já fez o flush.
    private var firstReadPending = true

    // Rede validada dispara depois do debounce. Rede nova com internet mas sem validação (VPN, rede
    // corporativa, teste de conectividade do Google bloqueado) pode nunca validar: dispara depois de
    // uma espera maior, que a validação, se vier, encurta. Portal cativo não conta como internet.
    // Perder a validação sem onLost (roteador sem internet, Wi-Fi conectado) conta como queda: não
    // dispara, e a volta da validação dispara. Qualquer rede padrão nova dispara, inclusive a troca
    // Wi-Fi → dados sem onLost da antiga.
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            // O callback é da rede padrão: a nova sem internet (portal cativo) derruba a anterior.
            if (!hasInternet(capabilities)) return onLost(lastNetwork ?: network)
            val validated = isValidated(capabilities)
            synchronized(lock) {
                if (closed) return
                val sameNetwork = network == lastNetwork
                if (sameNetwork && validated == lastValidated) return
                lastNetwork = network
                lastValidated = validated
                unvalidatedReady = firstReadPending
                if (firstReadPending) {
                    firstReadPending = false
                    return
                }
                when {
                    validated -> schedule(debounceMs, validated = true)
                    sameNetwork -> pending?.cancel()
                    else -> schedule(unvalidatedGraceMs, validated = false)
                }
            }
        }

        override fun onLost(network: Network) {
            synchronized(lock) {
                if (network != lastNetwork) return
                lastNetwork = null
                lastValidated = false
                unvalidatedReady = false
                pending?.cancel()
            }
        }
    }

    fun start() {
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (cm == null) {
                Log.w("ConnectivityRetry", "ConnectivityManager indisponível; sem reenvio ao voltar a rede.")
                return
            }
            // Registrar antes de ler a rede atual: uma queda e volta entre as duas não passa despercebida.
            cm.registerDefaultNetworkCallback(callback)
            connectivityManager = cm
            // O registro reentrega a rede já ativa: o configure já fez o flush, então ela não dispara.
            val active = cm.activeNetwork
            val capabilities = active?.let { cm.getNetworkCapabilities(it) }
            synchronized(lock) {
                if (firstReadPending && hasInternet(capabilities)) {
                    lastNetwork = active
                    lastValidated = isValidated(capabilities)
                    unvalidatedReady = true
                }
                firstReadPending = false
                observing = true
            }
        } catch (e: Exception) {
            Log.w("ConnectivityRetry", "Falha ao observar a rede; sem reenvio ao voltar a rede.", e)
        }
    }

    /**
     * Mesmo critério do gatilho: rede validada, ou sem validação depois da carência (VPN, rede
     * corporativa). Rede que perdeu a validação e portal cativo contam como sem rede. Sem observar a
     * rede (antes do start ou se o registro falhou), `true`: o envio decide.
     */
    fun isOnline(): Boolean = synchronized(lock) { !observing || lastValidated || unvalidatedReady }

    fun close() {
        synchronized(lock) {
            closed = true
            pending?.cancel()
        }
        try {
            connectivityManager?.unregisterNetworkCallback(callback)
        } catch (e: Exception) {
            Log.w("ConnectivityRetry", "Falha ao desregistrar o callback de rede.", e)
        }
        connectivityManager = null
        if (ownsScope) scope.cancel()
    }

    companion object {
        /** Espera por uma rede com internet que não validou antes de reenviar mesmo assim. */
        internal const val UNVALIDATED_GRACE_MS = 30_000L

        private fun hasInternet(capabilities: NetworkCapabilities?): Boolean =
            capabilities != null &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)

        private fun isValidated(capabilities: NetworkCapabilities?): Boolean =
            capabilities != null &&
                hasInternet(capabilities) &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    /** Com [lock]. */
    private fun schedule(delayMs: Long, validated: Boolean) {
        pending?.cancel()
        pending = scope.launch {
            delay(delayMs)
            // Cancelado depois do delay (rede mudou): não mexe no estado da rede nova.
            val current = synchronized(lock) {
                (pending === coroutineContext[Job]).also { if (it && !validated) unvalidatedReady = true }
            }
            if (current) onReconnect(validated)
        }
    }
}

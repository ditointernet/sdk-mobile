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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

internal class ConnectivityRetryTrigger(
    private val context: Context,
    private val onReconnect: () -> Unit,
    private val debounceMs: Long = 2_000,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob()),
) {

    private val lock = Any()
    private var connectivityManager: ConnectivityManager? = null
    private var lastValidated: Network? = null
    private var pending: Job? = null
    private var closed = false

    // Só rede validada dispara: onAvailable chega antes (portal cativo, Wi-Fi sem internet) e cada
    // passada que falha gasta uma das tentativas da fila. Qualquer rede padrão nova dispara, inclusive
    // a troca Wi-Fi → dados sem onLost da antiga.
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            // Perder a validação sem onLost (roteador sem internet, Wi-Fi conectado) conta como queda.
            if (!isValidated(capabilities)) return onLost(network)
            synchronized(lock) {
                if (network == lastValidated || closed) return
                lastValidated = network
                schedule()
            }
        }

        override fun onLost(network: Network) {
            synchronized(lock) {
                if (network != lastValidated) return
                lastValidated = null
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
            // O registro reentrega a rede já ativa: o configure já fez o flush, então ela não dispara.
            val active = cm.activeNetwork?.takeIf { isValidated(cm.getNetworkCapabilities(it)) }
            synchronized(lock) { lastValidated = active }
            cm.registerDefaultNetworkCallback(callback)
            connectivityManager = cm
        } catch (e: Exception) {
            Log.w("ConnectivityRetry", "Falha ao observar a rede; sem reenvio ao voltar a rede.", e)
        }
    }

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
    }

    private fun isValidated(capabilities: NetworkCapabilities?): Boolean =
        capabilities != null &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

    private fun schedule() {
        pending?.cancel()
        pending = scope.launch {
            delay(debounceMs)
            onReconnect()
        }
    }
}

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
    private val onReconnect: () -> Unit,
    private val debounceMs: Long = 2_000,
    injectedScope: CoroutineScope? = null,
) {

    private val ownsScope = injectedScope == null
    internal val scope: CoroutineScope = injectedScope ?: CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val lock = Any()
    private var connectivityManager: ConnectivityManager? = null
    private var lastValidated: Network? = null
    private var pending: Job? = null
    private var closed = false

    // Entrega inicial da rede já ativa (pode chegar dentro do registro): o configure já fez o flush.
    private var firstReadPending = true

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
                if (firstReadPending) {
                    firstReadPending = false
                    return
                }
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
            // Registrar antes de ler a rede atual: uma queda e volta entre as duas não passa despercebida.
            cm.registerDefaultNetworkCallback(callback)
            connectivityManager = cm
            // O registro reentrega a rede já ativa: o configure já fez o flush, então ela não dispara.
            val active = cm.activeNetwork?.takeIf { isValidated(cm.getNetworkCapabilities(it)) }
            synchronized(lock) {
                if (firstReadPending) lastValidated = active
                firstReadPending = false
            }
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
        if (ownsScope) scope.cancel()
    }

    companion object {
        private fun isValidated(capabilities: NetworkCapabilities?): Boolean =
            capabilities != null &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

        /** Há rede padrão validada agora; sem como saber, `true` (o envio decide). */
        fun isOnline(context: Context): Boolean =
            try {
                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                cm == null || isValidated(cm.getNetworkCapabilities(cm.activeNetwork))
            } catch (e: Exception) {
                true
            }
    }

    private fun schedule() {
        pending?.cancel()
        pending = scope.launch {
            delay(debounceMs)
            onReconnect()
        }
    }
}

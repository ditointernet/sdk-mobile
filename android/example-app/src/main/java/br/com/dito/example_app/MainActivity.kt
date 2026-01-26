package br.com.dito.example_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import br.com.dito.ditosdk.Dito
import br.com.dito.example_app.databinding.ActivityMainBinding
import com.google.firebase.messaging.FirebaseMessaging
import org.json.JSONObject
import java.security.MessageDigest

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val env = mutableMapOf<String, String>()
    private var token: String = ""

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            Log.d("DitoExample", "✅ Permissão de notificação concedida")
            showToast("Permissão de notificação concedida")
        } else {
            Log.w("DitoExample", "❌ Permissão de notificação negada")
            showToast("Permissão de notificação negada - notificações não serão exibidas")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        WindowCompat.setDecorFitsSystemWindows(window, true)
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController.show(WindowInsetsCompat.Type.systemBars())

        requestNotificationPermission()
        setupFcmToken()
        loadEnvValues()
        setupClickListeners()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            when {
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED -> {
                    Log.d("DitoExample", "✅ Permissão de notificação já concedida")
                }
                shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) -> {
                    Log.d("DitoExample", "⚠️ Mostrando justificativa para permissão de notificação")
                    showToast("Este app precisa de permissão para exibir notificações")
                    requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
                else -> {
                    Log.d("DitoExample", "📱 Solicitando permissão de notificação")
                    requestPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        } else {
            Log.d("DitoExample", "✅ Android < 13, permissão não necessária")
        }
    }

    private fun loadEnvValues() {
        env.putAll(EnvLoader.loadEnv(this))

        val bytes = env["IDENTIFY_EMAIL"].toString().toByteArray(Charsets.UTF_8)
        val md = MessageDigest.getInstance("SHA-1")
        val digest = md.digest(bytes)
        binding.editIdentifyId.setText(digest.joinToString("") { "%02x".format(it) })
        binding.editIdentifyName.setText(env["IDENTIFY_NAME"] ?: "")
        binding.editIdentifyEmail.setText(env["IDENTIFY_EMAIL"] ?: "")
        binding.editIdentifyCustomData.setText(env["IDENTIFY_CUSTOM_DATA"] ?: "{}")

        binding.editTrackAction.setText(env["TRACK_ACTION"] ?: "")
        binding.editTrackData.setText(env["TRACK_DATA"] ?: "{}")

        binding.editRegisterToken.setText(this.token)
        binding.editUnregisterToken.setText(this.token)
    }

    private fun setupClickListeners() {
        binding.buttonTestIdentify.setOnClickListener {
            testIdentify()
        }

        binding.buttonTestTrack.setOnClickListener {
            testTrack()
        }

        binding.buttonTestRegisterDevice.setOnClickListener {
            testRegisterDevice()
        }

        binding.buttonTestUnregisterDevice.setOnClickListener {
            testUnregisterDevice()
        }

        binding.buttonTestAll.setOnClickListener {
            testAll()
        }

        binding.buttonGetFcmToken.setOnClickListener {
            getFcmToken()
        }

        binding.buttonNotificationDebug.setOnClickListener {
            startActivity(Intent(this, NotificationDebugActivity::class.java))
        }
    }

    private fun setupFcmToken() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.w("DitoExample", "Falha ao obter token FCM", task.exception)
                binding.textFcmToken.text = "Token FCM: Erro ao obter token"
                return@addOnCompleteListener
            }

            this.token = task.result
            Log.d("DitoExample", "Token FCM obtido: $token")
            binding.textFcmToken.text = "Token FCM: $token"

            if (binding.editRegisterToken.text.toString().isEmpty()) {
                binding.editRegisterToken.setText(token)
            }
        }
    }

    private fun getFcmToken() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (!task.isSuccessful) {
                Log.w("DitoExample", "Falha ao obter token FCM", task.exception)
                showToast("Erro ao obter token FCM: ${task.exception?.message}")
                binding.textFcmToken.text = "Token FCM: Erro ao obter token"
                return@addOnCompleteListener
            }

            this.token = task.result
            Log.d("DitoExample", "Token FCM obtido: $token")
            binding.textFcmToken.text = "Token FCM: $token"
            binding.editRegisterToken.setText(token)
            showToast("Token FCM obtido e preenchido no campo Register Token")
        }
    }

    private fun testIdentify() {
        val id = binding.editIdentifyId.text.toString().trim()
        if (id.isEmpty()) {
            showToast("ID é obrigatório para identify")
            return
        }

        val name = binding.editIdentifyName.text.toString().trim()
        val email = binding.editIdentifyEmail.text.toString().trim()
        val customDataJson = binding.editIdentifyCustomData.text.toString().trim()

        val customData = parseJsonToMap(customDataJson)
        if (customDataJson.isNotEmpty() && customData == null) {
            showToast("customData JSON inválido")
            return
        }

        try {
            Dito.identify(
                id = id,
                name = name.ifEmpty { null },
                email = email.ifEmpty { null },
                customData = customData
            )

            Log.d("DitoExample", "Identify: id=$id, name=$name, email=$email, customData=$customData")
        } catch (e: Exception) {
            showToast("Erro ao executar identify: ${e.message}")
            Log.e("DitoExample", "Erro ao executar identify", e)
        }
    }

    private fun testTrack() {
        val action = binding.editTrackAction.text.toString().trim()
        if (action.isEmpty()) {
            showToast("Action é obrigatório para track")
            return
        }

        val dataJson = binding.editTrackData.text.toString().trim()
        val data = parseJsonToMap(dataJson)
        if (dataJson.isNotEmpty() && data == null) {
            showToast("data JSON inválido")
            return
        }

        try {
            Dito.track(action = action, data = data)
            showToast("Track executado com sucesso")
            Log.d("DitoExample", "Track: action=$action, data=$data")
        } catch (e: Exception) {
            showToast("Erro ao executar track: ${e.message}")
            Log.e("DitoExample", "Erro ao executar track", e)
        }
    }

    private fun testRegisterDevice() {
        val token = binding.editRegisterToken.text.toString().trim()
        if (token.isEmpty()) {
            showToast("Token é obrigatório para registerDevice")
            return
        }

        try {
            Dito.registerDevice(token)
            showToast("RegisterDevice executado com sucesso")
            Log.d("DitoExample", "RegisterDevice: token=$token")
        } catch (e: Exception) {
            showToast("Erro ao executar registerDevice: ${e.message}")
            Log.e("DitoExample", "Erro ao executar registerDevice", e)
        }
    }

    private fun testUnregisterDevice() {
        val token = binding.editUnregisterToken.text.toString().trim()
        if (token.isEmpty()) {
            showToast("Token é obrigatório para unregisterDevice")
            return
        }

        try {
            Dito.unregisterDevice(token)
            showToast("UnregisterDevice executado com sucesso")
            Log.d("DitoExample", "UnregisterDevice: token=$token")
        } catch (e: Exception) {
            showToast("Erro ao executar unregisterDevice: ${e.message}")
            Log.e("DitoExample", "Erro ao executar unregisterDevice", e)
        }
    }

    private fun testAll() {
        val env = EnvLoader.loadEnv(this)
        val apiKey = env["API_KEY"] ?: ""
        val apiSecret = env["API_SECRET"] ?: ""

        if (apiKey.isEmpty() || apiSecret.isEmpty()) {
            showToast("SDK não está inicializado (verifique API_KEY e API_SECRET no .env)")
            return
        }

        var successCount = 0
        var errorCount = 0

        val id = binding.editIdentifyId.text.toString().trim()
        if (id.isNotEmpty()) {
            try {
                val name = binding.editIdentifyName.text.toString().trim()
                val email = binding.editIdentifyEmail.text.toString().trim()
                val customDataJson = binding.editIdentifyCustomData.text.toString().trim()
                val customData = parseJsonToMap(customDataJson)

                Dito.identify(
                    id = id,
                    name = name.ifEmpty { null },
                    email = email.ifEmpty { null },
                    customData = customData
                )
                successCount++
                Log.d("DitoExample", "Identify executado")
            } catch (e: Exception) {
                errorCount++
                Log.e("DitoExample", "Erro ao executar identify", e)
            }
        }

        val action = binding.editTrackAction.text.toString().trim()
        if (action.isNotEmpty()) {
            try {
                val dataJson = binding.editTrackData.text.toString().trim()
                val data = parseJsonToMap(dataJson)
                Dito.track(action = action, data = data)
                successCount++
                Log.d("DitoExample", "Track executado")
            } catch (e: Exception) {
                errorCount++
                Log.e("DitoExample", "Erro ao executar track", e)
            }
        }

        val registerToken = binding.editRegisterToken.text.toString().trim()
        if (registerToken.isNotEmpty()) {
            try {
                Dito.registerDevice(registerToken)
                successCount++
                Log.d("DitoExample", "RegisterDevice executado")
            } catch (e: Exception) {
                errorCount++
                Log.e("DitoExample", "Erro ao executar registerDevice", e)
            }
        }

        val unregisterToken = binding.editUnregisterToken.text.toString().trim()
        if (unregisterToken.isNotEmpty()) {
            try {
                Dito.unregisterDevice(unregisterToken)
                successCount++
                Log.d("DitoExample", "UnregisterDevice executado")
            } catch (e: Exception) {
                errorCount++
                Log.e("DitoExample", "Erro ao executar unregisterDevice", e)
            }
        }

        val message = "Testes executados: $successCount sucesso, $errorCount erros"
        showToast(message)
        Log.d("DitoExample", message)
    }

    private fun parseJsonToMap(jsonString: String): Map<String, Any>? {
        if (jsonString.isEmpty()) {
            return null
        }

        return try {
            val jsonObject = JSONObject(jsonString)
            val map = mutableMapOf<String, Any>()
            val keys = jsonObject.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value = jsonObject.get(key)
                when (value) {
                    is String -> map[key] = value
                    is Int -> map[key] = value
                    is Double -> map[key] = value
                    is Boolean -> map[key] = value
                    else -> map[key] = value.toString()
                }
            }
            map
        } catch (e: Exception) {
            Log.e("DitoExample", "Erro ao parsear JSON: ${e.message}", e)
            null
        }
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
}

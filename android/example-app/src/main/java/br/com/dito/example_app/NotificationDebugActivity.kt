package br.com.dito.example_app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import br.com.dito.ditosdk.Dito
import br.com.dito.ditosdk.notification.DitoMessagingService
import br.com.dito.example_app.databinding.ActivityNotificationDebugBinding
import com.google.firebase.messaging.RemoteMessage
import java.io.File

class NotificationDebugActivity : AppCompatActivity() {

    private lateinit var binding: ActivityNotificationDebugBinding
    private val notificationFiles = mutableListOf<File>()
    private var currentJsonContent = ""

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityNotificationDebugBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupRecyclerView()
        loadNotificationFiles()
        setupClickListeners()
    }

    private fun setupRecyclerView() {
        binding.recyclerViewNotifications.layoutManager = LinearLayoutManager(this)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun loadNotificationFiles() {
        notificationFiles.clear()
        notificationFiles.addAll(NotificationDebugHelper.getAllNotificationFiles(this))

        val adapter = NotificationFileAdapter(notificationFiles) { file ->
            showNotificationDetails(file)
        }
        binding.recyclerViewNotifications.adapter = adapter

        binding.textNotificationCount.text = "Total de notificações salvas: ${notificationFiles.size}"
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun showNotificationDetails(file: File) {
        val content = NotificationDebugHelper.readNotificationPayload(file)
        currentJsonContent = content
        binding.textNotificationContent.text = content

        binding.buttonSimulate.isEnabled = true
        binding.buttonSimulate.setOnClickListener {
            simulateNotification(content)
        }

        binding.buttonCopyJson.isEnabled = true
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun simulateNotification(jsonPayload: String) {
        try {
            val remoteMessage = NotificationDebugHelper.simulateNotification(this, jsonPayload)
            if (remoteMessage != null) {
                val service = DitoMessagingService()
                service.onMessageReceived(remoteMessage)

                Toast.makeText(this, "Notificação simulada com sucesso!", Toast.LENGTH_SHORT).show()
                Log.d("NotificationDebug", "Notification simulated successfully")
            } else {
                Toast.makeText(this, "Erro ao simular notificação", Toast.LENGTH_SHORT).show()
                Log.e("NotificationDebug", "Failed to create RemoteMessage from payload")
            }
        } catch (e: Exception) {
            Toast.makeText(this, "Erro: ${e.message}", Toast.LENGTH_LONG).show()
            Log.e("NotificationDebug", "Error simulating notification", e)
        }
    }

    private fun setupClickListeners() {
        binding.buttonRefresh.setOnClickListener {
            loadNotificationFiles()
            Toast.makeText(this, "Lista atualizada", Toast.LENGTH_SHORT).show()
        }

        binding.buttonLatest.setOnClickListener {
            val latestFile = NotificationDebugHelper.getLatestNotificationFile(this)
            if (latestFile != null) {
                showNotificationDetails(latestFile)
            } else {
                Toast.makeText(this, "Nenhuma notificação salva", Toast.LENGTH_SHORT).show()
            }
        }

        binding.buttonCopyJson.setOnClickListener {
            copyJsonToClipboard()
        }

        binding.buttonSimulate.isEnabled = false
        binding.buttonCopyJson.isEnabled = false
    }

    private fun copyJsonToClipboard() {
        if (currentJsonContent.isEmpty()) {
            Toast.makeText(this, "Nenhum conteúdo para copiar", Toast.LENGTH_SHORT).show()
            return
        }

        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Notification JSON", currentJsonContent)
        clipboard.setPrimaryClip(clip)

        Toast.makeText(this, "JSON copiado para o clipboard!", Toast.LENGTH_SHORT).show()
        Log.d("NotificationDebug", "JSON copied to clipboard")
    }
}

class NotificationFileAdapter(
    private val files: List<File>,
    private val onFileClick: (File) -> Unit
) : RecyclerView.Adapter<NotificationFileAdapter.ViewHolder>() {

    class ViewHolder(val view: android.view.View) : RecyclerView.ViewHolder(view) {
        val textFileName: android.widget.TextView = view.findViewById(android.R.id.text1)
    }

    override fun onCreateViewHolder(parent: android.view.ViewGroup, viewType: Int): ViewHolder {
        val view = android.view.LayoutInflater.from(parent.context)
            .inflate(android.R.layout.simple_list_item_1, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val file = files[position]
        holder.textFileName.text = file.name
        holder.view.setOnClickListener { onFileClick(file) }
    }

    override fun getItemCount() = files.size
}

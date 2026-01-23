package br.com.dito.example

import android.content.Context
import java.io.InputStream

object EnvLoader {
    fun loadEnv(context: Context): Map<String, String> {
        val env = mutableMapOf<String, String>()

        return try {
            val inputStream: InputStream = context.assets.open(".env.development.local")
            val content = inputStream.bufferedReader().use { it.readText() }

            content.lines().forEach { line ->
                val trimmed = line.trim()
                if (trimmed.isNotEmpty() && !trimmed.startsWith("#")) {
                    val parts = trimmed.split("=", limit = 2)
                    if (parts.size == 2) {
                        val key = parts[0].trim()
                        val value = parts[1].trim()
                        env[key] = value
                    }
                }
            }

            env
        } catch (e: Exception) {
            println("Warning: Could not load .env.development.local: ${e.message}")
            env
        }
    }
}

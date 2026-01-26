package br.com.dito.example_app

import android.content.Context
import java.io.InputStream

object EnvLoader {
    fun loadEnv(context: Context): Map<String, String> {
        val env = mutableMapOf<String, String>()

        val content = tryLoadFromAssets(context) ?: tryLoadFromRaw(context)

        if (content != null) {
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
            println("✓ .env.development.local carregado com sucesso (${env.size} variáveis)")
        } else {
            println("⚠️ ERRO: Arquivo .env.development.local não encontrado no APK!")
            println("⚠️ Tentado em: assets/ e res/raw/")
            println("⚠️ Solução: No Android Studio, faça:")
            println("⚠️   1. Build > Clean Project")
            println("⚠️   2. Build > Rebuild Project")
            println("⚠️   3. Execute o app novamente")
        }

        return env
    }

    private fun tryLoadFromAssets(context: Context): String? {
        return try {
            val inputStream: InputStream = context.assets.open(".env.development.local")
            val content = inputStream.bufferedReader().use { it.readText() }
            println("✓ Arquivo carregado de: assets/.env.development.local")
            content
        } catch (e: java.io.FileNotFoundException) {
            println("ℹ️ Arquivo não encontrado em assets/, tentando res/raw/...")
            null
        } catch (e: Exception) {
            println("⚠️ Erro ao ler de assets/: ${e.message}")
            null
        }
    }

    private fun tryLoadFromRaw(context: Context): String? {
        return try {
            val resourceId = context.resources.getIdentifier(
                "env_development_local",
                "raw",
                context.packageName
            )
            if (resourceId == 0) {
                println("⚠️ Arquivo não encontrado em res/raw/")
                return null
            }
            val inputStream = context.resources.openRawResource(resourceId)
            val content = inputStream.bufferedReader().use { it.readText() }
            println("✓ Arquivo carregado de: res/raw/env_development_local.txt")
            content
        } catch (e: Exception) {
            println("⚠️ Erro ao ler de res/raw/: ${e.message}")
            null
        }
    }
}

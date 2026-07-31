import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.dito.example.sample_application"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.com.dito.example.sample_application"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }

        // O Dart lê as credenciais de `.env.development.local` (lib/env_loader.dart). O lado
        // nativo tem de sair da **mesma** fonte: se as duas metades autenticarem com chaves
        // diferentes, o app aberto funciona e só o clique em processo novo falha — porque é
        // ele que depende do manifest, e não do que o Dart inicializou.
        val dartEnv = Properties()
        val dartEnvFile = rootProject.file("../.env.development.local")
        if (dartEnvFile.exists()) {
            dartEnvFile.inputStream().use { dartEnv.load(it) }
        }

        // Vazio conta como ausente. Sem isso, um `export DITO_API_KEY=` no shell vence o
        // arquivo e o placeholder resolve para string vazia — que o merge aceita sem erro.
        fun resolve(vararg candidates: String?): String =
            candidates.firstOrNull { !it.isNullOrBlank() }?.trim()?.trim('"', '\'') ?: ""

        val ditoApiKey = resolve(
            System.getenv("DITO_API_KEY"),
            localProperties.getProperty("DITO_API_KEY"),
            dartEnv.getProperty("API_KEY"),
        )
        val ditoApiSecret = resolve(
            System.getenv("DITO_API_SECRET"),
            localProperties.getProperty("DITO_API_SECRET"),
            dartEnv.getProperty("API_SECRET"),
        )

        // Falhar aqui é mais barato que descobrir no clique. O build passava com placeholder
        // vazio e o sintoma aparecia só depois de matar o app e tocar na notificação.
        if (ditoApiKey.isBlank()) {
            throw GradleException(
                "Credencial da Dito não encontrada. Defina API_KEY em " +
                    "${dartEnvFile.path} (mesma fonte do Dart), ou DITO_API_KEY em " +
                    "local.properties ou no ambiente.",
            )
        }

        manifestPlaceholders["DITO_API_KEY"] = ditoApiKey
        manifestPlaceholders["DITO_API_SECRET"] = ditoApiSecret
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}

flutter {
    source = "../.."
}

import java.io.File
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

        val dotEnv = loadDotEnv(File(rootProject.projectDir.parentFile, ".env.development.local"))
        val ditoApiKey = listOfNotNull(
            System.getenv("DITO_API_KEY"),
            localProperties.getProperty("DITO_API_KEY"),
            dotEnv["DITO_API_KEY"],
            dotEnv["API_KEY"],
        ).firstOrNull { it.isNotBlank() }?.trim() ?: ""
        val ditoApiSecret = listOfNotNull(
            System.getenv("DITO_API_SECRET"),
            localProperties.getProperty("DITO_API_SECRET"),
            dotEnv["DITO_API_SECRET"],
            dotEnv["API_SECRET"],
        ).firstOrNull { it.isNotBlank() }?.trim() ?: ""

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

fun loadDotEnv(file: File): Map<String, String> {
    if (!file.exists()) return emptyMap()
    return buildMap {
        file.readLines().forEach { line ->
            val trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) return@forEach
            val eq = trimmed.indexOf('=')
            if (eq <= 0) return@forEach
            val key = trimmed.substring(0, eq).trim()
            var value = trimmed.substring(eq + 1).trim()
            if (value.length >= 2) {
                val q0 = value.first()
                val q1 = value.last()
                if ((q0 == '"' && q1 == '"') || (q0 == '\'' && q1 == '\'')) {
                    value = value.substring(1, value.length - 1)
                }
            }
            put(key, value)
        }
    }
}

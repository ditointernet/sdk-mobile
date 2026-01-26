plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.jetbrains.kotlin.android)
    id("com.google.gms.google-services")
}

fun loadEnvFile(): Map<String, String> {
    val envFile = file("src/main/assets/.env.development.local")
    val env = mutableMapOf<String, String>()
    if (envFile.exists()) {
        envFile.readLines().forEach { line ->
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
    }
    return env
}

android {
    namespace = "br.com.dito.example_app"
    compileSdk = 36

    val env = loadEnvFile()

    defaultConfig {
        applicationId = "br.com.dito.example_app"
        minSdk = 25
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        manifestPlaceholders["API_KEY"] = env["API_KEY"] ?: ""
        manifestPlaceholders["API_SECRET"] = env["API_SECRET"] ?: ""
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        viewBinding = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    androidResources {
        noCompress += ".env.development.local"
    }

    sourceSets {
        getByName("main") {
            assets.srcDirs("src/main/assets")
        }
    }
}

dependencies {
    implementation(project(":dito-sdk"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)

    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}

tasks.register("checkEnvFile") {
    doLast {
        val envFile = file("src/main/assets/.env.development.local")
        println("=".repeat(60))
        println("Verificando arquivo .env.development.local:")
        println("  Caminho: ${envFile.absolutePath}")
        println("  Existe: ${envFile.exists()}")
        if (envFile.exists()) {
            println("  Tamanho: ${envFile.length()} bytes")
            println("  Conteúdo:")
            envFile.readLines().take(5).forEach { line ->
                println("    $line")
            }
        }
        println("=".repeat(60))
    }
}

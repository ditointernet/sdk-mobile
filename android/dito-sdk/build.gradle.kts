plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.jetbrains.kotlin.android)
    id("com.google.devtools.ksp") version "2.0.0-1.0.21"
    id("maven-publish") apply true
    id("signing")
}

group = "br.com.dito"
version = System.getenv("VERSION_NAME") ?: "3.1.0"

android {
    namespace = "br.com.dito.ditosdk"
    compileSdk = 35

    defaultConfig {
        minSdk = 25

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
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

    publishing {
        singleVariant("release") {
            withSourcesJar()
            withJavadocJar()
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    testImplementation(libs.junit)
    testImplementation(libs.mockk)
    testImplementation(libs.robolectric)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.kotlin.test)
    testImplementation(libs.truth)
    testImplementation(libs.androidx.room.testing)
    testImplementation(libs.androidx.test.core)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)

    //Retrofit
    implementation(libs.retrofit)
    implementation(libs.converter.gson)

    //OkHttp
    implementation(libs.logging.interceptor)

    //Gson
    api(libs.gson)

    // Firebase
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)

    // SQL
    implementation(libs.androidx.room.ktx)
    implementation(libs.androidx.room.common)
    ksp(libs.androidx.room.compiler)
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])

                groupId = "br.com.dito"
                artifactId = "ditosdk"
                version = project.version.toString()
                pom {
                    name.set("Dito Android SDK")
                    description.set("SDK Android nativa da Dito para integração com o CRM Dito.")
                    url.set("https://github.com/ditointernet/sdk-mobile")
                    licenses {
                        license {
                            name.set("Proprietary")
                            url.set("https://github.com/ditointernet/sdk-mobile/blob/main/LICENSE")
                        }
                    }
                    developers {
                        developer {
                            id.set("dito")
                            name.set("Dito Internet")
                            email.set("licensing@dito.com.br")
                        }
                    }
                    scm {
                        url.set("https://github.com/ditointernet/sdk-mobile")
                        connection.set("scm:git:git://github.com/ditointernet/sdk-mobile.git")
                        developerConnection.set("scm:git:ssh://github.com/ditointernet/sdk-mobile.git")
                    }
                }
            }
        }

        repositories {
            val publishTarget = System.getenv("PUBLISH_TARGET") ?: "github"
            if (publishTarget == "central") {
                maven {
                    name = "MavenCentral"
                    url = uri("https://ossrh-staging-api.central.sonatype.com/service/local/staging/deploy/maven2/")
                    credentials {
                        username = System.getenv("SONATYPE_USERNAME") ?: ""
                        password = System.getenv("SONATYPE_PASSWORD") ?: ""
                    }
                }
            } else {
                maven {
                    name = "GitHubPackages"
                    url = uri("https://maven.pkg.github.com/ditointernet/sdk-mobile")
                    credentials {
                        username = System.getenv("GITHUB_ACTOR") ?: ""
                        password = System.getenv("GITHUB_TOKEN") ?: ""
                    }
                }
            }
        }
    }
}

val signingKey = System.getenv("SIGNING_KEY")
val signingPassword = System.getenv("SIGNING_PASSWORD")
if (!signingKey.isNullOrBlank() && !signingPassword.isNullOrBlank()) {
    signing {
        useInMemoryPgpKeys(signingKey, signingPassword)
        sign(publishing.publications)
    }
}
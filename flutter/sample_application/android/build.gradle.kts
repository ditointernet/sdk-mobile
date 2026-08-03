// Contraparte Android do hook que o Podfile deste sample já tinha no iOS: com o marcador
// presente, a SDK Android resolve do ~/.m2, então dá para rodar o sample contra uma SDK
// nativa ainda não publicada — o caso do push rico até o release do E3, e pré-requisito
// da sessão de validação do E9.
//
//   1. cd android && VERSION_NAME=4.1.0 ./gradlew :dito-sdk:publishReleasePublicationToMavenLocal
//   2. touch flutter/android/.use_local_dito_android_sdk
//   3. export DITO_ANDROID_SDK_VERSION=4.1.0
//
// Duas armadilhas que custaram tempo e valem o comentário:
//
// - tem que ser aqui, não no `dependencyResolutionManagement` do settings.gradle.kts: quem
//   resolve a SDK é o classpath do :app, e repositório declarado em projeto vence o
//   declarado em settings — o Gradle avisa isso em texto no erro de resolução;
// - o teste do marcador fica **fora** do `allprojects`. Dentro dele, `file()` resolve
//   relativo a cada subprojeto, então :app e :dito_sdk procuravam o marcador em pastas
//   diferentes e só o projeto raiz ganhava o mavenLocal.
val useLocalDitoAndroidSdk = file("../../android/.use_local_dito_android_sdk").exists()

allprojects {
    repositories {
        if (useLocalDitoAndroidSdk) {
            mavenLocal()
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

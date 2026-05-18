# Prompt de Instalação — Dito SDK Flutter

Use este arquivo como prompt para uma LLM instalar e configurar o Dito SDK Flutter em um projeto existente.

---

## Contexto para a LLM

Você é um assistente de código. Sua tarefa é integrar o **Dito SDK Flutter** (`dito_sdk`) em um projeto Flutter existente. Siga **todas** as etapas abaixo na ordem apresentada. Não pule nenhuma etapa. Para cada arquivo modificado, leia-o antes de editar.

O projeto usa Firebase Cloud Messaging (FCM) para push notifications. Se o projeto ainda não tiver Firebase configurado, avise o usuário antes de continuar.

### Sobre as credenciais Dito

O SDK suporta dois formatos de autenticação. Pergunte ao usuário qual ele possui antes de continuar:

| Formato | Quando usar | O que você terá |
|---|---|---|
| **Novo (X-Api-Key)** | Contas criadas recentemente ou migradas | Uma única `API_KEY` (sem secret) |
| **Legado** | Contas mais antigas ainda não migradas | `API_KEY` + `API_SECRET` separados |

> No formato novo, a `API_KEY` já contém toda a informação de autenticação — não há secret. O campo `API_SECRET` deve ser omitido ou deixado vazio onde aparecer nas etapas abaixo.

**Importante:** A API Dart do plugin Flutter (`ditoSdk.initialize()`) **ainda requer `appKey` e `appSecret`**. No formato novo, passe a `API_KEY` como `appKey` e uma string vazia `""` como `appSecret`. O tracking em background via `AndroidManifest.xml` e `Info.plist` funciona corretamente com apenas `API_KEY` (sem `API_SECRET`).

---

## Etapa 1 — Adicionar dependência no `pubspec.yaml`

No arquivo `pubspec.yaml` da aplicação, adicione dentro de `dependencies`:

```yaml
dependencies:
  dito_sdk: ^3.2.3
  firebase_core: ^4.4.0
  firebase_messaging: ^16.0.0
```

Execute:

```bash
flutter pub get
```

---

## Etapa 2 — Android: `AndroidManifest.xml`

No arquivo `android/app/src/main/AndroidManifest.xml`, faça as seguintes alterações:

**2.1 — Permissões (dentro de `<manifest>`, antes de `<application>`):**

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**2.2 — Credenciais para tracking em background (dentro de `<application>`):**

**Formato novo (X-Api-Key)** — apenas `API_KEY`, sem `API_SECRET`:

```xml
<meta-data
    android:name="br.com.dito.API_KEY"
    android:value="${DITO_API_KEY}" />
```

**Formato legado** — ambos `API_KEY` e `API_SECRET`:

```xml
<meta-data
    android:name="br.com.dito.API_KEY"
    android:value="${DITO_API_KEY}" />
<meta-data
    android:name="br.com.dito.API_SECRET"
    android:value="${DITO_API_SECRET}" />
```

**2.3 — Service delegador para Firebase Messaging (dentro de `<application>`):**

```xml
<service
    android:name=".CustomMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

---

## Etapa 3 — Android: `build.gradle.kts` do módulo `app`

No arquivo `android/app/build.gradle.kts`, dentro do bloco `android { defaultConfig { ... } }`, adicione a leitura das credenciais a partir de variáveis de ambiente ou `local.properties`:

```kotlin
val localProperties = java.util.Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) load(f.inputStream())
}

val ditoApiKey = System.getenv("DITO_API_KEY")
    ?: (localProperties.getProperty("DITO_API_KEY") ?: "")
val ditoApiSecret = System.getenv("DITO_API_SECRET")
    ?: (localProperties.getProperty("DITO_API_SECRET") ?: "")

manifestPlaceholders["DITO_API_KEY"] = ditoApiKey
manifestPlaceholders["DITO_API_SECRET"] = ditoApiSecret
```

> Por que isso é necessário? Quando uma notificação FCM chega enquanto o app está em background/fechado, o SDK Android precisa das credenciais para fazer o tracking do evento `"receive-android-notification"` sem que o app tenha sido inicializado explicitamente pelo usuário.

---

## Etapa 4 — Android: `MainActivity.kt`

No arquivo `android/app/src/main/kotlin/.../MainActivity.kt`, adicione a solicitação de permissão de notificações em tempo de execução para Android 13+ (API 33+):

```kotlin
package <PACKAGE_DO_SEU_APP>

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        requestPostNotificationsIfNeeded()
    }

    private fun requestPostNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    companion object {
        private const val REQUEST_POST_NOTIFICATIONS = 1001
    }
}
```

---

## Etapa 5 — Android: `CustomMessagingService.kt`

Crie o arquivo `android/app/src/main/kotlin/<PACKAGE>/CustomMessagingService.kt`:

```kotlin
package <PACKAGE_DO_SEU_APP>

import br.com.dito.ditosdk.DitoMessagingServiceHelper
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CustomMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val handled = DitoMessagingServiceHelper.handleMessage(applicationContext, remoteMessage)
        if (!handled) {
            super.onMessageReceived(remoteMessage)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        DitoMessagingServiceHelper.handleNewToken(applicationContext, token)
    }
}
```

> Por que este service é necessário? O Android só permite um `FirebaseMessagingService` por app. Este service delegador garante que notificações com `channel=DITO` sejam tratadas pelo SDK Dito, enquanto as demais são repassadas ao FlutterFire normalmente.

---

## Etapa 6 — iOS: `Info.plist`

No arquivo `ios/Runner/Info.plist`, adicione as seguintes chaves dentro do `<dict>` raiz:

```xml
<!-- Habilita recebimento de notificações em background -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>

<!-- Impede que o Firebase intercepte automaticamente o AppDelegate,
     necessário para compatibilidade com FlutterImplicitEngineDelegate -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>

<!-- Desabilita a inicialização automática do FCM para que o Flutter
     controle o ciclo de vida das mensagens via firebase_messaging -->
<key>FirebaseMessagingAutoInitEnabled</key>
<false/>

<!-- Credenciais para tracking de notificações em background no iOS.
     Se o app for inicializado explicitamente via ditoSdk.initialize(),
     as credenciais passadas via código terão prioridade. -->
<key>AppKey</key>
<string>SUA_API_KEY_AQUI</string>
<key>AppSecret</key>
<string>SEU_API_SECRET_AQUI</string>
```

> Por que `FirebaseAppDelegateProxyEnabled: false`? Com `FlutterImplicitEngineDelegate` (etapa 7), o Flutter gerencia o registro de plugins, tornando o proxy automático do Firebase desnecessário e potencialmente conflitante.

---

## Etapa 7 — iOS: `AppDelegate.swift`

No arquivo `ios/Runner/AppDelegate.swift`, configure o `AppDelegate` para usar `FlutterImplicitEngineDelegate`:

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }
}
```

> Nota: o plugin Dito configura automaticamente o Firebase Messaging no iOS (delegate, autorização de push, registro para APNs). Não é necessário adicionar nenhum código de Firebase no `AppDelegate`.

---

## Etapa 8 — iOS: Xcode (manual)

Oriente o usuário a realizar as seguintes ações manualmente no Xcode:

1. Abrir `ios/Runner.xcworkspace` no Xcode
2. Selecionar o target `Runner`
3. Aba **Signing & Capabilities** → **+ Capability**:
   - Adicionar **Push Notifications**
   - Adicionar **Background Modes** → marcar **Remote notifications**
4. Adicionar o arquivo `GoogleService-Info.plist` no target `Runner` (arrastar para dentro do Xcode com "Copy items if needed" marcado)

---

## Etapa 9 — Dart: `main.dart`

No arquivo `lib/main.dart`, configure o Firebase e o SDK Dito:

```dart
import 'dart:async';

import 'package:dito_sdk/dito_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Substitua pelo seu firebase_options.dart gerado via flutterfire configure
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final ditoSdk = DitoSdk();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await ditoSdk.setDebugMode(enabled: true); // remover em produção
    await ditoSdk.initialize(
      appKey: 'SUA_API_KEY_AQUI',
      appSecret: 'SEU_API_SECRET_AQUI',
    );
  } on PlatformException catch (e) {
    debugPrint('Dito SDK init error: ${e.message}');
  }

  runApp(const MyApp());
}
```

> `setDebugMode(enabled: true)` deve ser chamado **antes** de `initialize` para capturar logs de inicialização. Remova ou defina como `false` em produção.

---

## Etapa 10 — Dart: configurar listeners de notificação

No widget raiz do app (ou no `initState` do widget principal), configure os listeners:

```dart
class _MyAppState extends State<MyApp> {
  StreamSubscription<DitoNotificationClick>? _notificationClickSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  @override
  void initState() {
    super.initState();

    // Escuta cliques em notificações Dito (deeplink)
    _notificationClickSub = DitoSdk.onNotificationClick.listen((event) {
      if (event.deeplink.isEmpty) return;
      // Navegue para o deeplink aqui, ex: context.go(event.deeplink)
    });

    // Android: app aberto a partir de notificação
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await ditoSdk.handleNotificationClick(message.data);
    });

    // Android: app iniciado a partir de notificação (estado terminated)
    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message == null) return;
      await ditoSdk.handleNotificationClick(message.data);
    });
  }

  @override
  void dispose() {
    _notificationClickSub?.cancel();
    _messageOpenedSub?.cancel();
    super.dispose();
  }
}
```

---

## Etapa 11 — Uso do SDK

Após a configuração, use o SDK onde necessário:

**Identificar usuário** (chamar após login):

```dart
await ditoSdk.identify(
  id: 'user-id-unico',
  name: 'Nome do Usuário',
  email: 'email@exemplo.com',
  customData: {'plano': 'premium'},
);
```

**Rastrear evento:**

```dart
await ditoSdk.track(
  action: 'nome-do-evento',
  data: {'chave': 'valor'},
);
```

**Registrar token FCM** (chamar após obter o token do Firebase):

```dart
final token = await FirebaseMessaging.instance.getToken();
if (token != null) {
  await ditoSdk.registerDeviceToken(token);
}
```

**Desregistrar token** (chamar no logout):

```dart
final token = await FirebaseMessaging.instance.getToken();
if (token != null) {
  await ditoSdk.unregisterDeviceToken(token);
}
```

> Ordem obrigatória: `initialize` → `identify` → `track`. Chamar `track` antes de `identify` resulta em eventos sem vínculo com o usuário.

---

## Checklist de Verificação

Após concluir todas as etapas, confirme:

- [ ] `pubspec.yaml` com `dito_sdk`, `firebase_core`, `firebase_messaging`
- [ ] `AndroidManifest.xml` com `POST_NOTIFICATIONS`, `meta-data` de credenciais e `CustomMessagingService`
- [ ] `build.gradle.kts` injetando `manifestPlaceholders` com as credenciais
- [ ] `MainActivity.kt` solicitando permissão `POST_NOTIFICATIONS` em runtime (Android 13+)
- [ ] `CustomMessagingService.kt` criado e registrado no manifest
- [ ] `Info.plist` com `UIBackgroundModes`, `FirebaseAppDelegateProxyEnabled: false`, `FirebaseMessagingAutoInitEnabled: false`, `AppKey`, `AppSecret`
- [ ] `AppDelegate.swift` com `FlutterImplicitEngineDelegate`
- [ ] Xcode: capability **Push Notifications** + **Background Modes → Remote notifications** adicionadas
- [ ] `GoogleService-Info.plist` adicionado no target iOS do Xcode
- [ ] `main.dart` com `Firebase.initializeApp`, `onBackgroundMessage`, `ditoSdk.initialize`
- [ ] Listeners de `onNotificationClick`, `onMessageOpenedApp` e `getInitialMessage` configurados
- [ ] `setDebugMode(enabled: false)` ou removido em produção

---

## Erros Comuns

| Erro | Causa | Solução |
|---|---|---|
| `NOT_INITIALIZED` | Método chamado antes de `initialize` | Chamar `ditoSdk.initialize()` no `main()` antes de `runApp` |
| `INVALID_CREDENTIALS` | `appKey` ou `appSecret` vazios | Verificar valores passados ao `initialize` |
| `receive-android-notification` não dispara em background | SDK sem credenciais em background | Adicionar `meta-data` no `AndroidManifest.xml` (Etapa 2.2) |
| `receive-ios-notification` não dispara em background | `AppKey`/`AppSecret` ausentes no `Info.plist` | Adicionar credenciais no `Info.plist` (Etapa 6) |
| Notificação não aparece no Android 13+ | Permissão não solicitada | Implementar `requestPostNotificationsIfNeeded` no `MainActivity` (Etapa 4) |
| Push não chega no iOS | APNs não configurado ou capabilities ausentes | Verificar Etapa 8 no Xcode e configuração APNs no Firebase Console |

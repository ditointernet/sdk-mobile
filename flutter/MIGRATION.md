# Guia de Migração - Dito SDK Flutter

Este documento descreve os passos necessários para migrar da versão antiga do Dito SDK Flutter (pub.dev) para a nova versão 3.0.0+.

## 📋 Visão Geral das Mudanças

A nova versão do SDK traz simplificações significativas na API, melhor tratamento de erros e uma arquitetura mais alinhada com as SDKs nativas (iOS e Android).

### Principais Mudanças

| Categoria | Mudança |
|-----------|---------|
| **API** | Simplificação dos métodos e renomeação de parâmetros |
| **Identificação** | Método unificado - não há mais `identifyUser()` separado |
| **Eventos** | Parâmetros renomeados (`action` em vez de `eventName`) |
| **Push** | Remoção de parâmetro `platform` (detectado automaticamente) |
| **Notificações** | Remoção do sistema de notificações locais |
| **Configuração Nativa** | Credenciais no AndroidManifest (obrigatório) e Info.plist (opcional) |
| **Singleton** | Mudança de singleton para instância simples |

---

## 🔧 Passo 1: Atualização da Dependência

### Antes (SDK Antiga)

```yaml
dependencies:
  dito_sdk: ^2.x.x  # versão do pub.dev
```

### Depois (SDK Nova)

```yaml
dependencies:
  dito_sdk: ^3.0.0
```

Execute:

```bash
flutter pub get
```

---

## 🚀 Passo 2: Inicialização do SDK

### Antes (SDK Antiga)

```dart
import 'package:dito_sdk/dito_sdk.dart';

final dito = DitoSDK();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a SDK
  dito.initialize(
    apiKey: 'sua_api_key',
    secretKey: 'sua_secret_key'
  );

  // Inicializa o serviço de push (método separado)
  await dito.initializePushService();

  runApp(MyApp());
}
```

### Depois (SDK Nova)

```dart
import 'package:dito_sdk/dito_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cria instância do SDK
  final ditoSdk = DitoSdk();

  try {
    // Inicializa com os novos nomes de parâmetros
    await ditoSdk.initialize(
      appKey: 'sua_api_key',      // Renomeado de apiKey
      appSecret: 'sua_secret_key'  // Renomeado de secretKey
    );
    print('SDK inicializado com sucesso');
  } on PlatformException catch (e) {
    print('Erro ao inicializar: ${e.message}');
  }

  runApp(MyApp());
}
```

### ⚠️ Mudanças Importantes

1. **Parâmetros renomeados**: `apiKey` → `appKey`, `secretKey` → `appSecret`
2. **Método assíncrono**: `initialize()` agora retorna `Future<void>` e deve usar `await`
3. **Sem método separado para push**: Não existe mais `initializePushService()`
4. **Instância não é singleton**: Crie e passe a instância conforme necessário

---

## 👤 Passo 3: Identificação de Usuários

### Antes (SDK Antiga)

```dart
// Passo 1: Define os dados do usuário (não envia ainda)
dito.identify(
  sha1("joao@example.com"),  // userId
  'João da Silva',           // name
  'joao@example.com',        // email
  'São Paulo',               // location
  'male',                    // gender
  '1990-01-15',              // birthday
  {                          // customData
    'loja_preferida': 'LojaX',
    'canal_preferido': 'Loja Física'
  }
);

// Passo 2: Envia os dados para a Dito
await dito.identifyUser();
```

### Depois (SDK Nova)

```dart
// Método unificado - identifica e envia em uma única chamada
await ditoSdk.identify(
  id: sha1.convert(utf8.encode("joao@example.com")).toString(),
  name: 'João da Silva',
  email: 'joao@example.com',
  customData: {
    'loja_preferida': 'LojaX',
    'canal_preferido': 'Loja Física'
  }
);
```

### ⚠️ Mudanças Importantes

1. **Método unificado**: Não existe mais `identifyUser()` - `identify()` já envia os dados
2. **Parâmetros nomeados**: Todos os parâmetros agora são nomeados
3. **Parâmetros removidos**: `location`, `gender` e `birthday` não existem mais
   - Use `customData` para enviar esses dados se necessário
4. **ID obrigatório**: O parâmetro `id` é obrigatório e deve ser o primeiro
5. **Email opcional mas validado**: Se fornecido, deve ser um email válido

### Migração de Campos Removidos

Se você usava `location`, `gender` ou `birthday`, mova-os para `customData`:

```dart
// ✅ Solução: usar customData
await ditoSdk.identify(
  id: userId,
  name: 'João da Silva',
  email: 'joao@example.com',
  customData: {
    'location': 'São Paulo',        // Antes era parâmetro separado
    'gender': 'male',                // Antes era parâmetro separado
    'birthday': '1990-01-15',        // Antes era parâmetro separado
    'loja_preferida': 'LojaX',
  }
);
```

---

## 📊 Passo 4: Rastreamento de Eventos

### Antes (SDK Antiga)

```dart
await dito.trackEvent(
  eventName: 'comprou_produto',
  revenue: 99.90,
  customData: {
    'produto': 'produtoX',
    'sku_produto': '99999999',
    'metodo_pagamento': 'Visa',
  }
);
```

### Depois (SDK Nova)

```dart
await ditoSdk.track(
  action: 'comprou_produto',  // Renomeado de eventName
  data: {                      // Renomeado de customData
    'produto': 'produtoX',
    'sku_produto': '99999999',
    'metodo_pagamento': 'Visa',
    'revenue': 99.90,          // Agora dentro de data
  }
);
```

### ⚠️ Mudanças Importantes

1. **Método renomeado**: `trackEvent()` → `track()`
2. **Parâmetros renomeados**:
   - `eventName` → `action`
   - `customData` → `data`
3. **Revenue movido**: `revenue` não é mais um parâmetro separado - inclua em `data` se necessário

---

## 🔔 Passo 5: Push Notifications - Registro de Token

### Antes (SDK Antiga)

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

final token = await FirebaseMessaging.instance.getToken();

// Com parâmetro platform opcional
await dito.registryMobileToken(
  token: token!,
  platform: 'Android'  // ou 'iPhone'
);

// Para remover
await dito.removeMobileToken(
  token: token!,
  platform: 'Android'
);
```

### Depois (SDK Nova)

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

final token = await FirebaseMessaging.instance.getToken();

// Platform é detectado automaticamente
await ditoSdk.registerDeviceToken(token!);

// Para remover
await ditoSdk.unregisterDeviceToken(token!);
```

### ⚠️ Mudanças Importantes

1. **Métodos renomeados**:
   - `registryMobileToken()` → `registerDeviceToken()`
   - `removeMobileToken()` → `unregisterDeviceToken()`
2. **Parâmetro platform removido**: A plataforma é detectada automaticamente
3. **Parâmetro simplificado**: Apenas o token é necessário

---

## 🔔 Passo 6: Push Notifications - Configuração

### Antes (SDK Antiga)

A SDK antiga incluía um sistema de notificações locais:

```dart
import 'package:dito_sdk/dito_sdk.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final notification = DataPayload.fromJson(jsonDecode(message.data["data"]));

  // SDK antiga exibia notificação local
  dito.notificationService().showLocalNotification(
    CustomNotification(
      id: message.hashCode,
      title: notification.details.title ?? "Nome do App",
      body: notification.details.message,
      payload: notification
    )
  );
}
```

### Depois (SDK Nova)

A nova SDK remove o sistema de notificações locais. Configure o Firebase diretamente:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dito_sdk/dito_sdk.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Processe a notificação usando Firebase Messaging diretamente
  // A SDK Dito não gerencia mais notificações locais
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Registre o handler de background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicialize o Dito SDK
  final ditoSdk = DitoSdk();
  await ditoSdk.initialize(
    appKey: 'sua_api_key',
    appSecret: 'sua_secret_key'
  );

  // Registre o token
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await ditoSdk.registerDeviceToken(token);
  }

  runApp(MyApp());
}
```

### ⚠️ Mudanças Importantes

1. **Notificações locais removidas**: A SDK não gerencia mais exibição de notificações
2. **Use Firebase diretamente**: Configure `firebase_messaging` para exibir notificações
3. **DataPayload removido**: Classes auxiliares de notificação foram removidas
4. **openNotification removido**: Método para rastrear abertura de notificações foi removido

### 🔗 Click em notificação e deeplink (novo)

A versão nova expõe um stream para cliques em notificações Dito:

- `DitoSdk.onNotificationClick`

No Android, se você detecta o clique no Dart (por exemplo, via `FirebaseMessaging.onMessageOpenedApp`), encaminhe o payload para o SDK para tracking e emissão do evento:

```dart
final ditoSdk = DitoSdk();

DitoSdk.onNotificationClick.listen((event) {
  if (event.deeplink.isEmpty) return;
  // Navegação do seu app aqui
});

FirebaseMessaging.onMessageOpenedApp.listen((message) async {
  await ditoSdk.handleNotificationClick(message.data);
});
```

---

## 📱 Passo 7: Configuração Nativa - Android

### Credenciais no AndroidManifest (NOVO - Obrigatório)

A nova SDK requer que as credenciais sejam configuradas no `AndroidManifest.xml` para permitir tracking de notificações em background:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application>
    <meta-data
        android:name="br.com.dito.API_KEY"
        android:value="${DITO_API_KEY}" />
    <meta-data
        android:name="br.com.dito.API_SECRET"
        android:value="${DITO_API_SECRET}" />

    <!-- ... resto da configuração -->
</application>
```

E no `build.gradle.kts` do módulo `app`:

```kotlin
android {
    defaultConfig {
        // ... outras configurações

        val localProperties = Properties()
        val localPropertiesFile = rootProject.file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }

        val ditoApiKey = System.getenv("DITO_API_KEY")
            ?: (localProperties.getProperty("DITO_API_KEY") ?: "")
        val ditoApiSecret = System.getenv("DITO_API_SECRET")
            ?: (localProperties.getProperty("DITO_API_SECRET") ?: "")

        manifestPlaceholders["DITO_API_KEY"] = ditoApiKey
        manifestPlaceholders["DITO_API_SECRET"] = ditoApiSecret
    }
}
```

**Por quê?** Quando uma notificação chega em background, o Android pode precisar inicializar o SDK automaticamente para fazer tracking. As credenciais no manifest garantem que isso funcione mesmo se o app não foi inicializado explicitamente.

### Antes (SDK Antiga)

Não era necessário criar service customizado.

### Depois (SDK Nova)

Se você usa `firebase_messaging`, é necessário criar um service delegador:

**Arquivo**: `android/app/src/main/kotlin/com/seu/app/CustomMessagingService.kt`

```kotlin
package com.seu.app

import br.com.dito.ditosdk.DitoMessagingServiceHelper
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CustomMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Delega notificações Dito para o SDK nativo
        val handled = DitoMessagingServiceHelper.handleMessage(
            applicationContext,
            remoteMessage
        )

        // Se não for Dito, processa normalmente
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

**Arquivo**: `android/app/src/main/AndroidManifest.xml`

```xml
<application>
    <!-- Adicione dentro de <application> -->
    <service
        android:name=".CustomMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
</application>
```

---

## 🍎 Passo 8: Configuração Nativa - iOS

### Antes (SDK Antiga)

Era necessário modificar o `AppDelegate`:

```swift
// AppDelegate.swift - SDK Antiga
import UIKit
import Flutter
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Depois (SDK Nova)

**Não é mais necessário modificar o AppDelegate!** O plugin configura automaticamente.

Apenas certifique-se de:

1. ✅ Adicionar `GoogleService-Info.plist` no target iOS
2. ✅ Habilitar Push Notifications no Xcode
3. ✅ Habilitar Background Modes → Remote notifications
4. ✅ Configurar APNs no Firebase Console

### Credenciais no Info.plist (NOVO - Opcional mas Recomendado)

Para tracking de notificações em background (similar ao Android), adicione as credenciais no `Info.plist`:

```xml
<!-- ios/Runner/Info.plist -->
<dict>
    <key>AppKey</key>
    <string>sua-api-key</string>
    <key>AppSecret</key>
    <string>seu-api-secret</string>

    <!-- ... resto da configuração -->
</dict>
```

**Por quê?** Se uma notificação chegar em background antes do app ter sido inicializado explicitamente via `DitoSdk.initialize()`, o SDK nativo iOS poderá carregar as credenciais do `Info.plist` para fazer tracking do evento `"receive-ios-notification"`.

**Nota:** As credenciais passadas via `DitoSdk.initialize()` no código Dart têm prioridade sobre as do `Info.plist`.

---

## 🗑️ Passo 9: Remoções e Funcionalidades Descontinuadas

### Classes Removidas

- ❌ `User` class - Não existe mais
- ❌ `DataPayload` - Não existe mais
- ❌ `CustomNotification` - Não existe mais
- ❌ `NotificationService` - Não existe mais

### Métodos Removidos

- ❌ `identifyUser()` - Use apenas `identify()`
- ❌ `initializePushService()` - Configuração automática
- ❌ `openNotification()` - Rastreamento de abertura removido
- ❌ `notificationService()` - Sistema de notificações locais removido

### Se Você Usava `User` Class

**Antes:**

```dart
User user = User(
  sha1("joao@example.com"),
  'João da Silva',
  'joao@example.com',
  'São Paulo'
);

dito.identify(user.userId, user.name, user.email, user.location);
await dito.identifyUser();
```

**Depois:**

```dart
// Não há mais classe User - passe os dados diretamente
await ditoSdk.identify(
  id: sha1.convert(utf8.encode("joao@example.com")).toString(),
  name: 'João da Silva',
  email: 'joao@example.com',
  customData: {
    'location': 'São Paulo'
  }
);
```

---

## ✅ Checklist de Migração

Use este checklist para garantir que a migração foi concluída:

### Configuração

- [ ] Atualizada dependência no `pubspec.yaml` para `^3.0.0`
- [ ] Executado `flutter pub get`
- [ ] Removidas importações de classes antigas (`User`, `DataPayload`, etc.)

### Código Dart

- [ ] Alterado `initialize()` para usar `appKey` e `appSecret`
- [ ] Adicionado `await` na chamada de `initialize()`
- [ ] Removido `identifyUser()` - usando apenas `identify()`
- [ ] Atualizado `identify()` para usar parâmetros nomeados
- [ ] Movido `location`, `gender`, `birthday` para `customData` (se aplicável)
- [ ] Alterado `trackEvent()` para `track()`
- [ ] Renomeado `eventName` para `action` e `customData` para `data`
- [ ] Movido `revenue` para dentro de `data` (se aplicável)
- [ ] Alterado `registryMobileToken()` para `registerDeviceToken()`
- [ ] Removido parâmetro `platform` do registro de token
- [ ] Alterado `removeMobileToken()` para `unregisterDeviceToken()`
- [ ] Removido uso de `openNotification()` (se aplicável)
- [ ] Removido uso de `notificationService()` (se aplicável)

### Android

- [ ] Adicionado `API_KEY` e `API_SECRET` no `AndroidManifest.xml`
- [ ] Configurado `manifestPlaceholders` no `build.gradle.kts`
- [ ] Criado `CustomMessagingService.kt` com delegação para Dito
- [ ] Registrado service no `AndroidManifest.xml`

### iOS

- [ ] Adicionado `GoogleService-Info.plist` no target
- [ ] Habilitado Push Notifications no Xcode
- [ ] Habilitado Background Modes → Remote notifications
- [ ] Verificado que APNs está configurado no Firebase
- [ ] (Opcional) Adicionado `AppKey` e `AppSecret` no `Info.plist` para tracking em background
- [ ] Removido código de configuração manual do Firebase no `AppDelegate` (se aplicável)

### Testes

- [ ] Testado inicialização do SDK
- [ ] Testado identificação de usuário
- [ ] Testado rastreamento de eventos
- [ ] Testado registro de token de push
- [ ] Testado recebimento de push notifications (Android e iOS)
- [ ] Testado abertura de push notifications

---

## 🐛 Problemas Comuns

### Erro: "INVALID_PARAMETERS: apiKey cannot be null or empty"

**Causa**: Você está usando os nomes antigos dos parâmetros.

**Solução**:

```dart
// ❌ ERRADO
await ditoSdk.initialize(apiKey: key, secretKey: secret);

// ✅ CORRETO
await ditoSdk.initialize(appKey: key, appSecret: secret);
```

### Erro: "Cannot find 'identifyUser' in scope"

**Causa**: O método `identifyUser()` foi removido.

**Solução**: Use apenas `identify()`, que já envia os dados automaticamente.

### Push notifications não funcionam no Android

**Causa**: Falta configurar o `CustomMessagingService`.

**Solução**: Siga o [Passo 7](#-passo-7-configuração-nativa---android).

### Evento "receive-android-notification" não dispara em background

**Causa**: Credenciais não configuradas no `AndroidManifest.xml`.

**Solução**: Configure `API_KEY` e `API_SECRET` no `AndroidManifest.xml` conforme descrito no [Passo 7](#-passo-7-configuração-nativa---android).

### Evento "receive-ios-notification" não dispara em background

**Causa**: App não foi inicializado explicitamente antes da notificação chegar.

**Solução**: Adicione `AppKey` e `AppSecret` no `Info.plist` conforme descrito no [Passo 8](#-passo-8-configuração-nativa---ios).

### Erro: "location is not a parameter of identify"

**Causa**: Parâmetros `location`, `gender` e `birthday` foram removidos.

**Solução**: Mova esses valores para `customData`:

```dart
await ditoSdk.identify(
  id: userId,
  name: name,
  email: email,
  customData: {
    'location': 'São Paulo',
    'gender': 'male',
    'birthday': '1990-01-15'
  }
);
```

---

## 📞 Suporte

Se você encontrar problemas durante a migração:

1. 📚 Consulte o [README completo](./README.md)
2. 🔍 Verifique o [Troubleshooting](./README.md#-troubleshooting) no README
3. 📖 Veja o [app de exemplo](./sample_application) como referência
4. 🌐 Acesse a [documentação Dito](https://developers.dito.com.br)

---

## 📊 Comparação Rápida

| Funcionalidade | SDK Antiga | SDK Nova (3.0.0+) |
|----------------|------------|-------------------|
| Inicialização | `initialize(apiKey, secretKey)` | `initialize(appKey, appSecret)` |
| Identificação | `identify()` + `identifyUser()` | `identify()` (unificado) |
| Eventos | `trackEvent(eventName, revenue, customData)` | `track(action, data)` |
| Registro Token | `registryMobileToken(token, platform)` | `registerDeviceToken(token)` |
| Remoção Token | `removeMobileToken(token, platform)` | `unregisterDeviceToken(token)` |
| Push Service | `initializePushService()` | Automático (removido) |
| Notif. Locais | `notificationService().show()` | Removido - use Firebase |
| Abertura Notif. | `openNotification()` | Removido |
| User Class | `User(...)` | Removido |
| Singleton | `DitoSDK()` (singleton) | `DitoSdk()` (instância) |

---

**Última atualização**: 2026-01
**Versão do documento**: 1.0.0

# Guia de Push Notifications

Guia unificado para configuração e uso de Push Notifications em todas as plataformas suportadas pelo Dito SDK.

## 📋 Visão Geral

O Dito SDK suporta Push Notifications via Firebase Cloud Messaging (FCM) em todas as plataformas. Este guia fornece instruções passo a passo para configurar e usar Push Notifications em iOS, Android, Flutter e React Native.

## 🔥 Configuração Firebase Geral

### 1. Criar Projeto no Firebase Console

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Crie um novo projeto ou selecione um existente
3. Ative o Cloud Messaging no projeto

### 2. Obter Credenciais

Cada plataforma requer arquivos de configuração específicos:
- **iOS**: `GoogleService-Info.plist`
- **Android**: `google-services.json`
- **Flutter/React Native**: Ambos os arquivos acima

## 📱 Configuração por Plataforma

### iOS

#### 1. Adicionar GoogleService-Info.plist

1. Baixe o arquivo `GoogleService-Info.plist` do Firebase Console
2. Adicione o arquivo ao projeto Xcode
3. Certifique-se de que está incluído no target do app

#### 2. Configurar Capabilities

1. No Xcode, selecione o target do app
2. Vá em **Signing & Capabilities**
3. Adicione **Push Notifications**
4. Adicione **Background Modes** e marque **Remote notifications**

#### 3. Configurar AppDelegate

Veja o exemplo completo em [iOS README](../ios/README.md#-configuração-inicial).

**Ordem Importante (iOS 18+)**:
1. `FirebaseApp.configure()`
2. `Messaging.messaging().delegate = self`
3. `Dito.shared.configure()`

#### 4. Rich push: imagem e botões exigem um target a mais

Campanhas com `image` ou `actions` **só renderizam** se o app tiver uma
**Notification Service Extension**. Trocar a versão da SDK não basta: a extensão é um
target novo no projeto do app, e nenhuma versão de SDK cria target em projeto de
terceiro. Sem ela o push continua chegando, mas como título + mensagem.

São três passos — criar o target, linkar o pod `DitoSDKNotificationService` (não o
`DitoSDK`, que não compila em extensão) e herdar de `DitoNotificationService`. O
roteiro completo está em
[iOS README — Rich Push](../ios/README.md#-rich-push-imagem-botões-e-custom-data).

No lado do clique, use `Dito.notificationClick(response:)`. É o `actionIdentifier` da
`response` que identifica o botão tocado; com só o `userInfo`, o clique chega ao
painel sem `action_id`.

**Cold start e `receive-ios-notification`**: com app morto ou em background, o iOS só executa o SDK na **chegada** do push se o payload APNs incluir `"content-available": 1` e o app tiver **Remote notifications** em Background Modes. O plugin Flutter (`DitoNotificationDelegate`) chama o SDK nativo sem subir o Dart. Guarde o token FCM em `UserDefaults` (chave `FCMToken`) e reutilize-o quando `didReceiveRemoteNotification` rodar. O ingest exige `user_id` ou `userId` (também em `data`/`gcm`). Detalhes: [iOS README — secção 3.1](../ios/README.md).

### Android

#### 1. Adicionar google-services.json

1. Baixe o arquivo `google-services.json` do Firebase Console
2. Adicione o arquivo ao diretório `app/` do projeto
3. Adicione o plugin no `build.gradle.kts`:

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

#### 2. Configurar FirebaseMessagingService

Veja o exemplo completo em [Android README](../android/README.md#push-notifications).

### Flutter

#### 1. Instalar Dependências

```yaml
dependencies:
  firebase_messaging: ^14.0.0
  firebase_core: ^2.0.0
```

#### 2. Configurar Plataformas Nativas

Siga as instruções de [iOS](../ios/README.md) e [Android](../android/README.md).

#### 3. Inicializar Firebase

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

#### 4. Inbox e handlers Dart (opcional)

- **Inbox local**: `getNotifications()` e `markNotificationAsRead(id)` — veja [Flutter README — getNotifications](../flutter/README.md#getnotifications).
- **Receive em background via Dart**: `handleNotificationReceived(userInfo)` em `FirebaseMessaging.onBackgroundMessage` (fallback; no iOS o plugin nativo costuma tratar cold start).
- **Clique detectado no Dart**: `handleNotificationClick(message.data)` e/ou `DitoSdk.onNotificationClick` — detalhes em [Flutter README — Push Notifications](../flutter/README.md#-push-notifications).

### React Native

#### 1. Instalar Dependências

```bash
npm install @react-native-firebase/app @react-native-firebase/messaging
```

#### 2. Configurar Plataformas Nativas

Siga as instruções de [iOS](../ios/README.md) e [Android](../android/README.md).

## 🔔 Interceptação de Notificações

O SDK intercepta automaticamente notificações do canal Dito quando o campo `channel` nos dados da notificação é igual a `"DITO"` (case-insensitive).

### Como Funciona

1. Quando uma notificação é recebida, o SDK verifica o campo `channel`
2. Se `channel == "DITO"`, o SDK processa a notificação automaticamente
3. Se `channel != "DITO"`, a notificação é ignorada pelo SDK e deve ser processada normalmente pelo app

### Payload Esperado

**iOS (receive em tempo real com app morto):** inclua `content-available` no `aps`:

```json
{
  "aps": {
    "alert": { "title": "Título", "body": "Corpo" },
    "content-available": 1
  },
  "channel": "DITO",
  "notification": "notification-id",
  "reference": "user-reference",
  "link": "https://app.example.com/product/123",
  "log_id": "log-id",
  "notification_name": "Nome da Notificação",
  "user_id": "user-id"
}
```

Payload mínimo (campos de dados):

```json
{
  "channel": "DITO",
  "notification": "notification-id",
  "reference": "user-reference",
  "link": "https://app.example.com/product/123",
  "log_id": "log-id",
  "notification_name": "Nome da Notificação",
  "user_id": "user-id"
}
```

**Notas sobre deeplink**:

- O campo canônico no payload é `link` (string).
- Os wrappers **Flutter** e **React Native** aceitam `deeplink` como alias quando você precisa montar um `userInfo` manualmente (por exemplo, vindo de `firebase_messaging`).

## 📊 Tracking Automático

O SDK rastreia automaticamente quando uma notificação é recebida:

- **iOS**: Evento `receive-ios-notification`
- **Android**: Evento `receive-android-notification`

Os eventos incluem:
- Canal: "mobile"
- Token do dispositivo
- ID do disparo (log_id)
- ID da notificação
- Nome da notificação
- Provedor: "firebase"
- Sistema operacional

## 👆 Handling de Clicks

Quando o usuário clica em uma notificação, o SDK:

1. Registra o clique no CRM Dito
2. Extrai o deeplink (`link`) se disponível
3. Dispara o evento/callback exposto pela plataforma, para que o app faça navegação (ou abra navegador, etc.)

### Fluxo (alto nível)

```mermaid
sequenceDiagram
    participant User as Usuário
    participant OS as Sistema Operacional
    participant Native as SDK Nativo
    participant Bridge as Bridge
    participant App as App

    User->>OS: Clica na notificação
    OS->>Native: Entrega a interação
    Native->>Native: Tracking do clique
    Native->>Native: Extrai link
    alt iOS_AndroidNativo
        Native->>App: Callback com link
    end
    alt Flutter
        Native->>Bridge: EventChannel
        Bridge->>App: Stream emite evento
    end
    alt ReactNative
        Native->>Bridge: EventEmitter
        Bridge->>App: Listener recebe evento
    end
```

### Ciclo de vida (estados)

```mermaid
stateDiagram-v2
    [*] --> Recebida
    Recebida --> Exibida
    Exibida --> Clicada
    Exibida --> Descartada
    Clicada --> Processada
    Processada --> EventoDisparado
    EventoDisparado --> [*]
    Descartada --> [*]
```

Versão detalhada (com responsabilidades do SDK):

```mermaid
stateDiagram-v2
    [*] --> Enviada: Plataforma Dito envia
    Enviada --> Recebida: FCM entrega ao dispositivo
    Recebida --> Exibida: Sistema exibe notificação
    Exibida --> Clicada: Usuário clica
    Exibida --> Descartada: Usuário descarta
    Clicada --> Processada: SDK processa clique
    Processada --> CallbackExecutado: Callback com link
    CallbackExecutado --> Navegação: App navega
    Navegação --> [*]
    Descartada --> [*]

    note right of Recebida
        SDK rastreia evento
        receive-*-notification
    end note

    note right of Processada
        SDK extrai link
        e chama callback/evento
    end note
```

### Decisão de processamento (payload)

```mermaid
flowchart TD
    Start[Notificação recebida] --> CheckChannel{channel == DITO?}
    CheckChannel -->|Não| Ignore[Ignorar no SDK]
    CheckChannel -->|Sim| Process[Processar no SDK]
    Process --> TrackReceive[Tracking de recebimento]
    TrackReceive --> TrackClick[Tracking de clique]
    TrackClick --> Emit[Disparar evento/callback]
    Ignore --> End[Fim]
    Emit --> End
```

### Estrutura do payload (diagrama)

```mermaid
graph LR
    subgraph Payload[Payload FCM]
        Channel[channel: DITO]
        Notification[notification: ID]
        Reference[reference: User Ref]
        Deeplink[link: deeplink URL]
        LogID[log_id: Log ID]
        NotifName[notification_name: Nome]
        UserID[user_id: User ID]
    end

    subgraph Extracted[Dados extraídos]
        SDK[SDK processa]
    end

    subgraph Callback[Callback/evento retorna]
        DeeplinkStr[deeplink: string]
        NotifObj[notification: object]
    end

    Channel --> SDK
    Notification --> SDK
    Reference --> SDK
    Deeplink --> SDK
    LogID --> SDK
    NotifName --> SDK
    UserID --> SDK

    SDK --> DeeplinkStr
    SDK --> NotifObj
```

### Troubleshooting (fluxo)

```mermaid
flowchart TD
    Start[Callback não funciona?] --> Q1{Notificação chega?}

    Q1 -->|Não| CheckFCM[Verificar configuração FCM]
    Q1 -->|Sim| Q2{SDK processa?}

    Q2 -->|Não| CheckChannel{channel == DITO?}
    Q2 -->|Sim| Q3{Callback/evento executado?}

    CheckChannel -->|Não| FixPayload[Corrigir payload da notificação]
    CheckChannel -->|Sim| CheckInit[Verificar inicialização do SDK]

    Q3 -->|Não| Q4{Plataforma?}
    Q3 -->|Sim| Q5{Link existe?}

    Q4 -->|Android| CheckListener[Verificar notificationClickListener]
    Q4 -->|iOS| CheckDelegate[Verificar callback no AppDelegate]
    Q4 -->|Flutter| CheckStream[Verificar Stream listener]
    Q4 -->|React Native| CheckSubscribe[Verificar subscription do listener]

    Q5 -->|Não| CheckPayloadDeeplink[Verificar campo link no payload]
    Q5 -->|Sim| Q6{Navegação funciona?}

    Q6 -->|Não| CheckNavigation[Verificar implementação de navegação]
    Q6 -->|Sim| Success[Tudo funcionando]

    CheckFCM --> End[Fim]
    FixPayload --> End
    CheckInit --> End
    CheckListener --> End
    CheckDelegate --> End
    CheckStream --> End
    CheckSubscribe --> End
    CheckPayloadDeeplink --> End
    CheckNavigation --> End
    Success --> End
```

### Exemplo iOS

```swift
// Passe a `response`: é ela que carrega qual botão de rich push foi tocado.
Dito.notificationClick(response: response) { deeplink in
    if let url = URL(string: deeplink) {
        UIApplication.shared.open(url)
    }
}
```

### Exemplo Android

```kotlin
Dito.notificationClick(userInfo) { deeplink ->
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deeplink))
    startActivity(intent)
}
```

### Exemplo Flutter

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dito_sdk/dito_sdk.dart';

final ditoSdk = DitoSdk();

void setupPushClickHandling() {
  DitoSdk.onNotificationClick.listen((event) {
    final deeplink = event.deeplink;
    if (deeplink.isEmpty) return;
    // Navegação do seu app aqui
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    await ditoSdk.handleNotificationClick(message.data);
  });
}
```

### Exemplo React Native

```typescript
import DitoSdk, { addNotificationClickListener } from '@ditointernet/dito-sdk';

const unsubscribe = addNotificationClickListener((event) => {
  if (!event.deeplink) return;
  // Navegação do seu app aqui
});

// Quando o clique for detectado no JS (ex.: firebase messaging), delegue para o SDK:
await DitoSdk.handleNotificationClick(message.data);
```

## 🔗 Deeplinks e Navegação

O SDK extrai automaticamente o `link` do payload da notificação e fornece através do callback/evento.

### Formato de Deeplink

O deeplink deve estar no formato de URL:
- `https://app.example.com/product/123`
- `myapp://product/123`
- `dito://action/123`

### Navegação

Cada plataforma tem sua própria forma de processar deeplinks:

- **iOS**: Usar `UIApplication.shared.open(url)`
- **Android**: Usar `Intent` com `ACTION_VIEW`
- **Flutter**: Usar plugins de navegação/deeplink
- **React Native**: Usar bibliotecas de navegação/deeplink

## 🐛 Troubleshooting Unificado

### Notificações não são recebidas

**Checklist Geral**:
1. ✅ Firebase configurado corretamente
2. ✅ Arquivos de configuração adicionados (`GoogleService-Info.plist` / `google-services.json`)
3. ✅ Permissões solicitadas
4. ✅ Token FCM registrado no SDK (`Dito.registerDevice(token)` / `DitoSdk.registerDeviceToken(token)`)
5. ✅ Campo `channel` igual a `"DITO"` no payload

### Notificações não são interceptadas pelo SDK

**Causa**: Campo `channel` não é `"DITO"` ou não está presente.

**Solução**: Certifique-se de que o payload da notificação inclui `"channel": "DITO"`.

### Deeplinks não funcionam

**Causa**: Deeplink não está no formato correto ou não está sendo processado.

**Solução**:
1. Verifique se o deeplink está no payload como `"link"`
2. Implemente o callback corretamente
3. Configure o tratamento de deeplinks no app

### iOS: Erro "APNS device token not set"

**Causa**: Ordem incorreta de inicialização no iOS 18+.

**Solução**: Siga a ordem exata:
1. `FirebaseApp.configure()`
2. `Messaging.messaging().delegate = self`
3. `Dito.shared.configure()`
4. No `didRegisterForRemoteNotificationsWithDeviceToken`, defina `Messaging.messaging().apnsToken = deviceToken` ANTES de solicitar o token FCM

## 📝 Exemplos de Payload

### Payload Completo

```json
{
  "channel": "DITO",
  "notification": "notif-123",
  "reference": "user-456",
  "link": "https://app.example.com/product/789",
  "log_id": "log-abc",
  "notification_name": "Promoção Especial",
  "user_id": "user-456",
  "data": {
    "custom_field": "custom_value"
  }
}
```

### Payload Mínimo

```json
{
  "channel": "DITO",
  "notification": "notif-123",
  "reference": "user-456"
}
```

## 🔗 Links Úteis

- 🔥 [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- 📱 [iOS Push Notifications Guide](../ios/README.md#-push-notifications)
- 🤖 [Android Push Notifications Guide](../android/README.md#push-notifications)
- 🎯 [Flutter Push Notifications Guide](../flutter/README.md#push-notifications)
- ⚛️ [React Native Push Notifications Guide](../react-native/README.md#push-notifications)

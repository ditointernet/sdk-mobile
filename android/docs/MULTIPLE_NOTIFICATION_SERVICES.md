# Integração com Múltiplos Serviços de Notificação

## 📋 Visão Geral

O Android permite apenas **UM** `FirebaseMessagingService` por aplicação. Se você precisa integrar múltiplos SDKs de notificação (Dito, OneSignal, Braze, etc.) ou implementar lógica customizada, você precisa criar um **serviço delegador**.

## 🏗️ Arquitetura

### Problema
```
❌ NÃO FUNCIONA - Apenas um será usado:
<service android:name="br.com.dito.ditosdk.notification.DitoMessagingService" />
<service android:name="com.onesignal.OneSignalMessagingService" />
<service android:name="com.myapp.CustomMessagingService" />
```

### Solução
```
✅ FUNCIONA - Um serviço que delega para múltiplos handlers:
<service android:name="com.myapp.CustomMessagingService" />
  ↓
  ├─> DitoNotificationHandler (processa notificações DITO)
  ├─> OneSignalHandler (processa notificações OneSignal)
  └─> CustomHandler (processa suas notificações)
```

## 🚀 Implementação

### Opção 1: Usar DitoMessagingService (Apenas Dito)

Se você **NÃO** precisa de outros serviços, use o serviço fornecido:

```xml
<!-- AndroidManifest.xml -->
<service
    android:name="br.com.dito.ditosdk.notification.DitoMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

### Opção 2: Serviço Delegador (Múltiplos SDKs)

Se você precisa integrar com **OneSignal, Braze, ou lógica customizada**:

#### 1. Criar Serviço Customizado

```kotlin
package com.myapp

import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import br.com.dito.ditosdk.notification.DitoNotificationHandler
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyMessagingService : FirebaseMessagingService() {

    private val ditoHandler by lazy { DitoNotificationHandler(applicationContext) }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Notification received")

        when {
            // Dito SDK
            ditoHandler.canHandle(remoteMessage) -> {
                Log.d(TAG, "Delegating to Dito")
                ditoHandler.handleNotification(remoteMessage)
            }

            // OneSignal
            isOneSignalNotification(remoteMessage) -> {
                Log.d(TAG, "Delegating to OneSignal")
                // OneSignal.handleNotification(remoteMessage)
            }

            // Braze
            isBrazeNotification(remoteMessage) -> {
                Log.d(TAG, "Delegating to Braze")
                // Braze.handleNotification(remoteMessage)
            }

            // Custom
            else -> {
                Log.d(TAG, "Handling custom notification")
                handleCustomNotification(remoteMessage)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onNewToken(token: String) {
        super.onNewToken(token)

        // Registrar token em todos os serviços
        ditoHandler.handleNewToken(token)
        // OneSignal.setToken(token)
        // Braze.registerToken(token)
    }

    private fun isOneSignalNotification(remoteMessage: RemoteMessage): Boolean {
        return remoteMessage.data.containsKey("custom") &&
               remoteMessage.data["custom"]?.contains("\"i\":") == true
    }

    private fun isBrazeNotification(remoteMessage: RemoteMessage): Boolean {
        return remoteMessage.data.containsKey("_ab")
    }

    private fun handleCustomNotification(remoteMessage: RemoteMessage) {
        // Sua lógica customizada
    }

    companion object {
        private const val TAG = "MyMessagingService"
    }
}
```

#### 2. Registrar no AndroidManifest.xml

```xml
<service
    android:name=".MyMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

**IMPORTANTE:** Remova o `DitoMessagingService` do manifest se estiver usando serviço customizado.

## 🔍 Como Funciona

### DitoNotificationHandler

O SDK fornece a classe `DitoNotificationHandler` que pode ser usada em qualquer `FirebaseMessagingService`:

```kotlin
val ditoHandler = DitoNotificationHandler(context)

// Verificar se a notificação é do Dito
if (ditoHandler.canHandle(remoteMessage)) {
    // Processar notificação
    ditoHandler.handleNotification(remoteMessage)
}

// Registrar novo token
ditoHandler.handleNewToken(token)
```

### Identificação de Notificações

O Dito identifica suas notificações pelo campo `channel`:

```json
{
  "data": {
    "channel": "DITO",
    "notification": "...",
    "reference": "..."
  }
}
```

O método `canHandle()` verifica:
```kotlin
remoteMessage.data["channel"] == "DITO"
```

## 📱 Exemplos de Integração

### Com OneSignal

```kotlin
class MyMessagingService : FirebaseMessagingService() {

    private val ditoHandler by lazy { DitoNotificationHandler(applicationContext) }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        when {
            ditoHandler.canHandle(remoteMessage) -> {
                ditoHandler.handleNotification(remoteMessage)
            }
            isOneSignalNotification(remoteMessage) -> {
                // OneSignal processa automaticamente se estiver configurado
                // Ou você pode chamar manualmente:
                // OneSignal.handleNotificationReceived(remoteMessage)
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        ditoHandler.handleNewToken(token)
        OneSignal.setExternalUserId(token)
    }

    private fun isOneSignalNotification(msg: RemoteMessage): Boolean {
        return msg.data.containsKey("custom") &&
               msg.data["custom"]?.contains("\"i\":") == true
    }
}
```

### Com Braze

```kotlin
class MyMessagingService : FirebaseMessagingService() {

    private val ditoHandler by lazy { DitoNotificationHandler(applicationContext) }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        when {
            ditoHandler.canHandle(remoteMessage) -> {
                ditoHandler.handleNotification(remoteMessage)
            }
            BrazeFirebaseMessagingService.handleBrazeRemoteMessage(this, remoteMessage) -> {
                // Braze processou a notificação
            }
            else -> {
                // Sua lógica customizada
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        ditoHandler.handleNewToken(token)
        Braze.getInstance(this).registeredPushToken = token
    }
}
```

### Com Lógica Customizada

```kotlin
class MyMessagingService : FirebaseMessagingService() {

    private val ditoHandler by lazy { DitoNotificationHandler(applicationContext) }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        when (remoteMessage.data["type"]) {
            "DITO" -> ditoHandler.handleNotification(remoteMessage)
            "PROMO" -> handlePromoNotification(remoteMessage)
            "ALERT" -> handleAlertNotification(remoteMessage)
            else -> handleDefaultNotification(remoteMessage)
        }
    }

    private fun handlePromoNotification(msg: RemoteMessage) {
        // Exibir notificação de promoção com estilo customizado
    }

    private fun handleAlertNotification(msg: RemoteMessage) {
        // Exibir alerta urgente
    }
}
```

## ✅ Checklist de Integração

- [ ] Decidir se precisa de serviço customizado (múltiplos SDKs) ou usar `DitoMessagingService`
- [ ] Se customizado:
  - [ ] Criar classe que estende `FirebaseMessagingService`
  - [ ] Instanciar `DitoNotificationHandler`
  - [ ] Implementar `onMessageReceived()` com lógica de delegação
  - [ ] Implementar `onNewToken()` para todos os serviços
  - [ ] Registrar serviço no `AndroidManifest.xml`
  - [ ] **Remover** `DitoMessagingService` do manifest
- [ ] Testar notificações de cada serviço
- [ ] Verificar logs para confirmar delegação correta

## 🐛 Troubleshooting

### Notificações não aparecem

1. **Verificar qual serviço está registrado:**
```bash
adb shell dumpsys package com.seu.app | grep -A 5 "Service"
```

2. **Verificar logs:**
```bash
adb logcat | grep -E "DitoNotificationHandler|MyMessagingService"
```

3. **Confirmar que apenas UM serviço está no manifest:**
```bash
grep -r "FirebaseMessagingService" app/src/main/AndroidManifest.xml
```

### Múltiplos serviços no manifest

Se você declarou múltiplos serviços, **apenas um será usado** (geralmente o último). Solução:
1. Manter apenas um serviço customizado
2. Usar `DitoNotificationHandler` dentro dele

### Token não é registrado

Certifique-se de chamar `handleNewToken()` para todos os handlers:

```kotlin
override fun onNewToken(token: String) {
    super.onNewToken(token)
    ditoHandler.handleNewToken(token)
    // outros handlers...
}
```

## 📚 Referências

- [Firebase Cloud Messaging - Android](https://firebase.google.com/docs/cloud-messaging/android/receive)
- [OneSignal - Custom FCM Integration](https://documentation.onesignal.com/docs/android-native-sdk#custom-fcm-integration)
- [Braze - Firebase Integration](https://www.braze.com/docs/developer_guide/platform_integration_guides/android/push_notifications/android/integration/standard_integration/)

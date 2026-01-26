# Configuração do Firebase Cloud Messaging com Dito SDK

Este guia explica como configurar o Firebase Cloud Messaging (FCM) para usar o `DitoMessagingService` fornecido pelo SDK.

## 📋 Visão Geral

O Dito SDK fornece uma classe `DitoMessagingService` que gerencia automaticamente:
- ✅ Recebimento de notificações push
- ✅ Registro automático do token FCM
- ✅ Chamada de `Dito.notificationRead()` quando notificações chegam
- ✅ Exibição de notificações no sistema
- ✅ Gerenciamento de deep links
- ✅ Tracking de abertura de notificações

## 🚀 Configuração Básica

### 1. Adicionar o Serviço no AndroidManifest.xml

```xml
<service
    android:name="br.com.dito.ditosdk.notification.DitoMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

### 2. Configurar API Keys

Adicione suas credenciais do Dito no `AndroidManifest.xml`:

```xml
<meta-data
    android:name="br.com.dito.API_KEY"
    android:value="sua-api-key-aqui" />
<meta-data
    android:name="br.com.dito.API_SECRET"
    android:value="seu-api-secret-aqui" />
```

### 3. Inicializar o SDK

Na sua classe `Application`:

```kotlin
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        val options = Options(retry = 5)
        options.debug = true
        Dito.init(this, options)
    }
}
```

### 4. Adicionar google-services.json

Coloque o arquivo `google-services.json` do Firebase em `app/src/`.

## 📱 Funcionalidades Automáticas

### Registro de Token

O `DitoMessagingService` registra automaticamente o token FCM quando:
- O app é instalado pela primeira vez
- O token é renovado pelo Firebase

```kotlin
override fun onNewToken(token: String) {
    super.onNewToken(token)
    if (!Dito.isInitialized()) {
        Dito.init(applicationContext, null)
    }
    Dito.registerDevice(token)
}
```

### Processamento de Notificações

Quando uma notificação chega, o serviço:
1. Extrai os dados da notificação
2. Chama `Dito.notificationRead()` automaticamente
3. Exibe a notificação no sistema
4. Gerencia o deep link (se presente)

## 📦 Formato das Notificações

As notificações devem seguir este formato:

```json
{
  "data": {
    "notification": "notification_id",
    "reference": "user_reference",
    "log_id": "log_id",
    "user_id": "user_id",
    "details": {
      "title": "Título da Notificação",
      "message": "Mensagem da Notificação",
      "link": "deeplink://app/path",
      "notification_name": "Nome da Notificação"
    }
  }
}
```

### Campos Obrigatórios

- `notification`: ID da notificação (String ou Int)
- `reference`: Referência do usuário (String)

### Campos Opcionais

- `log_id`: ID do log
- `user_id`: ID do usuário
- `details.title`: Título da notificação
- `details.message`: Mensagem da notificação
- `details.link`: Deep link para abrir
- `details.notification_name`: Nome da notificação

## 🎨 Personalização (Opcional)

### Customizar Ícone da Notificação

```kotlin
val options = Options(retry = 5)
options.iconNotification = R.drawable.ic_notification
Dito.init(this, options)
```

### Customizar Intent de Conteúdo

```kotlin
val options = Options(retry = 5)
val intent = Intent(this, CustomActivity::class.java)
options.contentIntent = intent
Dito.init(this, options)
```

### Modo Híbrido (para apps híbridos)

```kotlin
// No AndroidManifest.xml
<meta-data
    android:name="br.com.dito.HIBRID_MODE"
    android:value="ON" />
```

## 🔧 Implementação Customizada (Avançado)

Se você precisar de comportamento customizado, pode estender o `DitoMessagingService`:

```kotlin
class MyCustomMessagingService : DitoMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Seu código customizado aqui

        // Chame o super para manter funcionalidade do Dito
        super.onMessageReceived(remoteMessage)
    }

    override fun onNewToken(token: String) {
        // Seu código customizado aqui

        // Chame o super para registrar no Dito
        super.onNewToken(token)
    }
}
```

E atualize o `AndroidManifest.xml`:

```xml
<service
    android:name=".MyCustomMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

## 🐛 Troubleshooting

### Token não está sendo registrado

1. Verifique se o Firebase está inicializado antes do Dito SDK
2. Verifique se as credenciais API_KEY e API_SECRET estão corretas
3. Verifique os logs com tag "DitoMessagingService"

### Notificações não aparecem

1. Verifique se o formato da notificação está correto
2. Verifique se os campos obrigatórios (`notification` e `reference`) estão presentes
3. Verifique as permissões de notificação no Android 13+

### Deep links não funcionam

1. Verifique se o campo `details.link` está presente
2. Configure o `contentIntent` nas opções do SDK
3. Verifique se a Activity de destino está declarada no Manifest

## 📚 Referências

- [Documentação Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Documentação Dito SDK](../README.md)
- [Exemplo Completo](MainActivity.kt)

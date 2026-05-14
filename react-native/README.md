# Dito SDK React Native Plugin

Plugin React Native oficial da Dito para integração com o CRM Dito, fornecendo APIs unificadas para iOS e Android.

## 📋 Visão Geral

O **Dito SDK React Native Plugin** é a biblioteca oficial da Dito para aplicações React Native, permitindo que você integre seu app com a plataforma de CRM e Marketing Automation da Dito.

Com o Dito SDK React Native Plugin você pode:

- 🔐 **Identificar usuários** e sincronizar seus dados com a plataforma
- 📊 **Rastrear eventos** e comportamentos dos usuários
- 🔔 **Gerenciar notificações push** via Firebase Cloud Messaging
- 💾 **Gerenciar dados offline** automaticamente

## 📱 Requisitos

| Requisito        | Versão Mínima |
| ---------------- | ------------- |
| React Native     | 0.72.0+       |
| React            | 18.0.0+       |
| TypeScript       | 5.0+          |
| Node.js          | 16+           |
| iOS              | 16.0+         |
| Android API      | 25+           |

## 📦 Instalação

### Via npm

```bash
npm install @ditointernet/dito-sdk
```

### Via yarn

```bash
yarn add @ditointernet/dito-sdk
```

### Linking Nativo

O plugin requer linking nativo. Siga as instruções de configuração para [iOS](../ios/README.md) e [Android](../android/README.md).

```bash
npm install @ditointernet/dito-sdk
# ou
yarn add @ditointernet/dito-sdk
```

**Nota para iOS**: O SDK iOS é automaticamente instalado via CocoaPods quando você executa `pod install` no diretório `ios/` do seu projeto React Native, pois o plugin já está configurado para usar o monorepo com `:subdirectory => 'ios'`.

## ⚙️ Configuração Inicial

### 1. Configure as plataformas nativas

#### iOS

Execute `pod install` no diretório `ios/` do seu projeto React Native:

```bash
cd ios
pod install
cd ..
```

O SDK iOS será instalado automaticamente do monorepo. Para mais detalhes, consulte o [iOS README](../ios/README.md).

#### Android

Siga as instruções de configuração em [Android README](../android/README.md).

### 2. Inicialize o SDK

```typescript
import DitoSdk from '@ditointernet/dito-sdk';

try {
  await DitoSdk.initialize({
    apiKey: 'your-api-key',
    apiSecret: 'your-api-secret',
  });
  console.log('SDK initialized successfully');
} catch (error) {
  console.error('Failed to initialize:', error.message);
}
```

## 📖 Métodos Disponíveis

### initialize

**Descrição**: Inicializa o Dito SDK com as credenciais fornecidas. Este método deve ser chamado antes de usar qualquer outro método do SDK.

**Assinatura**:
```typescript
static async initialize(options: {
  apiKey: string;
  apiSecret: string;
}): Promise<void>
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| apiKey | string | Sim | Chave API fornecida pela Dito |
| apiSecret | string | Sim | Segredo API fornecido pela Dito |

**Retorno**: `Promise<void>`

**Possíveis Erros**:
- `DitoError` com código `INVALID_PARAMETERS`: Se `apiKey` ou `apiSecret` forem null ou vazios
- `DitoError` com código `INITIALIZATION_FAILED`: Se a inicialização falhar
- `DitoError` com código `INVALID_CREDENTIALS`: Se as credenciais forem inválidas

**Exemplo**:
```typescript
try {
  await DitoSdk.initialize({
    apiKey: 'your-api-key',
    apiSecret: 'your-api-secret',
  });
} catch (error) {
  console.error('Failed to initialize:', error.message);
}
```

**Notas**:
- Deve ser chamado apenas uma vez durante o ciclo de vida do app
- Deve ser chamado antes de qualquer outro método do SDK

---

### identify

**Descrição**: Identifica um usuário no CRM Dito.

**Assinatura**:
```typescript
static async identify(options: {
  id: string;
  name?: string;
  email?: string;
  customData?: Record<string, any>;
}): Promise<void>
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| id | string | Sim | Identificador único do usuário |
| name | string? | Não | Nome do usuário |
| email | string? | Não | Email do usuário (deve ser válido se fornecido) |
| customData | Record<string, any>? | Não | Dados customizados adicionais |

**Retorno**: `Promise<void>`

**Possíveis Erros**:
- `DitoError` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `DitoError` com código `INVALID_PARAMETERS`: Se `id` for null ou vazio, ou se `email` for inválido

**Exemplo**:
```typescript
try {
  await DitoSdk.identify({
    id: 'user123',
    name: 'John Doe',
    email: 'john@example.com',
    customData: { type: 'premium', points: 1500 },
  });
} catch (error) {
  console.error('Error:', error.message);
}
```

**Notas**:
- O usuário deve ser identificado antes de rastrear eventos
- O email é opcional, mas se fornecido deve ser válido

---

### track

**Descrição**: Rastreia um evento no CRM Dito.

**Assinatura**:
```typescript
static async track(options: {
  action: string;
  data?: Record<string, any>;
}): Promise<void>
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| action | string | Sim | Nome da ação do evento |
| data | Record<string, any>? | Não | Dados adicionais do evento |

**Retorno**: `Promise<void>`

**Possíveis Erros**:
- `DitoError` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `DitoError` com código `INVALID_PARAMETERS`: Se `action` for null ou vazio

**Exemplo**:
```typescript
try {
  await DitoSdk.track({
    action: 'purchase',
    data: { product: 'item123', price: 99.99 },
  });
} catch (error) {
  console.error('Error:', error.message);
}
```

**Notas**:
- O usuário deve ser identificado antes de rastrear eventos
- Dados são sincronizados automaticamente em background

---

### logout

**Descrição**: Limpa a identidade local persistida pelo `identify` e a identidade local usada por tracking. Use após a saída de conta no app host para evitar que eventos futuros reutilizem o usuário anterior.

**Assinatura**:
```typescript
DitoSdk.logout(): Promise<void>
```

**Retorno**: `Promise<void>`

**Possíveis Erros**:
- `DitoError` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado

**Exemplo**:
```typescript
async function handleAccountSignOut() {
  await signOutAccount();
  await DitoSdk.logout();
}
```

**Notas**:
- Deve ser chamado após `DitoSdk.initialize(...)`
- O plugin React Native encaminha a operação para as SDKs nativas Android e iOS
- O efeito é local: remove dados persistidos por `identify` e identidade local usada por tracking
- Não remove credenciais ou configuração da SDK, opções de notificação, inbox de notificações, tokens de push ou dados remotos no backend

---

### registerDeviceToken

**Descrição**: Registra um token de dispositivo para receber push notifications.

**Assinatura**:
```typescript
static async registerDeviceToken(token: string): Promise<void>
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| token | string | Sim | Token FCM do dispositivo |

**Retorno**: `Promise<void>`

**Possíveis Erros**:
- `DitoError` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `DitoError` com código `INVALID_PARAMETERS`: Se `token` for null ou vazio

**Exemplo**:
```typescript
import messaging from '@react-native-firebase/messaging';

const token = await messaging().getToken();
if (token) {
  await DitoSdk.registerDeviceToken(token);
}
```

**Notas**:
- Deve ser chamado após obter o token FCM do Firebase
- O token deve ser atualizado sempre que o Firebase gerar um novo token

---

### unregisterDeviceToken

**Descrição**: Remove o registro de um token de dispositivo para parar de receber push notifications.

**Assinatura**:
```typescript
static async unregisterDeviceToken(token: string): Promise<void>
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| token | string | Sim | Token FCM do dispositivo a ser removido |

**Retorno**: `Promise<void>`

**Possíveis Erros**:
- `DitoError` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `DitoError` com código `INVALID_PARAMETERS`: Se `token` for null ou vazio

**Exemplo**:
```typescript
const token = await messaging().getToken();
if (token) {
  await DitoSdk.unregisterDeviceToken(token);
}
```

**Notas**:
- Use este método quando o usuário fizer logout ou desabilitar notificações

## 🔔 Push Notifications

Para um guia completo de configuração de Push Notifications, consulte o [guia unificado](../docs/push-notifications.md).

### Configuração Básica

1. Configure o Firebase no seu projeto React Native
2. Instale o plugin `@react-native-firebase/messaging`:

```bash
npm install @react-native-firebase/messaging
```

3. Configure o tratamento de notificações conforme mostrado abaixo.

### Customização de Notificações — `setNotificationOptions`

Use `setNotificationOptions` para personalizar a aparência das notificações push geradas pelo Dito SDK. Suportado em **Android** e **iOS**.

**Assinatura**:
```typescript
static async setNotificationOptions(options: DitoNotificationOptions): Promise<void>
```

**Interface `DitoNotificationOptions`**:

| Campo | Tipo | Plataforma | Descrição |
|-------|------|------------|-----------|
| `smallIconResId` | `number?` | Android | Resource ID do ícone pequeno na barra de status |
| `largeIconResId` | `number?` | Android | Resource ID do ícone grande na notificação expandida |
| `soundResourceName` | `string?` | Android/iOS | Nome do recurso de som personalizado |
| `accentColor` | `number?` | Android | Cor de destaque em formato ARGB (ex: `0xFF1A73E8`) |
| `badgeEnabled` | `boolean?` | Android/iOS | Habilita badge no ícone do app (padrão: `true`) |

**Exemplo**:
```typescript
import DitoSdk, { DitoNotificationOptions } from '@ditointernet/dito-sdk';

const notificationOptions: DitoNotificationOptions = {
  smallIconResId: R.drawable.ic_notification,
  soundResourceName: 'custom_sound',
  accentColor: 0xFF1A73E8,
  badgeEnabled: true,
};

await DitoSdk.setNotificationOptions(notificationOptions);
```

> **Nota**: Recomenda-se chamar `setNotificationOptions` durante a inicialização do app, antes de receber qualquer notificação.

## ⚠️ Tratamento de Erros

O plugin fornece mensagens de erro descritivas para facilitar o debugging:

- **INITIALIZATION_FAILED**: Falha na inicialização do SDK. Verifique suas credenciais e configuração.
- **INVALID_CREDENTIALS**: Credenciais inválidas fornecidas. Verifique seu apiKey e apiSecret.
- **NOT_INITIALIZED**: Método chamado antes da inicialização. Chame `initialize()` primeiro.
- **INVALID_PARAMETERS**: Parâmetros inválidos fornecidos. Verifique a documentação do método.
- **NETWORK_ERROR**: Erro de rede durante a operação. Verifique sua conexão com a internet.

Todas as mensagens de erro incluem detalhes adicionais sobre como resolver o problema.

**Exemplo de tratamento de erros**:

```typescript
import DitoSdk, { DitoErrorCode } from '@ditointernet/dito-sdk';

try {
  await DitoSdk.initialize({
    apiKey: apiKey,
    apiSecret: apiSecret,
  });
} catch (error: any) {
  switch (error.code) {
    case DitoErrorCode.INITIALIZATION_FAILED:
      console.error('Failed to initialize SDK');
      break;
    case DitoErrorCode.INVALID_CREDENTIALS:
      console.error('Invalid credentials');
      break;
    default:
      console.error('Error:', error.message);
  }
}
```

### Android

No seu `FirebaseMessagingService`, chame o método estático para interceptar notificações:

```kotlin
import br.com.dito.DitoSdkModule
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Verifica se a notificação é do canal Dito
        if (DitoSdkModule.handleNotification(this, remoteMessage)) {
            // Notificação foi processada pelo Dito SDK
            return
        }

        // Processar outras notificações normalmente
        // ...
    }
}
```

### iOS

No seu `UNUserNotificationCenterDelegate`, chame os métodos estáticos:

```swift
import DitoSdkModule
import UserNotifications

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let request = notification.request

        // Verifica se a notificação é do canal Dito
        if DitoSdkModule.didReceiveNotificationRequest(request, fcmToken: fcmToken) {
            // Notificação foi processada pelo Dito SDK
        }

        completionHandler([[.banner, .list, .sound, .badge]])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Verifica se a notificação é do canal Dito e processa o clique
        DitoSdkModule.didReceiveNotificationClick(userInfo: userInfo) { deeplink in
            // Processar deeplink se necessário
            // Navegar para deeplink
        }

        completionHandler()
    }
}
```

**Importante**: As notificações são processadas apenas se o campo `channel` nos dados da notificação for igual a `"Dito"`. Caso contrário, os métodos retornam `false` e a notificação deve ser processada normalmente pelo app.

## 💡 Exemplos Completos

### Exemplo Básico

```typescript
import React, { useEffect } from 'react';
import { View, Button, Alert } from 'react-native';
import DitoSdk from '@ditointernet/dito-sdk';

export default function App() {
  useEffect(() => {
    const initSDK = async () => {
      try {
        await DitoSdk.initialize({
          apiKey: 'your-api-key',
          apiSecret: 'your-api-secret',
        });
      } catch (error: any) {
        Alert.alert('Error', error.message);
      }
    };

    initSDK();
  }, []);

  const handleIdentify = async () => {
    try {
      await DitoSdk.identify({
        id: 'user123',
        name: 'John Doe',
        email: 'john@example.com',
        customData: { source: 'react_native_app' },
      });
      Alert.alert('Success', 'User identified');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleTrack = async () => {
    try {
      await DitoSdk.track({
        action: 'purchase',
        data: { product_id: 'item123', price: 99.99 },
      });
      Alert.alert('Success', 'Event tracked');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  return (
    <View>
      <Button title="Identify User" onPress={handleIdentify} />
      <Button title="Track Event" onPress={handleTrack} />
    </View>
  );
}
```

## Troubleshooting

### Erro: "Dito SDK requires API_KEY and API_SECRET to be configured in AndroidManifest.xml"

**Solução**: Adicione as credenciais no `AndroidManifest.xml` do seu app:

```xml
<meta-data
    android:name="br.com.dito.API_KEY"
    android:value="your-api-key" />
<meta-data
    android:name="br.com.dito.API_SECRET"
    android:value="your-api-secret" />
```

### Erro: "Dito SDK is not initialized"

**Solução**: Certifique-se de chamar `DitoSdk.initialize()` antes de usar qualquer outro método:

```typescript
await DitoSdk.initialize({
  apiKey: 'your-api-key',
  apiSecret: 'your-api-secret',
});
```

### Push notifications não são interceptadas

**Solução**:
1. Verifique se o método estático está sendo chamado corretamente no código nativo
2. Confirme que o campo `channel` na notificação é igual a `"Dito"`
3. No Android, certifique-se de que o `FirebaseMessagingService` está configurado
4. No iOS, verifique se o `UNUserNotificationCenterDelegate` está implementado

### Erro: "Invalid email format"

**Solução**: Verifique se o email fornecido está no formato correto (ex: `user@example.com`). O email é opcional, então você pode passar `undefined` se não tiver um email válido.

### Performance

O SDK foi otimizado para:
- Inicialização < 100ms
- Operações (identify, track, registerDeviceToken) < 16ms

Se você estiver enfrentando problemas de performance, verifique:
- Se o SDK está sendo inicializado apenas uma vez
- Se não há múltiplas chamadas simultâneas desnecessárias

### Problemas de Build

**Android:**
- Certifique-se de que o `minSdkVersion` é pelo menos 24
- Verifique se todas as dependências estão sincronizadas

**iOS:**
- Certifique-se de que o iOS deployment target é pelo menos 16.0
- Execute `pod install` no diretório `ios/` do seu projeto React Native
- O SDK iOS é instalado automaticamente do monorepo via `:subdirectory => 'ios'`

### Eventos não aparecem no painel Dito

**Checklist**:
1. ✅ SDK inicializado (`DitoSdk.initialize()`)
2. ✅ Usuário identificado ANTES de rastrear eventos
3. ✅ Conexão com internet (ou aguardar sincronização offline)

```typescript
// ❌ ERRADO - evento antes da identificação
await DitoSdk.track({ action: 'purchase', data: { product: 'item123' } });
await DitoSdk.identify({ id: userId, name: 'John', email: 'john@example.com' });

// ✅ CORRETO - identifique primeiro
await DitoSdk.identify({ id: userId, name: 'John', email: 'john@example.com' });
await DitoSdk.track({ action: 'purchase', data: { product: 'item123' } });
```

## 📄 Licença

Este projeto está licenciado sob uma licença proprietária. Veja [LICENSE](../LICENSE) para detalhes completos dos termos de licenciamento.

**Resumo dos Termos:**
- ✅ Permite uso das SDKs em aplicações comerciais
- ✅ Permite uso em aplicações próprias dos clientes
- ❌ Proíbe modificação do código fonte
- ❌ Proíbe cópia e redistribuição do código

## 🔗 Links Úteis

- 🌐 [Website Dito](https://www.dito.com.br)
- 📚 [Documentação Dito](https://developers.dito.com.br)
- 📖 [React Native Documentation](https://reactnative.dev/docs/getting-started)
- 📘 [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- 🔥 [Firebase React Native Documentation](https://rnfirebase.io/)
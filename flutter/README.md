# Dito SDK Flutter Plugin

Plugin Flutter oficial da Dito para integração com o CRM Dito, fornecendo APIs unificadas para iOS e Android.

## 📋 Visão Geral

O **Dito SDK Flutter Plugin** é a biblioteca oficial da Dito para aplicações Flutter, permitindo que você integre seu app com a plataforma de CRM e Marketing Automation da Dito.

Com o Dito SDK Flutter Plugin você pode:

- 🔐 **Identificar usuários** e sincronizar seus dados com a plataforma
- 📊 **Rastrear eventos** e comportamentos dos usuários
- 🔔 **Gerenciar notificações push** via Firebase Cloud Messaging
- 💾 **Gerenciar dados offline** automaticamente

## 📱 Requisitos

| Requisito        | Versão Mínima |
| ---------------- | ------------- |
| Flutter          | 3.3.0+        |
| Dart             | 3.10.7+       |
| iOS              | 16.0+         |
| Android API      | 24+           |

## 📦 Instalação

### 1. Adicione a dependência no `pubspec.yaml`

```yaml
dependencies:
  dito_sdk:
    path: ../flutter
```

Ou se publicado no pub.dev:

```yaml
dependencies:
  dito_sdk: ^1.0.0
```

### 2. Instale as dependências

```bash
flutter pub get
```

### 3. Configure as plataformas nativas

Siga as instruções de configuração para [iOS](../ios/README.md) e [Android](../android/README.md).

## ⚙️ Configuração Inicial

### 1. Inicialize o SDK

```dart
import 'package:dito_sdk/dito_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DitoSdk.initialize(
      apiKey: "sua-api-key",
      apiSecret: "seu-api-secret",
    );
    print('SDK initialized successfully');
  } catch (e) {
    print('Failed to initialize: $e');
  }

  runApp(MyApp());
}
```

## 📖 Métodos Disponíveis

### initialize

**Descrição**: Inicializa o Dito SDK com as credenciais fornecidas. Este método deve ser chamado antes de usar qualquer outro método do SDK.

**Assinatura**:
```dart
Future<void> initialize({
  required String apiKey,
  required String apiSecret,
})
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| apiKey | String | Sim | Chave API fornecida pela Dito |
| apiSecret | String | Sim | Segredo API fornecido pela Dito |

**Retorno**: `Future<void>`

**Possíveis Erros**:
- `PlatformException` com código `INVALID_PARAMETERS`: Se `apiKey` ou `apiSecret` forem null ou vazios
- `PlatformException` com código `INITIALIZATION_FAILED`: Se a inicialização falhar
- `PlatformException` com código `INVALID_CREDENTIALS`: Se as credenciais forem inválidas

**Exemplo**:
```dart
try {
  await DitoSdk.initialize(
    apiKey: "sua-api-key",
    apiSecret: "seu-api-secret",
  );
  print('SDK initialized successfully');
} on PlatformException catch (e) {
  print('Failed to initialize: ${e.message}');
}
```

**Notas**:
- Deve ser chamado apenas uma vez durante o ciclo de vida do app
- Deve ser chamado antes de qualquer outro método do SDK

---

### identify

**Descrição**: Identifica um usuário no CRM Dito.

**Assinatura**:
```dart
Future<void> identify({
  required String id,
  String? name,
  String? email,
  Map<String, dynamic>? customData,
})
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| id | String | Sim | Identificador único do usuário |
| name | String? | Não | Nome do usuário |
| email | String? | Não | Email do usuário (deve ser válido se fornecido) |
| customData | Map<String, dynamic>? | Não | Dados customizados adicionais |

**Retorno**: `Future<void>`

**Possíveis Erros**:
- `PlatformException` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `PlatformException` com código `INVALID_PARAMETERS`: Se `id` for null ou vazio, ou se `email` for inválido

**Exemplo**:
```dart
try {
  await DitoSdk.identify(
    id: 'user123',
    name: 'João Silva',
    email: 'joao@example.com',
    customData: {
      'tipo_cliente': 'premium',
      'pontos': 1500,
    },
  );
} on PlatformException catch (e) {
  print('Error: ${e.message}');
}
```

**Notas**:
- O usuário deve ser identificado antes de rastrear eventos
- O email é opcional, mas se fornecido deve ser válido

---

### track

**Descrição**: Rastreia um evento no CRM Dito.

**Assinatura**:
```dart
Future<void> track({
  required String action,
  Map<String, dynamic>? data,
})
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| action | String | Sim | Nome da ação do evento |
| data | Map<String, dynamic>? | Não | Dados adicionais do evento |

**Retorno**: `Future<void>`

**Possíveis Erros**:
- `PlatformException` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `PlatformException` com código `INVALID_PARAMETERS`: Se `action` for null ou vazio

**Exemplo**:
```dart
try {
  await DitoSdk.track(
    action: 'purchase',
    data: {
      'product': 'item123',
      'price': 99.99,
      'currency': 'BRL',
    },
  );
} on PlatformException catch (e) {
  print('Error: ${e.message}');
}
```

**Notas**:
- O usuário deve ser identificado antes de rastrear eventos
- Dados são sincronizados automaticamente em background

---

### registerDeviceToken

**Descrição**: Registra um token de dispositivo para receber push notifications.

**Assinatura**:
```dart
Future<void> registerDeviceToken(String token)
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| token | String | Sim | Token FCM do dispositivo |

**Retorno**: `Future<void>`

**Possíveis Erros**:
- `PlatformException` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `PlatformException` com código `INVALID_PARAMETERS`: Se `token` for null ou vazio

**Exemplo**:
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

Future<void> registerDevice() async {
  try {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await DitoSdk.registerDeviceToken(token);
    }
  } on PlatformException catch (e) {
    print('Error: ${e.message}');
  }
}
```

**Notas**:
- Deve ser chamado após obter o token FCM do Firebase
- O token deve ser atualizado sempre que o Firebase gerar um novo token

---

### unregisterDeviceToken

**Descrição**: Remove o registro de um token de dispositivo para parar de receber push notifications.

**Assinatura**:
```dart
Future<void> unregisterDeviceToken(String token)
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| token | String | Sim | Token FCM do dispositivo a ser removido |

**Retorno**: `Future<void>`

**Possíveis Erros**:
- `PlatformException` com código `NOT_INITIALIZED`: Se o SDK não foi inicializado
- `PlatformException` com código `INVALID_PARAMETERS`: Se `token` for null ou vazio

**Exemplo**:
```dart
Future<void> unregisterDevice() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await DitoSdk.unregisterDeviceToken(token);
    }
  } on PlatformException catch (e) {
    print('Error: ${e.message}');
  }
}
```

**Notas**:
- Use este método quando o usuário fizer logout ou desabilitar notificações

---

## 🔔 Push Notifications

Para um guia completo de configuração de Push Notifications, consulte o [guia unificado](../docs/push-notifications.md).

### Configuração Básica

1. Configure o Firebase no seu projeto Flutter
2. Instale o plugin `firebase_messaging`:

```yaml
dependencies:
  firebase_messaging: ^14.0.0
```

3. Configure o tratamento de notificações:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Processar notificação em background
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}
```

## ⚠️ Tratamento de Erros

O SDK Flutter lança `PlatformException` para erros. Todos os erros incluem mensagens descritivas:

- **INITIALIZATION_FAILED**: Falha na inicialização do SDK
- **INVALID_CREDENTIALS**: Credenciais inválidas fornecidas
- **NOT_INITIALIZED**: Método chamado antes da inicialização
- **INVALID_PARAMETERS**: Parâmetros inválidos fornecidos
- **NETWORK_ERROR**: Erro de rede durante a operação

**Exemplo de tratamento de erros**:

```dart
try {
  await DitoSdk.initialize(
    apiKey: apiKey,
    apiSecret: apiSecret,
  );
} on PlatformException catch (e) {
  switch (e.code) {
    case 'INITIALIZATION_FAILED':
      print('Failed to initialize SDK');
      break;
    case 'INVALID_CREDENTIALS':
      print('Invalid credentials');
      break;
    default:
      print('Error: ${e.message}');
  }
}
```

## 🐛 Troubleshooting

### Erro: "Dito SDK is not initialized"

**Solução**: Certifique-se de chamar `DitoSdk.initialize()` antes de usar qualquer outro método:

```dart
await DitoSdk.initialize(
  apiKey: 'your-api-key',
  apiSecret: 'your-api-secret',
);
```

### Erro: "Invalid email format"

**Solução**: Verifique se o email fornecido está no formato correto (ex: `user@example.com`). O email é opcional, então você pode passar `null` se não tiver um email válido.

### Eventos não aparecem no painel Dito

**Checklist**:
1. ✅ SDK inicializado (`DitoSdk.initialize()`)
2. ✅ Usuário identificado ANTES de rastrear eventos
3. ✅ Conexão com internet (ou aguardar sincronização offline)

```dart
// ❌ ERRADO - evento antes da identificação
await DitoSdk.track(action: 'purchase', data: {'product': 'item123'});
await DitoSdk.identify(id: userId, name: 'John', email: 'john@example.com');

// ✅ CORRETO - identifique primeiro
await DitoSdk.identify(id: userId, name: 'John', email: 'john@example.com');
await DitoSdk.track(action: 'purchase', data: {'product': 'item123'});
```

## 💡 Exemplos Completos

### Exemplo Básico

```dart
import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DitoSdk.initialize(
      apiKey: "sua-api-key",
      apiSecret: "seu-api-secret",
    );
  } catch (e) {
    print('Failed to initialize: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  Future<void> _identifyUser() async {
    try {
      await DitoSdk.identify(
        id: 'user123',
        name: 'João Silva',
        email: 'joao@example.com',
        customData: {'source': 'flutter_app'},
      );
      print('User identified successfully');
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _trackEvent() async {
    try {
      await DitoSdk.track(
        action: 'purchase',
        data: {
          'product_id': 'item123',
          'price': 99.99,
          'currency': 'BRL',
        },
      );
      print('Event tracked successfully');
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dito SDK Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _identifyUser,
              child: Text('Identify User'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _trackEvent,
              child: Text('Track Event'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 📄 Licença

Este projeto está licenciado sob uma licença proprietária. Veja [LICENSE](../LICENSE) para detalhes completos dos termos de licenciamento.

**Resumo dos Termos:**
- ✅ Permite uso das SDKs em aplicações comerciais
- ✅ Permite uso em aplicações próprias dos clientes
- ❌ Proíbe modificação do código fonte
- ❌ Proíbe cópia e redistribuição do código

## 🔗 Links Úteis- 🌐 [Website Dito](https://www.dito.com.br)
- 📚 [Documentação Dito](https://developers.dito.com.br)
- 📖 [Flutter Documentation](https://docs.flutter.dev/)
- 🎯 [Dart Documentation](https://dart.dev/guides)
- 🔥 [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
## 🛠️ Desenvolvimento no Monorepo

Este projeto usa **Melos** para gerenciamento de pacotes no monorepo.

### Setup Inicial

```bash
cd flutter
./setup_melos.sh
```

### Comandos Úteis

```bash
cd flutter
melos bootstrap        # Instalar dependências de todos os pacotes
melos run test         # Executar testes
melos run analyze      # Analisar código
melos run format       # Formatar código
melos run check        # Executar todos os checks
```

Para mais informações, consulte o [Guia Melos](./MELOS.md).

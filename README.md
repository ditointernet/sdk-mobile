# Dito SDK Monorepo

Monorepo unificado contendo as SDKs nativas iOS e Android da Dito, além de wrappers Flutter e React Native para integração com o CRM Dito.

## 📋 Visão Geral

Este monorepo contém:

- **SDKs Nativas**: Implementações nativas para iOS e Android
- **Plugins Cross-Platform**: Wrappers Flutter e React Native que fornecem APIs unificadas
- **Documentação**: Guias completos de integração e uso
- **Exemplos**: Apps de exemplo demonstrando o uso de cada plataforma

## 🏗️ Estrutura do Repositório

```
dito_sdk_flutter/
├── ios/              # SDK iOS nativa
│   └── README.md     # Documentação iOS
├── android/          # SDK Android nativa
│   └── README.md     # Documentação Android
├── flutter/          # Plugin Flutter
│   ├── example/      # App de exemplo Flutter
│   ├── README.md     # Documentação Flutter
│   └── LICENSE       # Licença Flutter
├── react-native/     # Plugin React Native
│   ├── example/      # App de exemplo React Native
│   └── README.md     # Documentação React Native
├── docs/             # Documentação adicional
│   ├── push-notifications.md  # Guia unificado de Push Notifications
│   └── todos.md      # Lista de TODOs/FIXMEs
├── scripts/          # Scripts de build e release
├── LICENSE           # Licença do repositório
└── README.md         # Este arquivo
```

## 🚀 Navegação Rápida

- **[iOS SDK](./ios/README.md)** - SDK nativa iOS com guia completo de instalação e uso
- **[Android SDK](./android/README.md)** - SDK nativa Android com guia completo de instalação e uso
- **[Flutter Plugin](./flutter/README.md)** - Plugin Flutter com guia completo
- **[React Native Plugin](./react-native/README.md)** - Plugin React Native com guia completo
- **[Guia de Push Notifications](./docs/push-notifications.md)** - Guia unificado para todas as plataformas
- **[Lista de TODOs/FIXMEs](./docs/todos.md)** - Itens pendentes e melhorias planejadas

## ⚡ Início Rápido

### Flutter

```dart
import 'package:dito_sdk/dito_sdk.dart';

// Inicializar SDK
await DitoSdk.initialize(
  apiKey: "sua-api-key",
  apiSecret: "seu-api-secret",
);

// Identificar usuário
await DitoSdk.identify(
  id: 'user123',
  name: 'John Doe',
  email: 'john@example.com',
);

// Rastrear evento
await DitoSdk.track(
  action: 'purchase',
  data: {'product': 'item123', 'price': 99.99},
);
```

### React Native

```typescript
import DitoSdk from '@ditointernet/dito-sdk';

// Inicializar SDK
await DitoSdk.initialize({
  apiKey: "sua-api-key",
  apiSecret: "seu-api-secret",
});

// Identificar usuário
await DitoSdk.identify({
  id: 'user123',
  name: 'John Doe',
  email: 'john@example.com',
});

// Rastrear evento
await DitoSdk.track({
  action: 'purchase',
  data: { product: 'item123', price: 99.99 },
});
```

Para exemplos completos e guias detalhados, consulte a documentação específica de cada plataforma.

## 🛠️ Desenvolvimento

### Pré-requisitos

- **Flutter**: Flutter 3.3.0+ e Dart 3.10.7+
- **React Native**: React Native 0.72.0+ e Node.js 16+
- **iOS**: Xcode 14+ e iOS 16.0+
- **Android**: Android Studio e Android API 24+

### Build de Todas as Plataformas

```bash
./scripts/build-all.sh
```

### Release Coordenado

```bash
./scripts/release.sh
```

### Executar Exemplos

**Flutter:**
```bash
cd flutter/example
flutter run
```

**React Native:**
```bash
cd react-native/example
npm install
npm run ios  # ou npm run android
```

## 📚 Funcionalidades

### ✅ Implementado

- ✅ Inicialização do SDK
- ✅ Identificação de usuários
- ✅ Rastreamento de eventos
- ✅ Registro de tokens de dispositivo
- ✅ Interceptação de push notifications
- ✅ Tratamento de erros robusto
- ✅ Documentação completa

### 🔄 Em Desenvolvimento

- 🔄 Métricas avançadas
- 🔄 A/B Testing
- 🔄 Personalização de notificações

## 🐛 Troubleshooting

### Problemas Comuns

**Erro de inicialização no Android:**
- Verifique se as credenciais estão configuradas no `AndroidManifest.xml`
- Certifique-se de que o SDK nativo está incluído como dependência

**Erro de inicialização no iOS:**
- Verifique se as credenciais estão configuradas no `Info.plist`
- No iOS 18+, configure o Firebase ANTES do Dito SDK

**Push notifications não funcionam:**
- Verifique se o método estático está sendo chamado corretamente
- Confirme que o campo `channel` na notificação é igual a `"Dito"`

Para mais detalhes, consulte a seção de troubleshooting nos READMEs específicos de cada plataforma ou o [guia unificado de Push Notifications](./docs/push-notifications.md).

## 📄 Licença

Este projeto está licenciado sob uma licença proprietária que permite o uso das SDKs em aplicações comerciais e próprias dos clientes, mas proíbe modificação, cópia e redistribuição do código fonte.

**Resumo dos Termos:**
- ✅ Permite uso das SDKs em aplicações comerciais
- ✅ Permite uso em aplicações próprias dos clientes
- ❌ Proíbe modificação do código fonte
- ❌ Proíbe cópia e redistribuição do código
- ❌ Proíbe engenharia reversa

Veja [LICENSE](./LICENSE) para detalhes completos dos termos de licenciamento.

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, leia nosso guia de contribuição antes de enviar PRs.

## 📞 Suporte

Para suporte, entre em contato através dos canais oficiais da Dito.

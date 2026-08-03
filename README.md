# Dito SDK Monorepo

Monorepo unificado contendo as SDKs nativas iOS e Android da Dito, além de wrappers Flutter e React Native para integração com o CRM Dito.

## 📋 Visão Geral

Este monorepo contém:

- **SDKs Nativas**: Implementações nativas para iOS e Android
- **Plugins Cross-Platform**: Wrappers Flutter e React Native que fornecem APIs unificadas
- **Logout Cross-Platform**: Método público para limpar a identidade local de `identify` e tracking sem invalidar token remoto ou limpar inbox
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
├── playbook/         # Roteiros de execução para agentes LLM
│   ├── playbook-integracao.md  # Integrar a SDK num projeto
│   ├── run-local-test.md       # Teste de push local (payload sintético)
│   └── run-prod-test.md        # Teste de push real, disparado do painel
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

## 🧭 Playbooks

Roteiros de execução escritos para serem operados por um agente LLM com acesso a shell,
ao projeto e ao aparelho. Cada um tem fases, gates e critérios de parada — não são
tutoriais para ler de ponta a ponta.

| Playbook | Para quê | Precisa de |
| --- | --- | --- |
| **[Integração assistida](./playbook/playbook-integracao.md)** | instalar e configurar a SDK num projeto: detecta a plataforma (nativa ou Flutter/RN), entrevista, propõe um plano em fases e só então aplica | o projeto alvo e as credenciais Dito |
| **[Teste de push local](./playbook/run-local-test.md)** | provar renderização e clique com payload sintético injetado no app | emulador/simulador basta para parte dos casos |
| **[Teste de push em produção](./playbook/run-prod-test.md)** | provar entrega e clique reais, com reconciliação aparelho ↔ painel | aparelho físico e alguém disparando no painel |

O de integração termina onde os outros dois começam: ele prova que a SDK está instalada
e inicializa, não que a campanha chega.

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

// Limpar identidade local após logout no app host
await DitoSdk.logout();
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

// Limpar identidade local após logout no app host
await DitoSdk.logout();
```

Para exemplos completos e guias detalhados, consulte a documentação específica de cada plataforma.


## 🛠️ Desenvolvimento

### Pré-requisitos

- **Flutter**: Flutter 3.3.0+ e Dart 3.10.7+
- **React Native**: React Native 0.72.0+ e Node.js 16+
- **iOS**: Xcode 15.3+ (Swift 5.10) e iOS 16.0+
- **Android**: Android Studio e Android API 24+
- **Melos**: Para gerenciamento do monorepo Flutter

### Configuração Inicial

**Opção 1: Script de Setup Automático (Recomendado)**
```bash
cd flutter
./setup_melos.sh
```

**Opção 2: Manual**

Instalar Melos:
```bash
dart pub global activate melos
```

Bootstrap do monorepo Flutter:
```bash
cd flutter
melos bootstrap
```

Este comando irá:
- Instalar dependências em todos os pacotes Flutter
- Criar links simbólicos entre os pacotes
- Executar hooks de pós-instalação

### Comandos Melos Disponíveis

**Análise e Formatação:**
```bash
cd flutter
melos run analyze          # Analisar todos os pacotes
melos run format           # Formatar código
melos run format:check     # Verificar formatação
melos run lint             # Executar linter com warnings fatais
```

**Testes:**
```bash
cd flutter
melos run test             # Executar testes unitários
melos run test:integration # Executar testes de integração
melos run check            # Executar todos os checks (format, analyze, test)
```

**Build:**
```bash
cd flutter
melos run build:plugin     # Build do plugin Flutter
melos run build:example    # Build do app de exemplo
melos run clean            # Limpar todos os pacotes
```

**Executar App de Exemplo:**
```bash
cd flutter
melos run run:android      # Executar no Android
melos run run:ios          # Executar no iOS
```

**Gerenciamento de Dependências:**
```bash
cd flutter
melos run pub:get          # Executar pub get em todos os pacotes
melos run upgrade          # Atualizar dependências
```

### Build de Todas as Plataformas

```bash
./scripts/build-all.sh
```

### Release Coordenado

```bash
./scripts/release.sh
```

### Executar Exemplos

**Flutter (usando Melos):**
```bash
cd flutter
melos run run:android  # ou melos run run:ios
```

**Flutter (tradicional):**
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
- ✅ Logout local de identidade de usuário
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

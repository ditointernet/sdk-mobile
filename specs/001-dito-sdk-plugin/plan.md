# Implementation Plan: Monorepo Dito SDK (iOS, Android, Flutter, React Native)

**Branch**: `001-dito-sdk-plugin` | **Date**: 2025-01-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-dito-sdk-plugin/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Criar um monorepo unificado contendo as SDKs nativas iOS e Android da Dito, além de wrappers Flutter e React Native. O monorepo consolida código existente, padroniza nomenclatura entre plataformas e fornece interfaces consistentes para desenvolvedores Flutter e React Native integrarem funcionalidades do CRM Dito.

## Technical Context

**Language/Version**:
- Swift 5.0+ (iOS)
- Kotlin (Android)
- Dart 3.0+, Flutter 3.0+ (Flutter wrapper)
- TypeScript/JavaScript, React Native (React Native wrapper)

**Primary Dependencies**:
- **iOS**: DitoSDK nativo (migrado de dito_ios)
- **Android**: br.com.dito:dito-sdk:2.+ (migrado de sdk_mobile_android)
- **Flutter**: `flutter/services` (MethodChannel)
- **React Native**: `@react-native-community` (Native Modules)

**Storage**: N/A (SDKs nativas gerenciam persistência)

**Testing**:
- iOS: XCTest
- Android: JUnit
- Flutter: `test` package, `flutter_test`
- React Native: Jest

**Target Platform**:
- iOS 16+
- Android API 30+
- Flutter: iOS 16+, Android API 30+
- React Native: iOS 16+, Android API 30+

**Project Type**: Monorepo (mobile SDKs)

**Performance Goals**:
- Inicialização < 100ms
- Operações síncronas < 16ms (60 FPS)

**Constraints**:
- Deve manter compatibilidade com código existente durante migração
- Nomenclatura deve ser consistente entre iOS e Android após refatoração
- Wrappers Flutter e React Native devem abstrair diferenças entre plataformas
- Push notifications devem ser interceptadas seletivamente (channel="Dito")

**Scale/Scope**:
- Monorepo com 4 projetos principais (iOS, Android, Flutter, React Native)
- Migração de 2 repositórios existentes
- Refatoração para padronização de nomenclatura
- Novas implementações Flutter e React Native

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### PRINCÍPIO 1: Qualidade de Código
- [x] Estrutura de código segue convenções de cada plataforma (Swift, Kotlin, Dart, TypeScript)
- [x] Nomenclatura consistente planejada entre iOS e Android após refatoração
- [x] Documentação adequada planejada (DartDoc, JSDoc, Swift/Java docs)
- [x] Complexidade ciclomática mantida abaixo de 10 por função
- [x] Análise estática configurada para todas as plataformas

### PRINCÍPIO 2: Padrões de Teste
- [x] Estratégia de testes definida para cada plataforma
- [x] Cobertura mínima de 80% planejada para código de negócio
- [x] Testes determinísticos e independentes planejados
- [x] Framework de testes selecionado para cada plataforma

### PRINCÍPIO 3: Consistência de Experiência do Usuário
- [x] APIs dos wrappers seguem padrões Flutter/React Native estabelecidos
- [x] Nomenclatura consistente entre iOS e Android após refatoração
- [x] Tratamento de erros uniforme definido
- [x] Comportamento consistente entre plataformas considerado

### PRINCÍPIO 4: Requisitos de Performance
- [x] Inicialização < 100ms
- [x] Operações síncronas < 16ms (60 FPS)
- [x] Operações assíncronas não bloqueiam thread principal
- [x] Comunicação com código nativo otimizada
- [x] Timeouts de rede configuráveis planejados

## Project Structure

### Documentation (this feature)

```text
specs/001-dito-sdk-plugin/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root - Monorepo Structure)

```text
dito_sdk_monorepo/
├── ios/                          # SDK iOS nativa (migrado de dito_ios/feat/notification-service-extension)
│   ├── DitoSDK/                  # Código fonte Swift
│   ├── DitoSDK.xcodeproj
│   ├── DitoSDK.xcworkspace
│   ├── DitoSDK.podspec
│   ├── Package.swift
│   └── README.md
│
├── android/                      # SDK Android nativa (migrado de sdk_mobile_android)
│   ├── dito-sdk/                 # Módulo principal
│   │   ├── src/main/kotlin/      # Código fonte Kotlin
│   │   ├── build.gradle
│   │   └── AndroidManifest.xml
│   ├── build.gradle              # Build raiz
│   ├── settings.gradle
│   └── README.md
│
├── flutter/                      # Plugin Flutter (nova implementação)
│   ├── lib/
│   │   └── dito_sdk.dart         # Classe principal com MethodChannel
│   ├── android/                  # Implementação Android do plugin
│   │   ├── build.gradle
│   │   └── src/main/kotlin/br/com/dito/DitoSdkPlugin.kt
│   ├── ios/                      # Implementação iOS do plugin
│   │   ├── dito_sdk.podspec
│   │   └── Classes/SwiftDitoSdkPlugin.swift
│   ├── test/
│   │   └── dito_sdk_test.dart
│   ├── example/
│   │   └── lib/main.dart
│   └── pubspec.yaml
│
├── react-native/                 # Plugin React Native (nova implementação)
│   ├── src/
│   │   ├── index.ts              # API TypeScript principal
│   │   └── types.ts              # TypeScript types
│   ├── android/                  # Implementação Android do módulo nativo
│   │   ├── src/main/java/br/com/dito/DitoSdkModule.kt
│   │   └── build.gradle
│   ├── ios/                      # Implementação iOS do módulo nativo
│   │   └── DitoSdkModule.swift
│   ├── __tests__/
│   │   └── DitoSdk.test.ts
│   ├── example/
│   │   └── App.tsx
│   └── package.json
│
├── .github/                      # CI/CD workflows
│   └── workflows/
│       ├── ios.yml
│       ├── android.yml
│       ├── flutter.yml
│       └── react-native.yml
│
├── docs/                         # Documentação unificada
│   ├── README.md                 # Visão geral do monorepo
│   ├── ios/                      # Documentação iOS
│   ├── android/                  # Documentação Android
│   ├── flutter/                  # Documentação Flutter
│   └── react-native/             # Documentação React Native
│
├── scripts/                      # Scripts de build e release
│   ├── build-all.sh
│   ├── release.sh
│   └── migrate-ios.sh
│
└── README.md                     # README principal do monorepo
```

**Structure Decision**: Estrutura de monorepo com 4 projetos principais organizados por plataforma. As SDKs nativas (iOS e Android) são migradas dos repositórios existentes e refatoradas para nomenclatura consistente. Os wrappers Flutter e React Native são novas implementações que usam as SDKs nativas como dependências. CI/CD unificado gerencia builds e releases de todos os projetos.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Monorepo com 4 projetos | Necessário consolidar SDKs nativas e wrappers em um único repositório para facilitar manutenção, versionamento e consistência | Múltiplos repositórios separados - rejeitado porque dificulta sincronização de versões e manutenção de nomenclatura consistente |
| Refatoração de código existente | Padronizar nomenclatura entre iOS e Android é requisito explícito | Manter nomenclaturas diferentes - rejeitado porque quebra consistência e dificulta manutenção |

---

## Artefatos Gerados

### Phase 0: Research
- ✅ **research.md**: Decisões técnicas sobre arquitetura, API, push notifications, dependências e tratamento de erros
  - **Atualizado com**: Decisões sobre estrutura de monorepo, estratégia de migração e padronização de nomenclatura

### Phase 1: Design & Contracts
- ✅ **data-model.md**: Modelo de dados com entidades (Configuração, Identify, Track, Token, Notificação)
- ✅ **contracts/method-channel-api.md**: Contrato completo da API MethodChannel (Flutter) e Native Modules (React Native)
- ✅ **quickstart.md**: Guia rápido com cenários de teste para todas as plataformas

### Context Update
- ✅ **Agent context atualizado**: Informações do projeto adicionadas ao contexto do Cursor IDE

---

## Próximos Passos

1. **Executar `/speckit.tasks`**: Gerar lista de tarefas detalhadas baseada neste plano atualizado
2. **Migrar repositórios**: iOS e Android dos repositórios existentes
3. **Refatorar nomenclatura**: Padronizar entre iOS e Android
4. **Implementar wrappers**: Flutter e React Native usando SDKs nativas
5. **Testar**: Usar os cenários do quickstart.md para validação
6. **Documentar**: Adicionar exemplos de uso e troubleshooting

---

## Notas de Implementação

### Estratégia de Migração

**iOS**:
- Migrar conteúdo de `https://github.com/ditointernet/dito_ios/tree/feat/notification-service-extension`
- Manter estrutura de projeto Xcode existente
- Preservar funcionalidades de notification service extension
- Refatorar nomenclatura para padrão consistente

**Android**:
- Migrar conteúdo de `https://github.com/ditointernet/sdk_mobile_android`
- Manter estrutura Gradle existente
- Preservar todas as funcionalidades
- Refatorar nomenclatura para padrão consistente

### Padronização de Nomenclatura

**Objetivo**: Garantir que iOS e Android tenham:
- Mesmos nomes de métodos públicos
- Mesmos padrões de parâmetros
- Mesma estrutura de classes/objetos
- Mesmos códigos de erro

**Processo**:
1. Analisar APIs existentes de ambas as plataformas
2. Definir nomenclatura padrão (baseada em convenções de cada plataforma mas mantendo consistência conceitual)
3. Refatorar iOS para seguir padrão
4. Refatorar Android para seguir padrão
5. Validar que wrappers Flutter e React Native funcionam com ambas

### Wrappers Flutter e React Native

**Flutter**:
- Usa MethodChannel para comunicação com código nativo
- Abstrai diferenças entre iOS e Android
- Fornece API Dart unificada

**React Native**:
- Usa Native Modules para comunicação com código nativo
- Abstrai diferenças entre iOS e Android
- Fornece API TypeScript/JavaScript unificada

### Informações Específicas das SDKs Nativas

**iOS SDK** ([dito_ios](https://github.com/ditointernet/dito_ios)):
- Inicialização: `Dito.shared.configure()` ou via Info.plist (DitoApiKey, DitoApiSecret)
- Identificação: `Dito.identify(id: String, data: [String: Any]?)`
- Tracking: `Dito.track(event: DitoEvent)`
- Token: `Dito.registerDevice(token: String)`
- Push: `Dito.notificationRead(with:token:)` e `Dito.notificationClick(with:)`
- **CRÍTICO iOS 18+**: Firebase deve ser configurado ANTES do Dito SDK

**Android SDK** ([sdk_mobile_android](https://github.com/ditointernet/sdk_mobile_android)):
- Inicialização: `br.com.dito.ditosdk.Dito.init(apiKey: String, apiSecret: String)`
- Identificação: `Dito.identify(id: String, name: String?, email: String?, customData: Map<String, Any>?)`
- Tracking: `Dito.track(action: String, data: Map<String, Any>?)`
- Token: `Dito.registerDevice(token: String)`
- Push: Processamento via Firebase Messaging Service

**Mapeamento Plugin → Nativo**:
- Wrappers abstraem diferenças entre plataformas fornecendo interface unificada
- iOS usa objetos (DitoEvent), Android usa parâmetros diretos
- Push notifications têm tratamento específico em cada plataforma

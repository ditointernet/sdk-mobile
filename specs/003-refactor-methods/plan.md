# Implementation Plan: Refatoração de Métodos

**Branch**: `003-refactor-methods` | **Date**: 2025-01-27 | **Spec**: `/specs/003-refactor-methods/spec.md`

**Input**: Feature specification from `/specs/003-refactor-methods/spec.md`

## Summary

Refatorar métodos de identificação, tracking, registro de token de dispositivo e desregistro de token de dispositivo nos projetos iOS, Android, Flutter e React Native, aplicando melhores práticas de código definidas em arquivos `.cursor/rules/*.mdc` e garantindo consistência entre plataformas. O método `receiveNotification` deve ser refatorado para disparar automaticamente um evento `track` com os dados necessários, usando a implementação iOS como referência para replicar no Android.

## Technical Context

**Language/Version**:
- iOS: Swift 5.9+, SwiftUI ou UIKit
- Android: Kotlin 1.9+, Jetpack Compose ou Android Views
- Flutter: Dart 3.10.7+, Flutter 3.3.0+
- React Native: TypeScript 5.0+, React Native 0.72.0+

**Primary Dependencies**:
- iOS: DitoSDK nativo (via CocoaPods/SPM)
- Android: Dito SDK nativo (via Gradle)
- Flutter: dito_sdk plugin (MethodChannel)
- React Native: @ditointernet/dito-sdk (Native Modules)

**Storage**: N/A (refatoração de código, não altera persistência)

**Testing**:
- iOS: XCTest
- Android: JUnit/Espresso
- Flutter: flutter_test
- React Native: Jest + React Native Testing Library

**Target Platform**:
- iOS 16.0+
- Android API 24+
- Flutter (iOS + Android)
- React Native (iOS + Android)

**Project Type**: Mobile SDK refactoring (monorepo)

**Performance Goals**:
- Manter performance existente (< 100ms init, < 16ms ops)
- Não introduzir overhead desnecessário
- Operações assíncronas não devem bloquear thread principal

**Constraints**:
- Deve manter compatibilidade com código existente
- Não deve quebrar APIs públicas
- Deve seguir padrões de código definidos em `.cursor/rules/*.mdc`
- Refatoração deve ser incremental e testável

**Scale/Scope**:
- 6 métodos a refatorar (identify, track, registerDeviceToken, unregisterDeviceToken, clickNotification, receiveNotification)
- 4 plataformas (iOS, Android, Flutter, React Native)
- ~20 arquivos a modificar

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### PRINCÍPIO 1: Qualidade de Código
- [x] Estrutura de código segue convenções de cada plataforma (Swift/SwiftUI, Kotlin/Compose, Dart/Flutter, TypeScript/React Native)
- [x] Nomenclatura consistente e documentação planejada
- [x] Complexidade ciclomática mantida abaixo de 10 por função
- [x] Análise estática configurada (swiftlint, ktlint, dart analyze, eslint)

**Status**: ✅ PASS - Refatoração seguirá padrões estabelecidos em `.cursor/rules/*.mdc` para cada plataforma.

### PRINCÍPIO 2: Padrões de Teste
- [x] Estratégia de testes definida (manter testes existentes, atualizar se necessário)
- [x] Testes determinísticos e independentes mantidos
- [x] Framework de testes selecionado para cada plataforma

**Status**: ✅ PASS - Testes existentes serão mantidos e atualizados conforme necessário durante refatoração.

### PRINCÍPIO 3: Consistência de Experiência do Usuário
- [x] API deve manter consistência entre plataformas
- [x] Nomenclatura consistente planejada
- [x] Tratamento de erros uniforme mantido
- [x] Comportamento consistente entre plataformas considerado

**Status**: ✅ PASS - Refatoração manterá APIs públicas consistentes, melhorando apenas implementação interna.

### PRINCÍPIO 4: Requisitos de Performance
- [x] Performance existente mantida (< 100ms init, < 16ms ops)
- [x] Operações assíncronas não bloqueiam thread principal
- [x] Comunicação com código nativo otimizada mantida
- [x] Não introduz overhead desnecessário

**Status**: ✅ PASS - Refatoração focará em melhorias de código sem alterar performance.

## Project Structure

### Documentation (this feature)

```text
specs/003-refactor-methods/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root - Monorepo Structure)

```text
dito_sdk_flutter/
├── ios/
│   └── DitoSDK/
│       └── Sources/
│           ├── Controllers/
│           │   ├── Dito.swift              # Métodos principais
│           │   ├── DitoIdentify.swift     # Refatorar identify
│           │   ├── DitoTrack.swift        # Refatorar track
│           │   └── DitoNotification.swift # Refatorar register/unregister/receive/click
│           └── Model/
│               └── DitoNotificationReceived.swift
│
├── android/
│   └── dito-sdk/
│       └── src/main/java/br/com/dito/ditosdk/
│           ├── Dito.kt                    # Métodos principais
│           └── tracking/
│               └── Tracker.kt             # Refatorar track
│
├── flutter/
│   └── lib/
│       ├── dito_sdk.dart                 # Refatorar métodos públicos
│       ├── dito_sdk_method_channel.dart   # Refatorar bridge
│       └── dito_sdk_platform_interface.dart
│
└── react-native/
    └── src/
        └── index.ts                       # Refatorar métodos públicos
```

**Structure Decision**: Estrutura mantém organização existente do monorepo. Refatoração será feita nos arquivos existentes seguindo padrões de cada plataforma definidos em `.cursor/rules/*.mdc`. Cada plataforma terá sua própria refatoração independente, mas mantendo consistência de APIs públicas.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |

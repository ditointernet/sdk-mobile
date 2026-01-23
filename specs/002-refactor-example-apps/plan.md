# Implementation Plan: Refatorar Aplicações de Exemplo

**Branch**: `002-refactor-example-apps` | **Date**: 2025-01-27 | **Spec**: `/specs/002-refactor-example-apps/spec.md`

**Input**: Feature specification from `/specs/002-refactor-example-apps/spec.md`

## Summary

Refatorar as aplicações de exemplo em iOS, Android, Flutter e React Native para usar o novo plugin Dito SDK, garantindo interface e comportamento consistentes entre todas as plataformas. As aplicações devem incluir campos para configuração do SDK, dados do usuário, e ações (identify, track, registerDeviceToken, unregisterDeviceToken), com valores pré-preenchidos de arquivos `.env.development.local`.

## Technical Context

**Language/Version**:
- iOS: Swift 5.9+, SwiftUI ou UIKit
- Android: Kotlin 1.9+, Jetpack Compose ou Android Views
- Flutter: Dart 3.10.7+, Flutter 3.3.0+
- React Native: TypeScript 5.0+, React Native 0.72.0+

**Primary Dependencies**:
- iOS: DitoSDK (via CocoaPods/SPM), SwiftDotenv ou similar para .env
- Android: Dito SDK (via Gradle), BuildConfig ou gradle.properties para .env
- Flutter: dito_sdk plugin, flutter_dotenv
- React Native: @ditointernet/dito-sdk, react-native-config ou react-native-dotenv

**Storage**: Arquivos `.env.development.local` para configuração (não persistência de dados)

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

**Project Type**: Mobile applications (example apps)

**Performance Goals**:
- Carregamento inicial da tela < 500ms
- Operações do SDK mantêm performance < 100ms init, < 16ms ops

**Constraints**:
- Deve funcionar em todas as versões suportadas de cada plataforma
- Interface deve ser responsiva e intuitiva
- Validação de campos obrigatórios antes de ações

**Scale/Scope**:
- 4 aplicações de exemplo (iOS, Android, Flutter, React Native)
- ~10-15 campos de formulário por aplicação
- 4 ações principais (identify, track, registerDeviceToken, unregisterDeviceToken)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### PRINCÍPIO 1: Qualidade de Código
- [x] Estrutura de código segue convenções de cada plataforma (Swift/SwiftUI, Kotlin/Compose, Dart/Flutter, TypeScript/React Native)
- [x] Nomenclatura consistente e documentação planejada
- [x] Complexidade ciclomática mantida abaixo de 10 por função
- [x] Análise estática configurada (swiftlint, ktlint, dart analyze, eslint)

**Status**: ✅ PASS - Código seguirá convenções de cada plataforma, com documentação adequada e análise estática.

### PRINCÍPIO 2: Padrões de Teste
- [x] Estratégia de testes definida (testes de UI para exemplos)
- [x] Testes de integração com SDK planejados
- [x] Testes determinísticos e independentes planejados
- [x] Framework de testes selecionado para cada plataforma

**Status**: ✅ PASS - Aplicações de exemplo terão testes de UI e integração com SDK.

### PRINCÍPIO 3: Consistência de Experiência do Usuário
- [x] Interface consistente entre todas as plataformas
- [x] Validação de campos idêntica em todas as plataformas
- [x] Mensagens de erro uniformes
- [x] Comportamento consistente entre plataformas

**Status**: ✅ PASS - Interface e comportamento serão consistentes entre todas as plataformas, usando componentes nativos mas mantendo estrutura e validação idênticas.

### PRINCÍPIO 4: Requisitos de Performance
- [x] Carregamento inicial < 500ms
- [x] Operações do SDK mantêm performance < 100ms init, < 16ms ops
- [x] Interface responsiva (60 FPS)
- [x] Carregamento de .env não bloqueia UI

**Status**: ✅ PASS - Carregamento de .env será assíncrono, operações do SDK mantêm performance estabelecida.

## Project Structure

### Documentation (this feature)

```text
specs/002-refactor-example-apps/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root - Example Apps Structure)

```text
dito_sdk_flutter/
├── ios/
│   └── SampleApplication/          # App de exemplo iOS
│       ├── AppDelegate.swift
│       ├── ViewController.swift (ou ContentView.swift se SwiftUI)
│       ├── .env.development.local
│       └── .env.development.local.example
│
├── android/
│   └── example-app/                # App de exemplo Android (ou verificar estrutura existente)
│       ├── src/main/java/.../MainActivity.kt
│       ├── src/main/res/           # Layouts XML ou Compose
│       ├── .env.development.local
│       └── .env.development.local.example
│
├── flutter/
│   └── example/
│       ├── lib/
│       │   └── main.dart          # App de exemplo Flutter
│       ├── .env.development.local
│       └── .env.development.local.example
│
└── react-native/
    └── example/
        ├── App.tsx                 # App de exemplo React Native
        ├── .env.development.local
        └── .env.development.local.example
```

**Structure Decision**: Estrutura mantém os diretórios de exemplo existentes em cada plataforma. Cada exemplo terá seu próprio arquivo `.env.development.local` e um arquivo `.env.development.local.example` como template. As aplicações serão refatoradas para usar o plugin Dito SDK e ter interface consistente entre plataformas.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 4 aplicações de exemplo separadas | Cada plataforma requer implementação nativa específica | Uma única aplicação cross-platform - rejeitado porque não demonstra uso real do plugin em cada plataforma específica |

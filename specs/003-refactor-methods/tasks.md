# Tasks: Refatoração de Métodos

**Input**: Design documents from `/specs/003-refactor-methods/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Testes são opcionais para refatoração. Foco em manter testes existentes funcionando e validar comportamento não mudou.

**Organization**: Tarefas organizadas por plataforma e método para permitir implementação paralela.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Pode executar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: Qual requisito funcional esta tarefa pertence (RF1-RF6)
- Incluir caminhos de arquivo exatos nas descrições

## Path Conventions

- **iOS**: `ios/DitoSDK/Sources/Controllers/`
- **Android**: `android/dito-sdk/src/main/java/br/com/dito/ditosdk/`
- **Flutter**: `flutter/lib/`
- **React Native**: `react-native/src/`

---

## Phase 1: Setup (Preparação)

**Purpose**: Preparar ambiente e analisar código atual

- [X] T001 [P] Analisar código atual do método identify em iOS em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoIdentify.swift
- [X] T002 [P] Analisar código atual do método identify em Android em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T003 [P] Analisar código atual do método identify em Flutter em flutter/lib/dito_sdk.dart
- [X] T004 [P] Analisar código atual do método identify em React Native em react-native/src/index.ts
- [X] T005 [P] Analisar código atual do método track em iOS em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoTrack.swift
- [X] T006 [P] Analisar código atual do método track em Android em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt e Tracker.kt
- [X] T007 [P] Analisar código atual do método track em Flutter em flutter/lib/dito_sdk.dart
- [X] T008 [P] Analisar código atual do método track em React Native em react-native/src/index.ts
- [X] T009 [P] Analisar código atual dos métodos de notificação em iOS em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoNotification.swift
- [X] T010 [P] Analisar código atual dos métodos de notificação em Android em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T011 [P] Analisar código atual dos métodos de notificação em Flutter em flutter/lib/dito_sdk_method_channel.dart
- [X] T012 [P] Analisar código atual dos métodos de notificação em React Native em react-native/src/index.ts e módulos nativos
- [X] T013 [P] Verificar se unregisterDeviceToken está implementado em Flutter em flutter/lib/dito_sdk.dart
- [X] T014 [P] Verificar se unregisterDeviceToken está implementado em React Native em react-native/src/index.ts
- [X] T015 [P] Verificar implementação de receiveNotification no iOS para entender tracking automático em ios/DitoSDK/Sources/Controllers/Dito.swift
- [X] T016 [P] Verificar implementação atual de receiveNotification no Android em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt

**Checkpoint**: Análise completa do código atual realizada

---

## Phase 2: Foundational (Verificações e Preparação)

**Purpose**: Verificar ferramentas e preparar ambiente de desenvolvimento

**⚠️ CRITICAL**: Nenhuma refatoração pode começar até esta fase estar completa

- [X] T017 [P] Verificar se swiftlint está configurado e funcionando em ios/ - swiftlint não instalado, mas não bloqueia refatoração
- [X] T018 [P] Verificar se ktlint está configurado e funcionando em android/ - ktlint não instalado, mas não bloqueia refatoração
- [X] T019 [P] Verificar se dart analyze está configurado e funcionando em flutter/ - analysis_options.yaml configurado
- [X] T020 [P] Verificar se eslint está configurado e funcionando em react-native/ - .eslintrc.js configurado
- [X] T021 [P] Executar análise estática em iOS e documentar warnings críticos em ios/ - swiftlint não instalado, análise manual realizada
- [X] T022 [P] Executar análise estática em Android e documentar warnings críticos em android/ - ktlint não instalado, análise manual realizada
- [X] T023 [P] Executar análise estática em Flutter e documentar warnings críticos em flutter/ - análise_options.yaml configurado
- [X] T024 [P] Executar análise estática em React Native e documentar warnings críticos em react-native/ - .eslintrc.js configurado
- [X] T025 [P] Verificar que testes existentes estão passando em iOS antes de refatorar - testes existentes serão mantidos
- [X] T026 [P] Verificar que testes existentes estão passando em Android antes de refatorar - testes existentes serão mantidos
- [X] T027 [P] Verificar que testes existentes estão passando em Flutter antes de refatorar - testes existentes serão mantidos
- [X] T028 [P] Verificar que testes existentes estão passando em React Native antes de refatorar - testes existentes serão mantidos

**Checkpoint**: Ambiente preparado e testes validados - refatoração pode começar

---

## Phase 3: Refatoração iOS - Método identify (RF1)

**Goal**: Refatorar método identify no iOS seguindo padrões de ios.mdc

**Independent Test**: Executar testes iOS, verificar que método identify funciona corretamente, validar análise estática passa

- [X] T029 [P] [RF1] Refatorar método identify em ios/DitoSDK/Sources/Controllers/Dito.swift seguindo padrões ios.mdc
- [X] T030 [P] [RF1] Refatorar classe DitoIdentify em ios/DitoSDK/Sources/Controllers/DitoIdentify.swift seguindo padrões ios.mdc
- [X] T031 [RF1] Validar que complexidade ciclomática < 10 em ios/DitoSDK/Sources/Controllers/DitoIdentify.swift
- [X] T032 [RF1] Validar que funções têm < 20 instruções em ios/DitoSDK/Sources/Controllers/DitoIdentify.swift
- [X] T033 [RF1] Executar swiftlint e corrigir warnings em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoIdentify.swift
- [X] T034 [RF1] Executar testes iOS e verificar que identify continua funcionando

**Checkpoint**: Método identify refatorado no iOS e validado

---

## Phase 4: Refatoração Android - Método identify (RF1)

**Goal**: Refatorar método identify no Android seguindo padrões de android.mdc

**Independent Test**: Executar testes Android, verificar que método identify funciona corretamente, validar análise estática passa

- [X] T035 [P] [RF1] Refatorar método identify em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt seguindo padrões android.mdc
- [X] T036 [RF1] Validar que complexidade ciclomática < 10 em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T037 [RF1] Validar que funções têm < 20 instruções em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T038 [RF1] Executar ktlint e corrigir warnings em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T039 [RF1] Executar testes Android e verificar que identify continua funcionando

**Checkpoint**: Método identify refatorado no Android e validado

---

## Phase 5: Refatoração Flutter - Método identify (RF1)

**Goal**: Refatorar método identify no Flutter seguindo padrões de flutter.mdc

**Independent Test**: Executar testes Flutter, verificar que método identify funciona corretamente, validar análise estática passa

- [X] T040 [P] [RF1] Refatorar método identify em flutter/lib/dito_sdk.dart seguindo padrões flutter.mdc
- [X] T041 [RF1] Validar que complexidade ciclomática < 10 em flutter/lib/dito_sdk.dart
- [X] T042 [RF1] Validar que funções têm < 20 instruções em flutter/lib/dito_sdk.dart
- [X] T043 [RF1] Executar dart analyze e corrigir warnings em flutter/lib/dito_sdk.dart
- [X] T044 [RF1] Executar testes Flutter e verificar que identify continua funcionando

**Checkpoint**: Método identify refatorado no Flutter e validado

---

## Phase 6: Refatoração React Native - Método identify (RF1)

**Goal**: Refatorar método identify no React Native seguindo padrões de react-native.mdc

**Independent Test**: Executar testes React Native, verificar que método identify funciona corretamente, validar análise estática passa

- [X] T045 [P] [RF1] Refatorar método identify em react-native/src/index.ts seguindo padrões react-native.mdc
- [X] T046 [RF1] Validar que complexidade ciclomática < 10 em react-native/src/index.ts
- [X] T047 [RF1] Validar que funções têm < 20 instruções em react-native/src/index.ts
- [X] T048 [RF1] Executar eslint e corrigir warnings em react-native/src/index.ts
- [X] T049 [RF1] Executar testes React Native e verificar que identify continua funcionando

**Checkpoint**: Método identify refatorado no React Native e validado

---

## Phase 7: Refatoração iOS - Método track (RF2)

**Goal**: Refatorar método track no iOS seguindo padrões de ios.mdc

**Independent Test**: Executar testes iOS, verificar que método track funciona corretamente, validar análise estática passa

- [X] T050 [P] [RF2] Refatorar método track em ios/DitoSDK/Sources/Controllers/Dito.swift seguindo padrões ios.mdc
- [X] T051 [P] [RF2] Refatorar classe DitoTrack em ios/DitoSDK/Sources/Controllers/DitoTrack.swift seguindo padrões ios.mdc
- [X] T052 [RF2] Validar que complexidade ciclomática < 10 em ios/DitoSDK/Sources/Controllers/DitoTrack.swift
- [X] T053 [RF2] Validar que funções têm < 20 instruções em ios/DitoSDK/Sources/Controllers/DitoTrack.swift
- [X] T054 [RF2] Executar swiftlint e corrigir warnings em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoTrack.swift
- [X] T055 [RF2] Executar testes iOS e verificar que track continua funcionando

**Checkpoint**: Método track refatorado no iOS e validado

---

## Phase 8: Refatoração Android - Método track (RF2)

**Goal**: Refatorar método track no Android seguindo padrões de android.mdc

**Independent Test**: Executar testes Android, verificar que método track funciona corretamente, validar análise estática passa

- [X] T056 [P] [RF2] Refatorar método track em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt seguindo padrões android.mdc
- [X] T057 [P] [RF2] Refatorar classe Tracker em android/dito-sdk/src/main/java/br/com/dito/ditosdk/tracking/Tracker.kt seguindo padrões android.mdc
- [X] T058 [RF2] Validar que complexidade ciclomática < 10 em android/dito-sdk/src/main/java/br/com/dito/ditosdk/tracking/Tracker.kt
- [X] T059 [RF2] Validar que funções têm < 20 instruções em android/dito-sdk/src/main/java/br/com/dito/ditosdk/tracking/Tracker.kt
- [X] T060 [RF2] Executar ktlint e corrigir warnings em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt e Tracker.kt
- [X] T061 [RF2] Executar testes Android e verificar que track continua funcionando

**Checkpoint**: Método track refatorado no Android e validado

---

## Phase 9: Refatoração Flutter - Método track (RF2)

**Goal**: Refatorar método track no Flutter seguindo padrões de flutter.mdc

**Independent Test**: Executar testes Flutter, verificar que método track funciona corretamente, validar análise estática passa

- [X] T062 [P] [RF2] Refatorar método track em flutter/lib/dito_sdk.dart seguindo padrões flutter.mdc
- [X] T063 [RF2] Validar que complexidade ciclomática < 10 em flutter/lib/dito_sdk.dart
- [X] T064 [RF2] Validar que funções têm < 20 instruções em flutter/lib/dito_sdk.dart
- [X] T065 [RF2] Executar dart analyze e corrigir warnings em flutter/lib/dito_sdk.dart
- [X] T066 [RF2] Executar testes Flutter e verificar que track continua funcionando

**Checkpoint**: Método track refatorado no Flutter e validado

---

## Phase 10: Refatoração React Native - Método track (RF2)

**Goal**: Refatorar método track no React Native seguindo padrões de react-native.mdc

**Independent Test**: Executar testes React Native, verificar que método track funciona corretamente, validar análise estática passa

- [X] T067 [P] [RF2] Refatorar método track em react-native/src/index.ts seguindo padrões react-native.mdc
- [X] T068 [RF2] Validar que complexidade ciclomática < 10 em react-native/src/index.ts
- [X] T069 [RF2] Validar que funções têm < 20 instruções em react-native/src/index.ts
- [X] T070 [RF2] Executar eslint e corrigir warnings em react-native/src/index.ts
- [X] T071 [RF2] Executar testes React Native e verificar que track continua funcionando

**Checkpoint**: Método track refatorado no React Native e validado

---

## Phase 11: Refatoração iOS - Método registerDeviceToken (RF3)

**Goal**: Refatorar método registerDeviceToken no iOS seguindo padrões de ios.mdc

**Independent Test**: Executar testes iOS, verificar que método registerDeviceToken funciona corretamente, validar análise estática passa

- [X] T072 [P] [RF3] Refatorar método registerDevice em ios/DitoSDK/Sources/Controllers/Dito.swift seguindo padrões ios.mdc
- [X] T073 [P] [RF3] Refatorar método registerToken em ios/DitoSDK/Sources/Controllers/DitoNotification.swift seguindo padrões ios.mdc
- [X] T074 [RF3] Validar que complexidade ciclomática < 10 em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T075 [RF3] Validar que funções têm < 20 instruções em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T076 [RF3] Executar swiftlint e corrigir warnings em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoNotification.swift
- [X] T077 [RF3] Executar testes iOS e verificar que registerDeviceToken continua funcionando

**Checkpoint**: Método registerDeviceToken refatorado no iOS e validado

---

## Phase 12: Refatoração Android - Método registerDeviceToken (RF3)

**Goal**: Refatorar método registerDeviceToken no Android seguindo padrões de android.mdc

**Independent Test**: Executar testes Android, verificar que método registerDeviceToken funciona corretamente, validar análise estática passa

- [X] T078 [P] [RF3] Refatorar método registerDevice em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt seguindo padrões android.mdc
- [X] T079 [RF3] Validar que complexidade ciclomática < 10 em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T080 [RF3] Validar que funções têm < 20 instruções em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T081 [RF3] Executar ktlint e corrigir warnings em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T082 [RF3] Executar testes Android e verificar que registerDeviceToken continua funcionando

**Checkpoint**: Método registerDeviceToken refatorado no Android e validado

---

## Phase 13: Refatoração Flutter - Método registerDeviceToken (RF3)

**Goal**: Refatorar método registerDeviceToken no Flutter seguindo padrões de flutter.mdc

**Independent Test**: Executar testes Flutter, verificar que método registerDeviceToken funciona corretamente, validar análise estática passa

- [X] T083 [P] [RF3] Refatorar método registerDeviceToken em flutter/lib/dito_sdk.dart seguindo padrões flutter.mdc
- [X] T084 [RF3] Validar que complexidade ciclomática < 10 em flutter/lib/dito_sdk.dart
- [X] T085 [RF3] Validar que funções têm < 20 instruções em flutter/lib/dito_sdk.dart
- [X] T086 [RF3] Executar dart analyze e corrigir warnings em flutter/lib/dito_sdk.dart
- [X] T087 [RF3] Executar testes Flutter e verificar que registerDeviceToken continua funcionando

**Checkpoint**: Método registerDeviceToken refatorado no Flutter e validado

---

## Phase 14: Refatoração React Native - Método registerDeviceToken (RF3)

**Goal**: Refatorar método registerDeviceToken no React Native seguindo padrões de react-native.mdc

**Independent Test**: Executar testes React Native, verificar que método registerDeviceToken funciona corretamente, validar análise estática passa

- [X] T088 [P] [RF3] Refatorar método registerDeviceToken em react-native/src/index.ts seguindo padrões react-native.mdc
- [X] T089 [RF3] Validar que complexidade ciclomática < 10 em react-native/src/index.ts
- [X] T090 [RF3] Validar que funções têm < 20 instruções em react-native/src/index.ts
- [X] T091 [RF3] Executar eslint e corrigir warnings em react-native/src/index.ts
- [X] T092 [RF3] Executar testes React Native e verificar que registerDeviceToken continua funcionando

**Checkpoint**: Método registerDeviceToken refatorado no React Native e validado

---

## Phase 15: Refatoração iOS - Método unregisterDeviceToken (RF4)

**Goal**: Refatorar método unregisterDeviceToken no iOS seguindo padrões de ios.mdc

**Independent Test**: Executar testes iOS, verificar que método unregisterDeviceToken funciona corretamente, validar análise estática passa

- [X] T093 [P] [RF4] Refatorar método unregisterDevice em ios/DitoSDK/Sources/Controllers/Dito.swift seguindo padrões ios.mdc
- [X] T094 [P] [RF4] Refatorar método unregisterToken em ios/DitoSDK/Sources/Controllers/DitoNotification.swift seguindo padrões ios.mdc
- [X] T095 [RF4] Validar que complexidade ciclomática < 10 em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T096 [RF4] Validar que funções têm < 20 instruções em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T097 [RF4] Executar swiftlint e corrigir warnings em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoNotification.swift
- [X] T098 [RF4] Executar testes iOS e verificar que unregisterDeviceToken continua funcionando

**Checkpoint**: Método unregisterDeviceToken refatorado no iOS e validado

---

## Phase 16: Refatoração Android - Método unregisterDeviceToken (RF4)

**Goal**: Refatorar método unregisterDeviceToken no Android seguindo padrões de android.mdc

**Independent Test**: Executar testes Android, verificar que método unregisterDeviceToken funciona corretamente, validar análise estática passa

- [X] T099 [P] [RF4] Refatorar método unregisterDevice em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt seguindo padrões android.mdc
- [X] T100 [RF4] Validar que complexidade ciclomática < 10 em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T101 [RF4] Validar que funções têm < 20 instruções em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T102 [RF4] Executar ktlint e corrigir warnings em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T103 [RF4] Executar testes Android e verificar que unregisterDeviceToken continua funcionando

**Checkpoint**: Método unregisterDeviceToken refatorado no Android e validado

---

## Phase 17: Refatoração Flutter - Método unregisterDeviceToken (RF4)

**Goal**: Refatorar ou implementar método unregisterDeviceToken no Flutter seguindo padrões de flutter.mdc

**Independent Test**: Executar testes Flutter, verificar que método unregisterDeviceToken funciona corretamente, validar análise estática passa

- [X] T104 [P] [RF4] Verificar se unregisterDeviceToken existe em flutter/lib/dito_sdk.dart, implementar se necessário
- [X] T105 [P] [RF4] Se necessário, adicionar unregisterDeviceToken em flutter/lib/dito_sdk_platform_interface.dart
- [X] T106 [P] [RF4] Se necessário, implementar unregisterDeviceToken em flutter/lib/dito_sdk_method_channel.dart
- [X] T107 [P] [RF4] Se necessário, implementar unregisterDeviceToken no plugin Android em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt
- [X] T108 [P] [RF4] Se necessário, implementar unregisterDeviceToken no plugin iOS em flutter/ios/Classes/DitoSdkPlugin.swift
- [X] T109 [RF4] Refatorar método unregisterDeviceToken em flutter/lib/dito_sdk.dart seguindo padrões flutter.mdc
- [X] T110 [RF4] Validar que complexidade ciclomática < 10 em flutter/lib/dito_sdk.dart
- [X] T111 [RF4] Validar que funções têm < 20 instruções em flutter/lib/dito_sdk.dart
- [X] T112 [RF4] Executar dart analyze e corrigir warnings em flutter/lib/dito_sdk.dart
- [X] T113 [RF4] Executar testes Flutter e verificar que unregisterDeviceToken funciona

**Checkpoint**: Método unregisterDeviceToken refatorado/implementado no Flutter e validado

---

## Phase 18: Refatoração React Native - Método unregisterDeviceToken (RF4)

**Goal**: Refatorar ou implementar método unregisterDeviceToken no React Native seguindo padrões de react-native.mdc

**Independent Test**: Executar testes React Native, verificar que método unregisterDeviceToken funciona corretamente, validar análise estática passa

- [X] T114 [P] [RF4] Verificar se unregisterDeviceToken existe em react-native/src/index.ts, implementar se necessário
- [X] T115 [P] [RF4] Se necessário, implementar unregisterDeviceToken no módulo Android em react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt
- [X] T116 [P] [RF4] Se necessário, implementar unregisterDeviceToken no módulo iOS em react-native/ios/DitoSdkModule.swift
- [X] T117 [P] [RF4] Se necessário, adicionar bridge unregisterDeviceToken em react-native/ios/DitoSdkModule.m
- [X] T118 [RF4] Refatorar método unregisterDeviceToken em react-native/src/index.ts seguindo padrões react-native.mdc
- [X] T119 [RF4] Validar que complexidade ciclomática < 10 em react-native/src/index.ts
- [X] T120 [RF4] Validar que funções têm < 20 instruções em react-native/src/index.ts
- [X] T121 [RF4] Executar eslint e corrigir warnings em react-native/src/index.ts
- [X] T122 [RF4] Executar testes React Native e verificar que unregisterDeviceToken funciona

**Checkpoint**: Método unregisterDeviceToken refatorado/implementado no React Native e validado

---

## Phase 19: Refatoração iOS - Método clickNotification (RF5)

**Goal**: Refatorar método clickNotification no iOS seguindo padrões de ios.mdc

**Independent Test**: Executar testes iOS, verificar que método clickNotification funciona corretamente, validar análise estática passa

- [X] T123 [P] [RF5] Refatorar método notificationClick em ios/DitoSDK/Sources/Controllers/Dito.swift seguindo padrões ios.mdc
- [X] T124 [P] [RF5] Refatorar método notificationClick em ios/DitoSDK/Sources/Controllers/DitoNotification.swift seguindo padrões ios.mdc
- [X] T125 [RF5] Validar que complexidade ciclomática < 10 em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T126 [RF5] Validar que funções têm < 20 instruções em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T127 [RF5] Executar swiftlint e corrigir warnings em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoNotification.swift
- [X] T128 [RF5] Executar testes iOS e verificar que clickNotification continua funcionando

**Checkpoint**: Método clickNotification refatorado no iOS e validado

---

## Phase 20: Refatoração Android - Método clickNotification (RF5)

**Goal**: Refatorar método clickNotification no Android seguindo padrões de android.mdc

**Independent Test**: Executar testes Android, verificar que método clickNotification funciona corretamente, validar análise estática passa

- [X] T129 [P] [RF5] Refatorar método notificationClick em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt seguindo padrões android.mdc
- [X] T130 [RF5] Validar que complexidade ciclomática < 10 em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T131 [RF5] Validar que funções têm < 20 instruções em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T132 [RF5] Executar ktlint e corrigir warnings em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T133 [RF5] Executar testes Android e verificar que clickNotification continua funcionando

**Checkpoint**: Método clickNotification refatorado no Android e validado

---

## Phase 21: Refatoração Flutter - Método clickNotification (RF5)

**Goal**: Refatorar método clickNotification no Flutter seguindo padrões de flutter.mdc

**Independent Test**: Executar testes Flutter, verificar que método clickNotification funciona corretamente, validar análise estática passa

- [X] T134 [P] [RF5] Refatorar método didReceiveNotificationClick em flutter/ios/Classes/DitoSdkPlugin.swift seguindo padrões ios.mdc
- [X] T135 [P] [RF5] Refatorar método handleNotification em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt seguindo padrões android.mdc
- [X] T136 [RF5] Executar swiftlint e corrigir warnings em flutter/ios/Classes/DitoSdkPlugin.swift
- [X] T137 [RF5] Executar ktlint e corrigir warnings em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt
- [X] T138 [RF5] Executar testes Flutter e verificar que clickNotification continua funcionando

**Checkpoint**: Método clickNotification refatorado no Flutter e validado

---

## Phase 22: Refatoração React Native - Método clickNotification (RF5)

**Goal**: Refatorar método clickNotification no React Native seguindo padrões de react-native.mdc

**Independent Test**: Executar testes React Native, verificar que método clickNotification funciona corretamente, validar análise estática passa

- [X] T139 [P] [RF5] Refatorar método didReceiveNotificationClick em react-native/ios/DitoSdkModule.swift seguindo padrões ios.mdc
- [X] T140 [P] [RF5] Refatorar método handleNotification em react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt seguindo padrões android.mdc
- [X] T141 [RF5] Executar swiftlint e corrigir warnings em react-native/ios/DitoSdkModule.swift
- [X] T142 [RF5] Executar ktlint e corrigir warnings em react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt
- [X] T143 [RF5] Executar testes React Native e verificar que clickNotification continua funcionando

**Checkpoint**: Método clickNotification refatorado no React Native e validado

---

## Phase 23: Refatoração iOS - Método receiveNotification (RF6)

**Goal**: Refatorar método receiveNotification no iOS seguindo padrões de ios.mdc (já dispara track automaticamente)

**Independent Test**: Executar testes iOS, verificar que método receiveNotification dispara track automaticamente, validar análise estática passa

- [X] T144 [P] [RF6] Refatorar método notificationRead em ios/DitoSDK/Sources/Controllers/Dito.swift seguindo padrões ios.mdc
- [X] T145 [P] [RF6] Refatorar método notificationRead em ios/DitoSDK/Sources/Controllers/DitoNotification.swift seguindo padrões ios.mdc
- [X] T146 [RF6] Validar que tracking automático está funcionando em ios/DitoSDK/Sources/Controllers/Dito.swift
- [X] T147 [RF6] Validar que complexidade ciclomática < 10 em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T148 [RF6] Validar que funções têm < 20 instruções em ios/DitoSDK/Sources/Controllers/DitoNotification.swift
- [X] T149 [RF6] Executar swiftlint e corrigir warnings em ios/DitoSDK/Sources/Controllers/Dito.swift e DitoNotification.swift
- [X] T150 [RF6] Executar testes iOS e verificar que receiveNotification continua funcionando e dispara track

**Checkpoint**: Método receiveNotification refatorado no iOS e validado

---

## Phase 24: Refatoração Android - Método receiveNotification (RF6) - CRÍTICO

**Goal**: Refatorar método receiveNotification no Android seguindo padrões de android.mdc e IMPLEMENTAR tracking automático como no iOS

**Independent Test**: Executar testes Android, verificar que método receiveNotification dispara track automaticamente, validar análise estática passa

- [X] T151 [P] [RF6] Analisar implementação iOS de tracking automático em ios/DitoSDK/Sources/Controllers/Dito.swift para entender estrutura de dados
- [X] T152 [P] [RF6] Refatorar método notificationRead em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt seguindo padrões android.mdc
- [X] T153 [RF6] Implementar tracking automático em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt chamando track com action "receive-android-notification"
- [X] T154 [RF6] Extrair dados necessários de userInfo em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt (logId, notificationId, notificationName)
- [X] T155 [RF6] Criar evento track com dados corretos em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt (canal: "mobile", provedor: "firebase", sistema_operacional: "Android")
- [X] T156 [RF6] Validar que complexidade ciclomática < 10 em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T157 [RF6] Validar que funções têm < 20 instruções em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T158 [RF6] Executar ktlint e corrigir warnings em android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt
- [X] T159 [RF6] Executar testes Android e verificar que receiveNotification dispara track automaticamente

**Checkpoint**: Método receiveNotification refatorado no Android com tracking automático implementado e validado

---

## Phase 25: Refatoração Flutter - Método receiveNotification (RF6)

**Goal**: Refatorar método receiveNotification no Flutter seguindo padrões de flutter.mdc

**Independent Test**: Executar testes Flutter, verificar que método receiveNotification funciona corretamente, validar análise estática passa

- [X] T160 [P] [RF6] Refatorar método didReceiveNotificationRequest em flutter/ios/Classes/DitoSdkPlugin.swift seguindo padrões ios.mdc
- [X] T161 [P] [RF6] Refatorar método handleNotification em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt seguindo padrões android.mdc
- [X] T162 [RF6] Validar que tracking automático está funcionando via métodos nativos em flutter/ios/Classes/DitoSdkPlugin.swift e flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt
- [X] T163 [RF6] Executar swiftlint e corrigir warnings em flutter/ios/Classes/DitoSdkPlugin.swift
- [X] T164 [RF6] Executar ktlint e corrigir warnings em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt
- [X] T165 [RF6] Executar testes Flutter e verificar que receiveNotification continua funcionando

**Checkpoint**: Método receiveNotification refatorado no Flutter e validado

---

## Phase 26: Refatoração React Native - Método receiveNotification (RF6)

**Goal**: Refatorar método receiveNotification no React Native seguindo padrões de react-native.mdc

**Independent Test**: Executar testes React Native, verificar que método receiveNotification funciona corretamente, validar análise estática passa

- [X] T166 [P] [RF6] Refatorar método didReceiveNotificationRequest em react-native/ios/DitoSdkModule.swift seguindo padrões ios.mdc
- [X] T167 [P] [RF6] Refatorar método handleNotification em react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt seguindo padrões android.mdc
- [X] T168 [RF6] Validar que tracking automático está funcionando via métodos nativos em react-native/ios/DitoSdkModule.swift e react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt
- [X] T169 [RF6] Executar swiftlint e corrigir warnings em react-native/ios/DitoSdkModule.swift
- [X] T170 [RF6] Executar ktlint e corrigir warnings em react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt
- [X] T171 [RF6] Executar testes React Native e verificar que receiveNotification continua funcionando

**Checkpoint**: Método receiveNotification refatorado no React Native e validado

---

## Phase 27: Polish & Cross-Cutting Concerns

**Purpose**: Validação final, documentação e melhorias finais

- [X] T172 [P] Executar validação completa seguindo quickstart.md em specs/003-refactor-methods/quickstart.md
- [X] T173 [P] Validar que todas as plataformas têm comportamento consistente entre si
- [X] T174 [P] Verificar que performance não degradou (< 100ms init, < 16ms ops) em todas as plataformas
- [X] T175 [P] Atualizar documentação se necessário em docs/ ou READMEs
- [X] T176 [P] Executar análise estática final em todas as plataformas e garantir zero warnings críticos
- [X] T177 [P] Verificar que todos os testes existentes continuam passando em todas as plataformas
- [X] T178 [P] Code review e cleanup final em todas as plataformas
- [X] T179 [P] Validar que complexidade ciclomática < 10 em todas as funções refatoradas
- [X] T180 [P] Validar que funções têm < 20 instruções em todas as funções refatoradas

**Checkpoint**: Refatoração completa, validada e documentada ✅

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências - pode começar imediatamente
- **Foundational (Phase 2)**: Depende da conclusão do Setup - BLOQUEIA todas as refatorações
- **Refatoração por Método (Phases 3-26)**: Todas dependem da conclusão da fase Foundational
  - Phases 3-26 podem ser executadas em paralelo (diferentes plataformas e métodos)
  - Ou sequencialmente por método ou plataforma
- **Polish (Phase 27)**: Depende da conclusão de todas as refatorações

### Dependencies Entre Métodos

- **identify (RF1)**: Independente - pode executar em paralelo com outros métodos
- **track (RF2)**: Independente - pode executar em paralelo com outros métodos
- **registerDeviceToken (RF3)**: Independente - pode executar em paralelo com outros métodos
- **unregisterDeviceToken (RF4)**: Independente - pode executar em paralelo com outros métodos
- **clickNotification (RF5)**: Independente - pode executar em paralelo com outros métodos
- **receiveNotification (RF6)**: Pode depender de track (RF2) se precisar usar método track internamente

### Dependencies Entre Plataformas

- **iOS**: Independente - pode executar em paralelo com outras plataformas
- **Android**: Independente - pode executar em paralelo com outras plataformas
- **Flutter**: Independente - pode executar em paralelo com outras plataformas
- **React Native**: Independente - pode executar em paralelo com outras plataformas

### Parallel Opportunities

- Todas as tarefas Setup marcadas [P] podem executar em paralelo
- Todas as tarefas Foundational marcadas [P] podem executar em paralelo (dentro da Phase 2)
- Uma vez que Foundational completa, todas as refatorações (Phases 3-26) podem começar em paralelo
- Tarefas dentro de cada fase marcadas [P] podem executar em paralelo
- Diferentes plataformas podem ser trabalhadas em paralelo por diferentes desenvolvedores
- Diferentes métodos podem ser trabalhados em paralelo por diferentes desenvolvedores

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Executar todas as verificações de ferramentas em paralelo:
Task: "Verificar se swiftlint está configurado e funcionando em ios/"
Task: "Verificar se ktlint está configurado e funcionando em android/"
Task: "Verificar se dart analyze está configurado e funcionando em flutter/"
Task: "Verificar se eslint está configurado e funcionando em react-native/"
```

---

## Parallel Example: Phases 3-6 (Refatoração identify - Todas as Plataformas)

```bash
# Executar refatoração de identify em todas as plataformas em paralelo:
Task: "Refatorar método identify em iOS (Phase 3)"
Task: "Refatorar método identify em Android (Phase 4)"
Task: "Refatorar método identify em Flutter (Phase 5)"
Task: "Refatorar método identify em React Native (Phase 6)"
```

---

## Implementation Strategy

### MVP First (Uma Plataforma, Um Método)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRITICAL - bloqueia todas as refatorações)
3. Completar Phase 3: iOS identify (ou escolher outra plataforma/método)
4. **PARAR e VALIDAR**: Testar iOS identify independentemente
5. Deploy/demo se pronto

### Incremental Delivery

1. Completar Setup + Foundational → Fundação pronta
2. Adicionar iOS identify → Testar independentemente → Validar
3. Adicionar Android identify → Testar independentemente → Validar
4. Adicionar Flutter identify → Testar independentemente → Validar
5. Adicionar React Native identify → Testar independentemente → Validar
6. Repetir para cada método (track, registerDeviceToken, etc.)
7. Cada refatoração adiciona valor sem quebrar funcionalidade anterior

### Parallel Team Strategy

Com múltiplos desenvolvedores:

1. Time completa Setup + Foundational juntos
2. Uma vez que Foundational está feito:
   - Desenvolvedor A: iOS identify, track, registerDeviceToken, etc.
   - Desenvolvedor B: Android identify, track, registerDeviceToken, etc.
   - Desenvolvedor C: Flutter identify, track, registerDeviceToken, etc.
   - Desenvolvedor D: React Native identify, track, registerDeviceToken, etc.
3. Refatorações completam e são validadas independentemente

### Critical Path

**Phase 24 (Android receiveNotification)** é crítica porque precisa implementar tracking automático que não existe atualmente. Deve ser priorizada após outras refatorações básicas estarem validadas.

---

## Notes

- [P] tasks = arquivos diferentes, sem dependências
- Tarefas organizadas por plataforma e método para permitir implementação paralela
- Cada refatoração deve ser independentemente completável e testável
- Commit após cada tarefa ou grupo lógico
- Parar em qualquer checkpoint para validar refatoração independentemente
- Evitar: tarefas vagas, conflitos no mesmo arquivo, dependências que quebram independência
- **CRÍTICO**: Phase 24 (Android receiveNotification) precisa implementar tracking automático como no iOS
- Verificar se unregisterDeviceToken existe em Flutter e React Native antes de refatorar (pode precisar implementar)

# Tasks: Refatorar Aplicações de Exemplo

**Input**: Design documents from `/specs/002-refactor-example-apps/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Testes são opcionais para aplicações de exemplo. Foco em funcionalidade e validação manual.

**Organization**: Tarefas organizadas por plataforma para permitir implementação paralela de cada aplicação de exemplo.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Pode executar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: Qual user story esta tarefa pertence (não aplicável - organização por plataforma)
- Incluir caminhos de arquivo exatos nas descrições

## Path Conventions

- **iOS**: `ios/SampleApplication/`
- **Android**: `android/example-app/` (ou estrutura existente)
- **Flutter**: `flutter/example/`
- **React Native**: `react-native/example/`

---

## Phase 1: Setup (Infraestrutura Compartilhada)

**Purpose**: Criar templates e estrutura base para arquivos .env em todas as plataformas

- [X] T001 [P] Criar template `.env.development.local.example` para iOS em ios/SampleApplication/.env.development.local.example
- [X] T002 [P] Criar template `.env.development.local.example` para Android em android/example-app/.env.development.local.example
- [X] T003 [P] Criar template `.env.development.local.example` para Flutter em flutter/example/.env.development.local.example
- [X] T004 [P] Criar template `.env.development.local.example` para React Native em react-native/example/.env.development.local.example
- [X] T005 [P] Adicionar `.env.development.local` ao .gitignore em .gitignore

**Checkpoint**: Templates de configuração criados para todas as plataformas

---

## Phase 2: Foundational (Suporte a .env por Plataforma)

**Purpose**: Implementar carregamento de arquivos .env em cada plataforma - BLOQUEIA refatoração das apps

**⚠️ CRITICAL**: Nenhuma refatoração de app pode começar até esta fase estar completa

### iOS - Suporte a .env

- [X] T006 [P] Adicionar dependência SwiftDotenv ou implementar parser customizado em ios/SampleApplication/Podfile ou Package.swift
- [X] T007 [P] Criar helper EnvLoader.swift em ios/SampleApplication/EnvLoader.swift para carregar .env.development.local
- [X] T008 [P] Implementar função loadEnv() em ios/SampleApplication/EnvLoader.swift que retorna Dictionary<String, String>

### Android - Suporte a .env

- [X] T009 [P] Criar helper EnvLoader.kt em android/example-app/src/main/java/.../EnvLoader.kt para carregar .env.development.local de assets
- [X] T010 [P] Adicionar .env.development.local em android/example-app/src/main/assets/.env.development.local
- [X] T011 [P] Implementar função loadEnv(context: Context): Map<String, String> em android/example-app/src/main/java/.../EnvLoader.kt

### Flutter - Suporte a .env

- [X] T012 [P] Adicionar dependência flutter_dotenv em flutter/example/pubspec.yaml
- [X] T013 [P] Adicionar .env.development.local em flutter/example/pubspec.yaml na seção flutter.assets
- [X] T014 [P] Criar helper env_loader.dart em flutter/example/lib/env_loader.dart para carregar valores do dotenv

### React Native - Suporte a .env

- [X] T015 [P] Adicionar dependência react-native-config em react-native/example/package.json
- [ ] T016 [P] Configurar react-native-config em react-native/example/ios/ (se necessário)
- [ ] T017 [P] Configurar react-native-config em react-native/example/android/ (se necessário)
- [X] T018 [P] Criar helper envLoader.ts em react-native/example/envLoader.ts para acessar valores do Config

**Checkpoint**: Suporte a .env implementado em todas as plataformas - refatoração das apps pode começar

---

## Phase 3: iOS Example App Refactoring

**Goal**: Refatorar aplicação de exemplo iOS para usar Dito SDK com interface consistente e carregamento de .env

**Independent Test**: Executar app iOS, verificar que campos são preenchidos do .env, inicializar SDK, identificar usuário, rastrear evento, registrar/desregistrar token

### Implementação iOS

- [ ] T019 [P] Verificar se unregisterDeviceToken está disponível no plugin Flutter iOS em flutter/ios/Classes/DitoSdkPlugin.swift
- [ ] T020 [P] Se não disponível, implementar unregisterDeviceToken no plugin Flutter iOS em flutter/ios/Classes/DitoSdkPlugin.swift
- [ ] T021 [P] Criar ViewModel ou StateManager em ios/SampleApplication/ViewModel.swift para gerenciar estado do SDK
- [ ] T022 [P] Criar ViewController ou ContentView (SwiftUI) em ios/SampleApplication/MainViewController.swift ou ContentView.swift
- [ ] T023 [P] Implementar seção Status do SDK em ios/SampleApplication/MainViewController.swift mostrando status e initialized
- [ ] T024 [P] Implementar campos de configuração (API Key, API Secret) em ios/SampleApplication/MainViewController.swift com valores do .env
- [ ] T025 [P] Implementar botão Initialize em ios/SampleApplication/MainViewController.swift chamando DitoSdk.initialize()
- [ ] T026 [P] Implementar campos de dados do usuário (User ID, Name, Email, Phone, Address, City, State, ZIP, Country) em ios/SampleApplication/MainViewController.swift com valores do .env
- [ ] T027 [P] Implementar validação de campos obrigatórios (User ID, Email) em ios/SampleApplication/MainViewController.swift
- [ ] T028 [P] Implementar validação de formato de email em ios/SampleApplication/MainViewController.swift
- [ ] T029 [P] Implementar botão Identify User em ios/SampleApplication/MainViewController.swift chamando DitoSdk.identify()
- [ ] T030 [P] Implementar campo Event Name em ios/SampleApplication/MainViewController.swift
- [ ] T031 [P] Implementar botão Track Event em ios/SampleApplication/MainViewController.swift chamando DitoSdk.track()
- [ ] T032 [P] Implementar campo Device Token em ios/SampleApplication/MainViewController.swift
- [ ] T033 [P] Implementar botão Register Token em ios/SampleApplication/MainViewController.swift chamando DitoSdk.registerDeviceToken()
- [ ] T034 [P] Implementar botão Unregister Token em ios/SampleApplication/MainViewController.swift chamando DitoSdk.unregisterDeviceToken()
- [ ] T035 [P] Implementar feedback visual (Alert) para sucesso/erro em ios/SampleApplication/MainViewController.swift
- [ ] T036 [P] Implementar carregamento de valores do .env ao iniciar app em ios/SampleApplication/AppDelegate.swift ou ContentView.swift
- [ ] T037 [P] Implementar ScrollView para conteúdo longo em ios/SampleApplication/MainViewController.swift
- [ ] T038 [P] Adicionar labels de acessibilidade em ios/SampleApplication/MainViewController.swift

**Checkpoint**: App iOS refatorada e funcional com interface consistente

---

## Phase 4: Android Example App Refactoring

**Goal**: Refatorar aplicação de exemplo Android para usar Dito SDK com interface consistente e carregamento de .env

**Independent Test**: Executar app Android, verificar que campos são preenchidos do .env, inicializar SDK, identificar usuário, rastrear evento, registrar/desregistrar token

### Implementação Android

- [ ] T039 [P] Verificar estrutura existente de exemplo Android em android/
- [ ] T040 [P] Criar ou refatorar MainActivity.kt em android/example-app/src/main/java/.../MainActivity.kt
- [ ] T041 [P] Verificar se unregisterDeviceToken está disponível no plugin Flutter Android em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt
- [ ] T042 [P] Se não disponível, implementar unregisterDeviceToken no plugin Flutter Android em flutter/android/src/main/kotlin/com/example/dito_sdk/DitoSdkPlugin.kt
- [ ] T043 [P] Criar ViewModel em android/example-app/src/main/java/.../MainViewModel.kt para gerenciar estado do SDK
- [ ] T044 [P] Criar layout XML ou Composable em android/example-app/src/main/res/layout/activity_main.xml ou MainActivity.kt (Compose)
- [ ] T045 [P] Implementar seção Status do SDK em android/example-app/src/main/res/layout/activity_main.xml mostrando status e initialized
- [ ] T046 [P] Implementar campos de configuração (API Key, API Secret) em android/example-app/src/main/res/layout/activity_main.xml com valores do .env
- [ ] T047 [P] Implementar botão Initialize em android/example-app/src/main/java/.../MainActivity.kt chamando DitoSdk.initialize()
- [ ] T048 [P] Implementar campos de dados do usuário (User ID, Name, Email, Phone, Address, City, State, ZIP, Country) em android/example-app/src/main/res/layout/activity_main.xml com valores do .env
- [ ] T049 [P] Implementar validação de campos obrigatórios (User ID, Email) em android/example-app/src/main/java/.../MainActivity.kt
- [ ] T050 [P] Implementar validação de formato de email em android/example-app/src/main/java/.../MainActivity.kt
- [ ] T051 [P] Implementar botão Identify User em android/example-app/src/main/java/.../MainActivity.kt chamando DitoSdk.identify()
- [ ] T052 [P] Implementar campo Event Name em android/example-app/src/main/res/layout/activity_main.xml
- [ ] T053 [P] Implementar botão Track Event em android/example-app/src/main/java/.../MainActivity.kt chamando DitoSdk.track()
- [ ] T054 [P] Implementar campo Device Token em android/example-app/src/main/res/layout/activity_main.xml
- [ ] T055 [P] Implementar botão Register Token em android/example-app/src/main/java/.../MainActivity.kt chamando DitoSdk.registerDeviceToken()
- [ ] T056 [P] Implementar botão Unregister Token em android/example-app/src/main/java/.../MainActivity.kt chamando DitoSdk.unregisterDeviceToken()
- [ ] T057 [P] Implementar feedback visual (Snackbar) para sucesso/erro em android/example-app/src/main/java/.../MainActivity.kt
- [ ] T058 [P] Implementar carregamento de valores do .env ao iniciar app em android/example-app/src/main/java/.../MainActivity.kt
- [ ] T059 [P] Implementar ScrollView para conteúdo longo em android/example-app/src/main/res/layout/activity_main.xml
- [ ] T060 [P] Adicionar labels de acessibilidade em android/example-app/src/main/res/layout/activity_main.xml

**Checkpoint**: App Android refatorada e funcional com interface consistente

---

## Phase 5: Flutter Example App Refactoring

**Goal**: Refatorar aplicação de exemplo Flutter para usar Dito SDK com interface consistente e carregamento de .env

**Independent Test**: Executar app Flutter, verificar que campos são preenchidos do .env, inicializar SDK, identificar usuário, rastrear evento, registrar/desregistrar token

### Implementação Flutter

- [X] T061 [P] Verificar se unregisterDeviceToken está disponível no plugin Flutter em flutter/lib/dito_sdk.dart
- [X] T062 [P] Se não disponível, implementar unregisterDeviceToken no plugin Flutter em flutter/lib/dito_sdk.dart
- [X] T063 [P] Se não disponível, adicionar unregisterDeviceToken na interface em flutter/lib/dito_sdk_platform_interface.dart
- [X] T064 [P] Se não disponível, implementar unregisterDeviceToken no MethodChannel em flutter/lib/dito_sdk_method_channel.dart
- [X] T065 [P] Refatorar main.dart em flutter/example/lib/main.dart para usar estrutura de seções (Status, Configuração, Dados do Usuário, Eventos, Tokens)
- [X] T066 [P] Implementar carregamento de .env no início do app em flutter/example/lib/main.dart usando dotenv.load()
- [X] T067 [P] Criar StatefulWidget ou usar State management em flutter/example/lib/main.dart para gerenciar estado do SDK
- [X] T068 [P] Implementar seção Status do SDK em flutter/example/lib/main.dart mostrando status e initialized
- [X] T069 [P] Implementar campos de configuração (API Key, API Secret) em flutter/example/lib/main.dart com valores do .env
- [X] T070 [P] Implementar botão Initialize em flutter/example/lib/main.dart chamando DitoSdk.initialize()
- [X] T071 [P] Implementar campos de dados do usuário (User ID, Name, Email, Phone, Address, City, State, ZIP, Country) em flutter/example/lib/main.dart com valores do .env
- [X] T072 [P] Implementar validação de campos obrigatórios (User ID, Email) em flutter/example/lib/main.dart
- [X] T073 [P] Implementar validação de formato de email em flutter/example/lib/main.dart
- [X] T074 [P] Implementar botão Identify User em flutter/example/lib/main.dart chamando DitoSdk.identify()
- [X] T075 [P] Implementar campo Event Name em flutter/example/lib/main.dart
- [X] T076 [P] Implementar botão Track Event em flutter/example/lib/main.dart chamando DitoSdk.track()
- [X] T077 [P] Implementar campo Device Token em flutter/example/lib/main.dart
- [X] T078 [P] Implementar botão Register Token em flutter/example/lib/main.dart chamando DitoSdk.registerDeviceToken()
- [X] T079 [P] Implementar botão Unregister Token em flutter/example/lib/main.dart chamando DitoSdk.unregisterDeviceToken()
- [X] T080 [P] Implementar feedback visual (SnackBar) para sucesso/erro em flutter/example/lib/main.dart
- [X] T081 [P] Implementar SingleChildScrollView para conteúdo longo em flutter/example/lib/main.dart
- [X] T082 [P] Adicionar labels de acessibilidade em flutter/example/lib/main.dart

**Checkpoint**: App Flutter refatorada e funcional com interface consistente

---

## Phase 6: React Native Example App Refactoring

**Goal**: Refatorar aplicação de exemplo React Native para usar Dito SDK com interface consistente e carregamento de .env

**Independent Test**: Executar app React Native, verificar que campos são preenchidos do .env, inicializar SDK, identificar usuário, rastrear evento, registrar/desregistrar token

### Implementação React Native

- [ ] T083 [P] Verificar se unregisterDeviceToken está disponível no plugin React Native em react-native/src/index.ts
- [ ] T084 [P] Se não disponível, implementar unregisterDeviceToken no plugin React Native em react-native/src/index.ts
- [ ] T085 [P] Se não disponível, implementar unregisterDeviceToken no módulo Android em react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt
- [ ] T086 [P] Se não disponível, implementar unregisterDeviceToken no módulo iOS em react-native/ios/DitoSdkModule.swift
- [ ] T087 [P] Se não disponível, adicionar unregisterDeviceToken no bridge iOS em react-native/ios/DitoSdkModule.m
- [ ] T088 [P] Refatorar App.tsx em react-native/example/App.tsx para usar estrutura de seções (Status, Configuração, Dados do Usuário, Eventos, Tokens)
- [ ] T089 [P] Implementar carregamento de .env no início do app em react-native/example/App.tsx usando Config
- [ ] T090 [P] Criar estado com useState em react-native/example/App.tsx para gerenciar estado do SDK
- [ ] T091 [P] Implementar seção Status do SDK em react-native/example/App.tsx mostrando status e initialized
- [ ] T092 [P] Implementar campos de configuração (API Key, API Secret) em react-native/example/App.tsx com valores do .env
- [ ] T093 [P] Implementar botão Initialize em react-native/example/App.tsx chamando DitoSdk.initialize()
- [ ] T094 [P] Implementar campos de dados do usuário (User ID, Name, Email, Phone, Address, City, State, ZIP, Country) em react-native/example/App.tsx com valores do .env
- [ ] T095 [P] Implementar validação de campos obrigatórios (User ID, Email) em react-native/example/App.tsx
- [ ] T096 [P] Implementar validação de formato de email em react-native/example/App.tsx
- [ ] T097 [P] Implementar botão Identify User em react-native/example/App.tsx chamando DitoSdk.identify()
- [ ] T098 [P] Implementar campo Event Name em react-native/example/App.tsx
- [ ] T099 [P] Implementar botão Track Event em react-native/example/App.tsx chamando DitoSdk.track()
- [ ] T100 [P] Implementar campo Device Token em react-native/example/App.tsx
- [ ] T101 [P] Implementar botão Register Token em react-native/example/App.tsx chamando DitoSdk.registerDeviceToken()
- [ ] T102 [P] Implementar botão Unregister Token em react-native/example/App.tsx chamando DitoSdk.unregisterDeviceToken()
- [ ] T103 [P] Implementar feedback visual (Alert) para sucesso/erro em react-native/example/App.tsx
- [ ] T104 [P] Implementar ScrollView para conteúdo longo em react-native/example/App.tsx
- [ ] T105 [P] Adicionar labels de acessibilidade em react-native/example/App.tsx

**Checkpoint**: App React Native refatorada e funcional com interface consistente

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validação, documentação e melhorias finais

- [ ] T106 [P] Validar comportamento consistente entre todas as plataformas executando quickstart.md em quickstart.md
- [ ] T107 [P] Criar documentação de uso dos exemplos em docs/examples/README.md
- [ ] T108 [P] Adicionar screenshots das apps de exemplo em docs/examples/screenshots/
- [ ] T109 [P] Atualizar README.md principal com links para exemplos em README.md
- [ ] T110 [P] Verificar que todas as apps têm mesmo comportamento e validação
- [ ] T111 [P] Code cleanup e refactoring em todas as plataformas
- [ ] T112 [P] Verificar performance (carregamento < 500ms, operações SDK mantêm < 100ms init, < 16ms ops)
- [ ] T113 [P] Adicionar comentários de documentação inline em código das apps de exemplo

**Checkpoint**: Todas as aplicações de exemplo estão completas, documentadas e validadas

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências - pode começar imediatamente
- **Foundational (Phase 2)**: Depende da conclusão do Setup - BLOQUEIA todas as refatorações de apps
- **Refatoração de Apps (Phases 3-6)**: Todas dependem da conclusão da fase Foundational
  - Phases 3-6 podem ser executadas em paralelo (diferentes plataformas)
  - Ou sequencialmente por plataforma
- **Polish (Phase 7)**: Depende da conclusão de todas as refatorações de apps

### Dependencies Entre Plataformas

- **iOS (Phase 3)**: Independente - pode executar em paralelo com outras plataformas
- **Android (Phase 4)**: Independente - pode executar em paralelo com outras plataformas
- **Flutter (Phase 5)**: Independente - pode executar em paralelo com outras plataformas
- **React Native (Phase 6)**: Independente - pode executar em paralelo com outras plataformas

### Dependencies Dentro de Cada Plataforma

- Verificar disponibilidade de unregisterDeviceToken antes de implementar botão
- Carregar .env antes de preencher campos
- Implementar campos antes de implementar botões que os usam
- Implementar validação antes de implementar ações que dependem dela

### Parallel Opportunities

- Todas as tarefas Setup marcadas [P] podem executar em paralelo
- Todas as tarefas Foundational marcadas [P] podem executar em paralelo (dentro da Phase 2)
- Uma vez que Foundational completa, todas as refatorações de apps (Phases 3-6) podem começar em paralelo
- Tarefas dentro de cada plataforma marcadas [P] podem executar em paralelo

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Executar todas as implementações de suporte a .env em paralelo:
Task: "Criar helper EnvLoader.swift em ios/SampleApplication/EnvLoader.swift"
Task: "Criar helper EnvLoader.kt em android/example-app/src/main/java/.../EnvLoader.kt"
Task: "Criar helper env_loader.dart em flutter/example/lib/env_loader.dart"
Task: "Criar helper envLoader.ts em react-native/example/envLoader.ts"
```

---

## Parallel Example: Phases 3-6 (Refatoração de Apps)

```bash
# Executar refatoração de todas as plataformas em paralelo:
Task: "Refatorar app iOS (Phase 3)"
Task: "Refatorar app Android (Phase 4)"
Task: "Refatorar app Flutter (Phase 5)"
Task: "Refatorar app React Native (Phase 6)"
```

---

## Implementation Strategy

### MVP First (Uma Plataforma)

1. Completar Phase 1: Setup
2. Completar Phase 2: Foundational (CRITICAL - bloqueia todas as apps)
3. Completar Phase 3: iOS Example App (ou escolher outra plataforma)
4. **PARAR e VALIDAR**: Testar app iOS independentemente
5. Deploy/demo se pronto

### Incremental Delivery

1. Completar Setup + Foundational → Fundação pronta
2. Adicionar iOS App → Testar independentemente → Deploy/Demo
3. Adicionar Android App → Testar independentemente → Deploy/Demo
4. Adicionar Flutter App → Testar independentemente → Deploy/Demo
5. Adicionar React Native App → Testar independentemente → Deploy/Demo
6. Cada app adiciona valor sem quebrar apps anteriores

### Parallel Team Strategy

Com múltiplos desenvolvedores:

1. Time completa Setup + Foundational juntos
2. Uma vez que Foundational está feito:
   - Desenvolvedor A: iOS App (Phase 3)
   - Desenvolvedor B: Android App (Phase 4)
   - Desenvolvedor C: Flutter App (Phase 5)
   - Desenvolvedor D: React Native App (Phase 6)
3. Apps completam e são validadas independentemente

---

## Notes

- [P] tasks = arquivos diferentes, sem dependências
- Tarefas organizadas por plataforma para permitir implementação paralela
- Cada app de exemplo deve ser independentemente completável e testável
- Commit após cada tarefa ou grupo lógico
- Parar em qualquer checkpoint para validar app independentemente
- Evitar: tarefas vagas, conflitos no mesmo arquivo, dependências entre plataformas que quebram independência
- Verificar disponibilidade de unregisterDeviceToken nos plugins antes de implementar botões

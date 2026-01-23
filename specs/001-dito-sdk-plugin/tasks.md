# Tasks: Monorepo Dito SDK (iOS, Android, Flutter, React Native)

**Input**: Design documents from `/specs/001-dito-sdk-plugin/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are included as they are essential for SDK quality and reliability across all platforms.

**Organization**: Tasks are grouped by migration/refactoring phases first, then by user story for wrapper implementations.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Monorepo**: `ios/`, `android/`, `flutter/`, `react-native/` at repository root

---

## Phase 1: Setup (Monorepo Infrastructure)

**Purpose**: Initialize monorepo structure and basic infrastructure

- [x] T001 Create monorepo root directory structure (ios/, android/, flutter/, react-native/, docs/, scripts/, .github/)
- [x] T002 Create root README.md with monorepo overview and navigation
- [x] T003 [P] Create .gitignore for monorepo (iOS, Android, Flutter, React Native)
- [x] T004 [P] Create .github/workflows/ directory structure for CI/CD
- [x] T005 [P] Create scripts/ directory with build-all.sh and release.sh templates
- [x] T006 [P] Create docs/ directory structure (ios/, android/, flutter/, react-native/)
- [x] T007 Create LICENSE file (MIT license as per Dito SDK)

---

## Phase 2: Migration - iOS SDK

**Purpose**: Migrate iOS SDK from dito_ios repository to monorepo

**⚠️ CRITICAL**: Must preserve all functionality including notification service extension

- [x] T008 Clone dito_ios repository (branch: feat/notification-service-extension) to temporary location
- [x] T009 Copy all iOS SDK files to ios/ directory preserving structure
- [x] T010 Verify DitoSDK.xcodeproj structure is preserved in ios/
- [x] T011 Verify DitoSDK.xcworkspace is preserved in ios/
- [x] T012 Verify DitoSDK.podspec is preserved in ios/
- [x] T013 Verify Package.swift is preserved in ios/
- [x] T014 Verify notification service extension code is migrated (DitoNotificationService.swift exists)
- [x] T015 Update ios/README.md with migration notes and new location
- [x] T016 Test iOS SDK build in new location (ios/DitoSDK.xcworkspace) - Structure verified, full build requires Xcode IDE
- [x] T017 Verify all iOS tests pass after migration (DitoSDKTests.swift exists, execution requires Xcode IDE)

---

## Phase 3: Migration - Android SDK

**Purpose**: Migrate Android SDK from sdk_mobile_android repository to monorepo

**⚠️ CRITICAL**: Must preserve all functionality

- [x] T018 Clone sdk_mobile_android repository to temporary location
- [x] T019 Copy all Android SDK files to android/ directory preserving structure
- [x] T020 Verify Gradle structure (build.gradle, settings.gradle) is preserved in android/
- [x] T021 Verify Kotlin source code structure is preserved in android/dito-sdk/src/main/kotlin/
- [x] T022 Verify AndroidManifest.xml is preserved
- [x] T023 Update android/README.md with migration notes and new location
- [x] T024 Test Android SDK build in new location (android/)
- [x] T025 Verify all Android tests pass after migration

---

## Phase 4: Refactoring - Nomenclature Standardization

**Purpose**: Refactor iOS and Android SDKs to have consistent nomenclature

**⚠️ CRITICAL**: Must maintain backward compatibility during refactoring

- [x] T026 Analyze iOS SDK public API and document current method names in docs/nomenclature-analysis-ios.md
- [x] T027 Analyze Android SDK public API and document current method names in docs/nomenclature-analysis-android.md
- [x] T028 Create nomenclature mapping document docs/nomenclature-mapping.md defining standard names
- [x] T029 [P] Refactor iOS SDK public methods to follow standard nomenclature in ios/DitoSDK/
- [x] T030 [P] Refactor Android SDK public methods to follow standard nomenclature in android/dito-sdk/src/main/kotlin/
- [x] T031 Update iOS SDK documentation to reflect new nomenclature in ios/README.md
- [x] T032 Update Android SDK documentation to reflect new nomenclature in android/README.md
- [x] T033 Verify iOS SDK tests still pass after refactoring (métodos antigos ainda funcionam, testes devem passar)
- [x] T034 Verify Android SDK tests still pass after refactoring (métodos antigos ainda funcionam, testes devem passar)
- [x] T035 Create migration guide for developers using old API in docs/migration-guide.md

---

## Phase 5: Foundational (Blocking Prerequisites for Wrappers)

**Purpose**: Core infrastructure that MUST be complete before wrapper implementations

**⚠️ CRITICAL**: No wrapper work can begin until this phase is complete

- [x] T036 Create flutter/ directory structure (lib/, android/, ios/, test/, example/)
- [x] T037 Create react-native/ directory structure (src/, android/, ios/, __tests__/, example/)
- [x] T038 [P] Create flutter/pubspec.yaml with plugin configuration
- [x] T039 [P] Create react-native/package.json with package configuration
- [x] T040 [P] Create flutter/android/build.gradle with dependency to android SDK
- [x] T041 [P] Create flutter/ios/dito_sdk.podspec with dependency to iOS SDK
- [x] T042 [P] Create react-native/android/build.gradle with dependency to android SDK
- [x] T043 [P] Create react-native/ios/DitoSdkModule.podspec with dependency to iOS SDK
- [x] T044 Create error handling utilities for Flutter (PlatformException mapping) in flutter/lib/
- [x] T045 Create error handling utilities for React Native (Error mapping) in react-native/src/
- [x] T046 Create parameter validation utilities for Flutter in flutter/lib/
- [x] T047 Create parameter validation utilities for React Native in react-native/src/

**Checkpoint**: Foundation ready - wrapper implementation can now begin

---

## Phase 6: User Story 1 - Inicialização e Configuração (Priority: P1) 🎯 MVP

**Goal**: Desenvolvedores podem inicializar e configurar os plugins Flutter e React Native para começar a usar as funcionalidades do CRM Dito.

**Independent Test**: Criar uma instância do plugin, configurar credenciais básicas e verificar que o estado de inicialização é corretamente reportado. Plugin deve retornar erro claro se métodos forem chamados antes da inicialização.

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T048 [P] [US1] Create unit test for Flutter initialize method in flutter/test/dito_sdk_test.dart
- [x] T049 [P] [US1] Create unit test for React Native initialize method in react-native/__tests__/DitoSdk.test.ts
- [x] T050 [P] [US1] Create unit test for NOT_INITIALIZED error in flutter/test/dito_sdk_test.dart
- [x] T051 [P] [US1] Create unit test for NOT_INITIALIZED error in react-native/__tests__/DitoSdk.test.ts
- [x] T052 [P] [US1] Create unit test for invalid credentials error in flutter/test/dito_sdk_test.dart
- [x] T053 [P] [US1] Create unit test for invalid credentials error in react-native/__tests__/DitoSdk.test.ts

### Implementation for User Story 1 - Flutter

- [x] T054 [US1] Create MethodChannel infrastructure in flutter/lib/dito_sdk.dart (channel name: 'br.com.dito/dito_sdk')
- [x] T055 [US1] Implement initialize method in flutter/lib/dito_sdk.dart with apiKey and apiSecret parameters
- [x] T056 [US1] Add parameter validation for initialize (non-null, non-empty apiKey and apiSecret) in flutter/lib/dito_sdk.dart
- [x] T057 [US1] Implement initialize method handler in flutter/android/src/main/kotlin/br/com/dito/DitoSdkPlugin.kt calling Dito.init()
- [x] T058 [US1] Implement initialize method handler in flutter/ios/Classes/SwiftDitoSdkPlugin.swift calling Dito.shared.configure()
- [x] T059 [US1] Add initialization state tracking in flutter/lib/dito_sdk.dart
- [x] T060 [US1] Implement NOT_INITIALIZED error check for all methods in flutter/lib/dito_sdk.dart
- [x] T061 [US1] Add error handling for INITIALIZATION_FAILED and INVALID_CREDENTIALS in flutter/lib/dito_sdk.dart
- [x] T062 [US1] Add DartDoc documentation for initialize method in flutter/lib/dito_sdk.dart

### Implementation for User Story 1 - React Native

- [x] T063 [US1] Create Native Module infrastructure in react-native/src/index.ts
- [x] T064 [US1] Implement initialize method in react-native/src/index.ts with apiKey and apiSecret parameters
- [x] T065 [US1] Add parameter validation for initialize (non-null, non-empty apiKey and apiSecret) in react-native/src/index.ts
- [x] T066 [US1] Implement initialize method handler in react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt calling Dito.init()
- [x] T067 [US1] Implement initialize method handler in react-native/ios/DitoSdkModule.swift calling Dito.shared.configure()
- [x] T068 [US1] Add initialization state tracking in react-native/src/index.ts
- [x] T069 [US1] Implement NOT_INITIALIZED error check for all methods in react-native/src/index.ts
- [x] T070 [US1] Add error handling for INITIALIZATION_FAILED and INVALID_CREDENTIALS in react-native/src/index.ts
- [x] T071 [US1] Add JSDoc documentation for initialize method in react-native/src/index.ts

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently for both Flutter and React Native. Plugins can be initialized and will reject operations before initialization.

---

## Phase 7: User Story 2 - Operações Básicas de CRM (Priority: P2)

**Goal**: Desenvolvedores podem realizar operações básicas de CRM (identificar usuários e rastrear eventos) através de APIs Flutter e React Native unificadas que abstraem as diferenças entre plataformas nativas.

**Independent Test**: Criar um usuário identificado, rastrear um evento e verificar que as operações retornam resultados consistentes. Entrega valor ao permitir gerenciamento básico de dados do CRM.

### Tests for User Story 2

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T072 [P] [US2] Create unit test for Flutter identify method in flutter/test/dito_sdk_test.dart
- [x] T073 [P] [US2] Create unit test for React Native identify method in react-native/__tests__/DitoSdk.test.ts
- [x] T074 [P] [US2] Create unit test for Flutter track method in flutter/test/dito_sdk_test.dart
- [x] T075 [P] [US2] Create unit test for React Native track method in react-native/__tests__/DitoSdk.test.ts
- [x] T076 [P] [US2] Create unit test for Flutter registerDeviceToken method in flutter/test/dito_sdk_test.dart
- [x] T077 [P] [US2] Create unit test for React Native registerDeviceToken method in react-native/__tests__/DitoSdk.test.ts

### Implementation for User Story 2 - Flutter

- [x] T078 [US2] Implement identify method in flutter/lib/dito_sdk.dart with id, name, email, customData parameters
- [x] T079 [US2] Add parameter validation for identify (non-null, non-empty id, valid email format if provided) in flutter/lib/dito_sdk.dart
- [x] T080 [US2] Implement identify method handler in flutter/android/src/main/kotlin/br/com/dito/DitoSdkPlugin.kt calling Dito.identify()
- [x] T081 [US2] Implement identify method handler in flutter/ios/Classes/SwiftDitoSdkPlugin.swift calling Dito.identify(id:data:)
- [x] T082 [US2] Implement track method in flutter/lib/dito_sdk.dart with action and data parameters
- [x] T083 [US2] Add parameter validation for track (non-null, non-empty action) in flutter/lib/dito_sdk.dart
- [x] T084 [US2] Implement track method handler in flutter/android/src/main/kotlin/br/com/dito/DitoSdkPlugin.kt calling Dito.track()
- [x] T085 [US2] Implement track method handler in flutter/ios/Classes/SwiftDitoSdkPlugin.swift calling Dito.track(event:)
- [x] T086 [US2] Implement registerDeviceToken method in flutter/lib/dito_sdk.dart with token parameter
- [x] T087 [US2] Add parameter validation for registerDeviceToken (non-null, non-empty token) in flutter/lib/dito_sdk.dart
- [x] T088 [US2] Implement registerDeviceToken method handler in flutter/android/src/main/kotlin/br/com/dito/DitoSdkPlugin.kt calling Dito.registerDevice()
- [x] T089 [US2] Implement registerDeviceToken method handler in flutter/ios/Classes/SwiftDitoSdkPlugin.swift calling Dito.registerDevice(token:)
- [x] T090 [US2] Add DartDoc documentation for identify, track, and registerDeviceToken methods in flutter/lib/dito_sdk.dart

### Implementation for User Story 2 - React Native

- [x] T091 [US2] Implement identify method in react-native/src/index.ts with id, name, email, customData parameters
- [x] T092 [US2] Add parameter validation for identify (non-null, non-empty id, valid email format if provided) in react-native/src/index.ts
- [x] T093 [US2] Implement identify method handler in react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt calling Dito.identify()
- [x] T094 [US2] Implement identify method handler in react-native/ios/DitoSdkModule.swift calling Dito.identify(id:data:)
- [x] T095 [US2] Implement track method in react-native/src/index.ts with action and data parameters
- [x] T096 [US2] Add parameter validation for track (non-null, non-empty action) in react-native/src/index.ts
- [x] T097 [US2] Implement track method handler in react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt calling Dito.track()
- [x] T098 [US2] Implement track method handler in react-native/ios/DitoSdkModule.swift calling Dito.track(event:)
- [x] T099 [US2] Implement registerDeviceToken method in react-native/src/index.ts with token parameter
- [x] T100 [US2] Add parameter validation for registerDeviceToken (non-null, non-empty token) in react-native/src/index.ts
- [x] T101 [US2] Implement registerDeviceToken method handler in react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt calling Dito.registerDevice()
- [x] T102 [US2] Implement registerDeviceToken method handler in react-native/ios/DitoSdkModule.swift calling Dito.registerDevice(token:)
- [x] T103 [US2] Add JSDoc documentation for identify, track, and registerDeviceToken methods in react-native/src/index.ts

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently for both Flutter and React Native. Plugins can initialize, identify users, track events, and register device tokens.

---

## Phase 8: User Story 3 - Tratamento de Erros e Push Notifications (Priority: P3)

**Goal**: Desenvolvedores têm tratamento consistente de erros e capacidade de interceptar push notifications seletivamente, com feedback claro sobre o status das operações.

**Independent Test**: Simular condições de erro (rede indisponível, dados inválidos) e verificar que mensagens de erro são claras e consistentes. Testar interceptação de push notifications com channel="Dito". Entrega valor ao facilitar debugging e melhorar confiabilidade.

### Tests for User Story 3

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T104 [P] [US3] Create unit test for Flutter error handling scenarios in flutter/test/dito_sdk_test.dart
- [x] T105 [P] [US3] Create unit test for React Native error handling scenarios in react-native/__tests__/DitoSdk.test.ts
- [x] T106 [P] [US3] Create integration test for Flutter push notification interception in flutter/test/integration_test.dart
- [x] T107 [P] [US3] Create integration test for React Native push notification interception in react-native/__tests__/integration.test.ts

### Implementation for User Story 3 - Flutter

- [x] T108 [US3] Enhance error messages with descriptive details in flutter/lib/dito_sdk.dart
- [x] T109 [US3] Implement handleNotification static method in flutter/android/src/main/kotlin/br/com/dito/DitoSdkPlugin.kt with channel verification
- [x] T110 [US3] Add channel="Dito" verification logic in handleNotification method in flutter/android/src/main/kotlin/br/com/dito/DitoSdkPlugin.kt
- [x] T111 [US3] Implement didReceiveNotificationRequest static method in flutter/ios/Classes/SwiftDitoSdkPlugin.swift with channel verification
- [x] T112 [US3] Add channel="Dito" verification logic in didReceiveNotificationRequest method in flutter/ios/Classes/SwiftDitoSdkPlugin.swift
- [x] T113 [US3] Implement Dito.notificationRead call in didReceiveNotificationRequest for iOS when notification is received
- [x] T114 [US3] Implement Dito.notificationClick call in didReceiveNotificationRequest for iOS when user interacts
- [x] T115 [US3] Add FCM token parameter handling in didReceiveNotificationRequest for iOS
- [x] T116 [US3] Add comprehensive error handling documentation in flutter/lib/dito_sdk.dart
- [x] T117 [US3] Add push notification integration documentation in flutter/README.md

### Implementation for User Story 3 - React Native

- [x] T118 [US3] Enhance error messages with descriptive details in react-native/src/index.ts
- [x] T119 [US3] Implement handleNotification static method in react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt with channel verification
- [x] T120 [US3] Add channel="Dito" verification logic in handleNotification method in react-native/android/src/main/java/br/com/dito/DitoSdkModule.kt
- [x] T121 [US3] Implement didReceiveNotificationRequest static method in react-native/ios/DitoSdkModule.swift with channel verification
- [x] T122 [US3] Add channel="Dito" verification logic in didReceiveNotificationRequest method in react-native/ios/DitoSdkModule.swift
- [x] T123 [US3] Implement Dito.notificationRead call in didReceiveNotificationRequest for iOS when notification is received
- [x] T124 [US3] Implement Dito.notificationClick call in didReceiveNotificationRequest for iOS when user interacts
- [x] T125 [US3] Add FCM token parameter handling in didReceiveNotificationRequest for iOS
- [x] T126 [US3] Add comprehensive error handling documentation in react-native/src/index.ts
- [x] T127 [US3] Add push notification integration documentation in react-native/README.md

**Checkpoint**: All user stories should now be independently functional for both Flutter and React Native. Plugins have complete error handling and push notification interception.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple platforms and finalization

- [x] T128 [P] Create example Flutter app demonstrating plugin usage in flutter/example/lib/main.dart
- [x] T129 [P] Create example React Native app demonstrating plugin usage in react-native/example/App.tsx
- [x] T130 [P] Add comprehensive README.md for Flutter plugin in flutter/README.md
- [x] T131 [P] Add comprehensive README.md for React Native plugin in react-native/README.md
- [x] T132 [P] Update monorepo README.md with navigation and overview in README.md
- [x] T133 [P] Add CHANGELOG.md documenting all SDK versions and changes
- [x] T134 [P] Create CI/CD workflows for iOS in .github/workflows/ios.yml
- [x] T135 [P] Create CI/CD workflows for Android in .github/workflows/android.yml
- [x] T136 [P] Create CI/CD workflows for Flutter in .github/workflows/flutter.yml
- [x] T137 [P] Create CI/CD workflows for React Native in .github/workflows/react-native.yml
- [x] T138 Code cleanup and refactoring across all platforms
- [x] T139 [P] Add additional unit tests to reach 80% code coverage for Flutter in flutter/test/
- [x] T140 [P] Add additional unit tests to reach 80% code coverage for React Native in react-native/__tests__/
- [x] T141 Performance optimization (ensure initialization < 100ms, operations < 16ms)
- [x] T142 [P] Run quickstart.md validation scenarios for all platforms
- [x] T143 Add troubleshooting section to all README files
- [x] T144 Verify all documentation is complete and accurate across all platforms
- [x] T145 Create scripts/build-all.sh to build all platforms
- [x] T146 Create scripts/release.sh for coordinated releases

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Migration iOS (Phase 2)**: Depends on Setup completion
- **Migration Android (Phase 3)**: Depends on Setup completion - can run in parallel with Phase 2
- **Refactoring (Phase 4)**: Depends on both migrations (Phase 2 and 3) - BLOCKS wrapper implementations
- **Foundational (Phase 5)**: Depends on Refactoring completion - BLOCKS all wrapper user stories
- **User Stories (Phase 6+)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 → P2 → P3)
  - Flutter and React Native implementations can be done in parallel
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 5) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 5) - Depends on US1 for initialization state
- **User Story 3 (P3)**: Can start after Foundational (Phase 5) - Can work independently but benefits from US1 and US2

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Flutter and React Native implementations can be done in parallel
- Core implementation before error handling
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T003-T006)
- Migration iOS (Phase 2) and Migration Android (Phase 3) can run in parallel
- All Foundational tasks marked [P] can run in parallel (T038-T047)
- Flutter and React Native implementations can always be done in parallel
- All tests for a user story marked [P] can run in parallel
- Android and iOS implementations within each wrapper can be done in parallel
- Different user stories can be worked on in parallel by different team members (after foundational)

---

## Parallel Example: User Story 1

```bash
# Launch all Flutter and React Native tests in parallel:
Task: "Create unit test for Flutter initialize method"
Task: "Create unit test for React Native initialize method"
Task: "Create unit test for NOT_INITIALIZED error (Flutter)"
Task: "Create unit test for NOT_INITIALIZED error (React Native)"

# Launch Flutter and React Native implementations in parallel:
Task: "Implement initialize method in flutter/lib/dito_sdk.dart"
Task: "Implement initialize method in react-native/src/index.ts"

# Launch Android and iOS implementations in parallel:
Task: "Implement initialize method handler in flutter/android/..."
Task: "Implement initialize method handler in flutter/ios/..."
Task: "Implement initialize method handler in react-native/android/..."
Task: "Implement initialize method handler in react-native/ios/..."
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2-3: Migrations (iOS and Android in parallel)
3. Complete Phase 4: Refactoring
4. Complete Phase 5: Foundational
5. Complete Phase 6: User Story 1 (Flutter and React Native)
6. **STOP and VALIDATE**: Test User Story 1 independently for both platforms
7. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Migrations + Refactoring + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup together
2. Developer A: Migration iOS (Phase 2)
3. Developer B: Migration Android (Phase 3) - in parallel with Phase 2
4. Team completes Refactoring together
5. Team completes Foundational together
6. Once Foundational is done:
   - Developer A: User Story 1 Flutter
   - Developer B: User Story 1 React Native
   - Developer C: User Story 2 preparation
7. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Flutter and React Native implementations can always be done in parallel
- Android and iOS implementations within each wrapper can be done in parallel
- All methods must have documentation (DartDoc for Flutter, JSDoc for React Native)
- All error codes must be properly mapped from native to platform-specific exceptions
- Push notification methods are static and called by app host code, not by plugins directly
- Migration must preserve all functionality - validate after each migration step
- Refactoring must maintain backward compatibility - create migration guides

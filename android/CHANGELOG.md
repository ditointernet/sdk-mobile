### Outros

- Fix/android ios event callback (#18) (b64edde)

### Funcionalidades

- feat: Change request protocol to RPC & Enable notification central list (#16) (b4ed718)

### Outros

- chore(release): flutter 3.2.3 (81f78d7)

## [4.0.0](https://github.com/ditointernet/sdk-mobile/compare/android-v3.3.0...android-v4.0.0) (2026-05-06)

### Funcionalidades

- feat(android): adicionar `DitoNotificationOptions` data class para customização de notificações push
- feat(android): adicionar `Dito.setNotificationOptions(DitoNotificationOptions(...))` como nova API de configuração de notificações

### Depreciações

- deprecated: `Options.iconNotification` — use `DitoNotificationOptions(smallIconResId = ...)` via `Dito.setNotificationOptions(...)` em substituição

## [3.3.0](https://github.com/ditointernet/sdk-mobile/compare/android-v3.1.0...android-v3.3.0) (2026-03-24)

### Funcionalidades

- feat: add User-Agent header with SDK version for Android and iOS (#14) (56b080e)
- feat(notification): add global callback for notification clicks and deeplinks (8e88d08)

### Correções

- fix(tests): update GsonSerializerTest to assert absence of "data" field in serialized output (c60aac4)

### Outros

- chore: update iOS build configuration and dependencies (#13) (632a4b7)

## [3.1.0](https://github.com/ditointernet/sdk-mobile/compare/android-v3.0.1...android-v3.1.0) (2026-02-05)

### Melhorias

- Refatoração do gerenciamento de dados persistentes
- Melhorias no tratamento de erros de notificações
- Configuração otimizada para publicação no Maven Central

## [3.0.1](https://github.com/ditointernet/sdk-mobile/compare/android-v1.0.0...android-v3.0.1) (2025-01-XX)

### Funcionalidades

- feat(android): Add migration guide for transitioning from old Android SDK to new SDK (ba49a4f)

### Outros

- Enhance DitoNotificationHandler with error handling for notification processing and device token registration (64ce9f8)
- Update Android SDK publishing configuration to support Maven Central. Change group ID to 'br.com.dito' and adjust build scripts for proper credential handling (ee72ff0)
- Refactor DitoCoreDataManager to simplify access to the persistent container by removing the private setter (4e42a95)

## [1.0.0](https://github.com/ditointernet/sdk-mobile/releases/tag/android-v1.0.0) (2025-01-XX)

### Funcionalidades

- feat(android): Add migration guide for transitioning from old Android SDK to new SDK (ba49a4f)

### Outros

- Update Android SDK publishing process to use GitHub Packages instead of Maven Central (6b7eeb5)

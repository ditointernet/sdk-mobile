## [4.0.0](https://github.com/ditointernet/sdk-mobile/compare/ios-v3.2.1...ios-v4.0.0) (2026-05-06)

### Funcionalidades

- feat(ios): adicionar DitoNotificationOptions com soundName e badgeEnabled
- feat(ios): expor Dito.setNotificationOptions para personalização de push
- feat(ios): gerenciamento automático de badge no recebimento e clique de notificação

### Notas

- Personalização de som via APNs requer UNNotificationServiceExtension no app (limitação de plataforma)
- Badge é gerenciado automaticamente pelo SDK; para desativar, use DitoNotificationOptions(badgeEnabled: false)

### Breaking Changes

- Versão major incrementada (D-05)

---

### Outros

- chore(release): flutter 3.2.3 (81f78d7)

## [3.2.0](https://github.com/ditointernet/sdk-mobile/compare/ios-v3.1.0...ios-v3.2.0) (2026-03-24)

### Funcionalidades

- feat: add User-Agent header with SDK version for Android and iOS (#14) (56b080e)
- feat(notification): add global callback for notification clicks and deeplinks (8e88d08)

### Outros

- chore: update iOS build configuration and dependencies (#13) (632a4b7)
- Fix/package.swift fixes (#10) (2728b16)

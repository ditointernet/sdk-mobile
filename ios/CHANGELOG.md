### Outros

- Fix/android ios event callback (#18) (b64edde)

### Correções

- fix(ios): update podspec file paths for DitoSDK (fae0320)

### Funcionalidades

- feat: Change request protocol to RPC & Enable notification central list (#16) (b4ed718)

### Correções

- fix(ios): declarar dependências CocoaPods do DitoSDK (#17) (fcc19fe)

### Outros

- chore(release): ios 3.3.0 (e927ba7)

### Funcionalidades

- feat: Change request protocol to RPC & Enable notification central list (#16) (b4ed718)

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

- chore(ios): Sample — persistência FCM em UserDefaults, log `os.Logger` sem `user_id`, gravação de payloads de debug (JSON/plist/txt) e documentação alinhada
- chore(release): flutter 3.2.3 (81f78d7)

## [3.2.0](https://github.com/ditointernet/sdk-mobile/compare/ios-v3.1.0...ios-v3.2.0) (2026-03-24)

### Funcionalidades

- feat: add User-Agent header with SDK version for Android and iOS (#14) (56b080e)
- feat(notification): add global callback for notification clicks and deeplinks (8e88d08)

### Outros

- chore: update iOS build configuration and dependencies (#13) (632a4b7)
- Fix/package.swift fixes (#10) (2728b16)

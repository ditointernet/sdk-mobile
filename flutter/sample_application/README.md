# Sample Application - Dito SDK Flutter

Aplicacao de exemplo para validar a integracao do `dito_sdk` com Flutter.

## Requisitos

- Flutter 3.3.0+
- iOS 16+ e Android API 24+
- Firebase configurado no projeto
- Chaves de push configuradas no Firebase (APNs para iOS)

## Configuracao

1. Crie o arquivo `.env.development.local` em `flutter/sample_application`:

```
DITO_APP_KEY=seu_app_key
DITO_APP_SECRET=seu_app_secret
```

2. Adicione o `GoogleService-Info.plist` no target iOS do sample:

- `flutter/sample_application/ios/Runner`

3. Habilite no Xcode:

- Push Notifications
- Background Modes -> Remote notifications

4. Configure o Firebase no Android (google-services.json) e no iOS.

## Executar

```bash
cd flutter/sample_application
flutter pub get
flutter run
```

## O que este app demonstra

- Inicializacao do SDK
- Identificacao de usuario
- Track de eventos
- Notificacoes em foreground e background

## Observacoes

- O plugin configura o Firebase Messaging no iOS automaticamente.
- O app precisa ser aberto ao menos uma vez para registrar o token.

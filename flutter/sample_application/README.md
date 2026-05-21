# Sample Application - Dito SDK Flutter

Aplicacao de exemplo para validar a integracao do `dito_sdk` com Flutter.

## Requisitos

- Flutter 3.24.0+
- Dart 3.10.7+
- iOS 16+ e Android API 26+
- Firebase configurado no projeto
- Chaves de push configuradas no Firebase (APNs para iOS)

## Configuracao

1. Crie o arquivo `.env.development.local` em `flutter/sample_application`:

```
API_KEY=seu_app_key
API_SECRET=seu_app_secret
```

2. Adicione o `GoogleService-Info.plist` no target iOS do sample:

- `flutter/sample_application/ios/Runner`

3. Habilite no Xcode:

- Push Notifications
- Background Modes -> Remote notifications

4. Configure o Firebase no Android (`google-services.json`) e no iOS.

5. (Opcional, Android background) Credenciais no manifest para tracking em background — defina em `local.properties` ou variáveis de ambiente:

```
DITO_API_KEY=seu_app_key
DITO_API_SECRET=seu_app_secret
```

O `build.gradle.kts` do sample injeta esses valores como `manifestPlaceholders`. Veja [README do plugin Flutter](../README.md#android).

## SDK iOS nativo local (teste manual)

O `Podfile` usa o `DitoSDK` em `sdk-mobile/ios` quando `DITO_USE_LOCAL_IOS_SDK=1` ou existe `flutter/ios/.use_local_dito_ios_sdk`:

```bash
DITO_USE_LOCAL_IOS_SDK=1 flutter run -d <device_id> --release
# ou
touch ../../ios/.use_local_dito_ios_sdk && flutter run
```

Sem isso, o sample usa o `DitoSDK` do CocoaPods (`~> 3.4.0`).

## Executar

```bash
cd flutter/sample_application
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## O que este app demonstra

- Inicializacao do SDK (`initialize`, `setDebugMode`)
- Identificacao de usuario (`identify` com `customData`)
- Track de eventos
- Registro de token FCM
- Stream `DitoSdk.onNotificationClick` e delegacao via `handleNotificationClick`
- Handler de background opcional com `handleNotificationReceived`
- Notification inbox (`getNotifications`, `markNotificationAsRead`)
- Opcoes de notificacao (`setNotificationOptions`)

## Observacoes

- O plugin configura o Firebase Messaging no iOS automaticamente.
- O app precisa ser aberto ao menos uma vez para registrar o token FCM.
- No iOS, receive em app morto/background e tratado principalmente pelo plugin nativo; o background handler Dart e fallback.

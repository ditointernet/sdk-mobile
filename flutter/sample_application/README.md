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

Sem isso, o sample usa o `DitoSDK` do trunk do CocoaPods, na versão pedida por
`flutter/ios/dito_sdk.podspec` (`~> 3.6`).

## Push rico no iOS: o target `NotificationServiceExtension`

O projeto iOS deste sample tem **três** targets: `Runner`, `RunnerTests` e
`NotificationServiceExtension`. O terceiro não é acessório — sem ele, um push rico chega no
iOS só com título e corpo, sem imagem e sem botões, e **sem nenhum erro**. Quem baixa a
imagem e registra a categoria com as actions é a extension, num processo próprio; nada disso
passa pelo Dart.

- `ios/NotificationServiceExtension/NotificationService.swift` — herda de
  `DitoNotificationService`, e é só isso.
- `ios/NotificationServiceExtension/Info.plist` — aponta o `NSExtensionPrincipalClass` e liga
  o `DitoPushDebugLog`.
- O bloco `target 'NotificationServiceExtension'` no `Podfile`, irmão do `Runner` e não
  aninhado nele, linkando só o pod extension-safe.

Depois de um `pod install`, confirme que o `.appex` foi realmente embutido — o erro silencioso
aqui é o target existir e não entrar no app:

```bash
find ~/Library/Developer/Xcode/DerivedData -name 'NotificationServiceExtension.appex' | head
```

Ao contrário do sample nativo, aqui o `DitoPushDebugLog` vem **ligado** no `Info.plist` da
extension: este app existe para diagnosticar push e roda só com credenciais de teste. Para
ver o payload como o iOS o entregou à extensão:

```bash
log stream --predicate 'eventMessage CONTAINS "DITO_PUSH_PAYLOAD"'
```

Nenhuma linha durante um push significa que a extensão não foi acordada — olhe o payload
(`mutable-content: 1`) antes de suspeitar do SDK.

O passo a passo para replicar isso num app integrador está em
[README do plugin Flutter](../README.md#ios-a-notification-service-extension-não-é-opcional).

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
- Push rico (imagem, botões e `custom_data`), incluindo o target de NSE que o iOS exige

## Observacoes

- O plugin configura o Firebase Messaging no iOS automaticamente.
- O app precisa ser aberto ao menos uma vez para registrar o token FCM.
- No iOS, receive em app morto/background e tratado principalmente pelo plugin nativo; o background handler Dart e fallback.
- **O painel "Último push" só preenche com o app em foreground.** Ele é alimentado por
  `FirebaseMessaging.onMessage`, que no iOS não dispara com o app em background — e um teste
  de push rico é feito justamente com o app em background. Ver o painel vazio não significa
  que o payload veio sem `custom_data`: com o app em background, o `custom_data` aparece no
  bloco de **último clique**, quando a notificação é tocada, via
  `DitoSdk.onNotificationClick`.

## 🧭 Playbooks

Este app é um dos alvos dos playbooks de teste (Parte C do teste local), e a
`NotificationServiceExtension` daqui é a referência funcionando para push rico no iOS:

- **[Teste de push local](../../playbook/run-local-test.md)** — payload sintético, sem depender do painel.
- **[Teste de push em produção](../../playbook/run-prod-test.md)** — push real disparado do painel, com reconciliação aparelho ↔ painel.
- **[Integração assistida](../../playbook/playbook-integracao.md)** — para instalar a SDK num app Flutter que **não** é deste repositório.

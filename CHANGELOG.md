# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Adicionado

#### Push rico (imagem, botões de ação e custom data)

Uma campanha pode trazer imagem, até dois botões de ação e custom data. As chaves no payload
FCM são **aditivas e condicionais** — só aparecem quando a campanha usa o recurso — então um
app com SDK anterior continua recebendo e renderizando push exatamente como antes.

Versões mínimas por recurso:

| Recurso | Android | iOS | Flutter | React Native |
|---|---|---|---|---|
| Imagem | 4.1.0 | 3.6.0 (requer NSE) | 3.4.0 | 1.1.0 |
| Botões de ação | 4.1.0 | 3.6.0 (requer NSE) | 3.4.0 | 1.1.0 |
| Custom data | 4.1.0 | 3.6.0 | 3.4.0 | 1.1.0 |

- **Android SDK**: imagem via `BigPictureStyle`, botões via `addAction`, custom data no
  listener de recebimento e de clique. Novo `DitoNotificationActionReceiver`, já registrado
  no manifest da SDK — o app integrador não declara nada. Migração Room `2 → 3` persiste
  imagem e custom data na inbox.
- **iOS SDK**: novo produto **`DitoSDKNotificationService`**, extension-safe, para a
  Notification Service Extension do app. Imagem como attachment e botões via
  `UNNotificationCategory` registrada dinamicamente. **Sem a NSE, imagem e botões não
  aparecem** e o push degrada para título e corpo. Releases publicam dois pods em lockstep.
- **Flutter**: `DitoSdk.parsePushPayload` e o modelo `DitoPushPayload`/`DitoPushAction`;
  `DitoNotificationClick` ganhou `actionId`, `actionLabel`, `customData` e `isActionClick`;
  `DitoNotificationInfo` ganhou `image` e `customData`. O clique agora chega ao Dart também
  quando nasce na notificação nativa — antes só o clique roteado por
  `handleNotificationClick` era emitido, e um toque em botão nunca passa por lá.
- **React Native**: `parsePushPayload` e `hasRichContent` em TypeScript, e a bridge de
  notificação que o pacote não tinha: `DitoSdk.onNotificationClick`,
  `DitoSdk.getInitialNotificationClick`, `DitoSdk.getNotifications` e
  `DitoSdk.markNotificationAsRead`, com os modelos `DitoNotificationClick` e
  `DitoNotificationInfo`. `onNotificationClick` é o único ponto onde o JavaScript distingue
  toque em botão de toque no corpo.
- Clique em botão **reusa** o evento `click-notification`, com `action_id` e `action_label`
  na custom data do evento. Consequência aceita: o CTR soma corpo e botão; a segmentação por
  `action_id` é o que separa os dois nos relatórios.

#### Cross-Platform
- Método público `logout` nas SDKs Flutter e React Native para limpar localmente dados persistidos por `identify` e a identidade local usada por tracking.
- O logout não remove configuração da SDK, opções de notificação, inbox de notificações, tokens de push ou dados remotos no backend.

### Corrigido

#### React Native SDK
- O gate de canal comparava `channel` com `"Dito"` de forma exata, nas duas plataformas,
  enquanto o backend emite `"DITO"`. Na prática **nenhum** push da Dito era processado pela
  bridge React Native. No iOS havia um segundo problema no mesmo lugar: a chave era lida só
  no topo do payload, e num push real ela vive dentro de `data`. A comparação agora é
  insensível a caixa e o lookup cobre os dois níveis, como o plugin Flutter já fazia.
- `handleNotificationClick` chamava a sobrecarga de um argumento de
  `Dito.notificationClick`, que **não** invoca o `notificationClickDataListener` — nenhum
  clique era observável, nem pela bridge nem por um listener do app host. Agora usa a
  sobrecarga que invoca, e garante a chave `deeplink` a partir de `link` (a única que a SDK
  lê), como o plugin Flutter já fazia.
- O build do módulo Android **não compilava**: o `settings.gradle` inclui a `:dito-sdk`, cujo
  script resolve tudo pelo version catalog do build `android/`, e o catalog não era
  declarado; o `buildscript` fixava AGP 8.5.2 e Kotlin 1.9.0 contra os 8.7.0 e 2.0.0 que a
  `:dito-sdk` pede; não havia `gradle.properties`, então `android.useAndroidX` faltava; e a
  dependência `com.facebook.react:react-native:+` resolvia a 0.20.1, última publicada com
  esse nome no Maven Central. Agora `./gradlew :compileDebugKotlin` roda.

### Alterado

#### Flutter
- CI com versão de Flutter fixada (`3.44.5`) em vez de só `channel: stable`, para build
  reproduzível.
- `environment` do pubspec passou a declarar um par coerente: `flutter: '>=3.38.0'` com
  `sdk: '>=3.10.7'`. O par anterior (`flutter: '>=3.24.0'`) descrevia uma combinação
  inexistente, já que Flutter 3.24 ship Dart 3.5. **Não sobe o piso de compatibilidade** — o
  `sdk:`, que é o que o pub aplica, já o fixava em Dart 3.10.7.

### Limitações conhecidas

- **React Native não tem bridge de notificação exposta ao JS.** Não há stream de clique nem
  inbox no lado JavaScript; só helpers nativos estáticos que o app chama do próprio
  AppDelegate/Service. Então o push rico chega até a SDK nativa e é renderizado, mas o app
  RN não recebe o clique com `action_id` em JS. Alcançar a paridade com Flutter exige
  construir essa bridge, que é trabalho próprio e não faz parte desta entrega.
- **Validação de renderização em device ainda não foi feita** em nenhuma plataforma. Imagem
  aparecendo, botão aparecendo, ordem preservada e degradação sem NSE dependem de push real
  em device.

## [3.0.1] - 2026-02-04

### Alterado

#### Android SDK
- Preparação da publicação do AAR no Maven Central (`br.com.dito:ditosdk`) com `sources` e `javadoc` via `maven-publish`
- Versão controlada por `VERSION_NAME` (pipeline de release)

#### iOS SDK
- Atualização do CocoaPods spec para `DitoSDK` `3.0.1`

#### Flutter Plugin
- Versão do plugin atualizada para `3.0.1`
- Padronização das assinaturas públicas com as plataformas nativas (ex.: `identify`, `track`, `registerDeviceToken`)

#### React Native Plugin
- Padronização das assinaturas públicas com as plataformas nativas (ex.: `identify`, `track`, `registerDeviceToken`)

## [1.0.0] - 2024-01-XX

### Adicionado

#### Flutter Plugin
- Inicialização do SDK com API key e secret
- Identificação de usuários com id, name, email e customData
- Rastreamento de eventos com action e data
- Registro de tokens de dispositivo para push notifications
- Interceptação de push notifications (Android e iOS)
- Tratamento de erros robusto com mensagens descritivas
- Validação de parâmetros
- Documentação completa com exemplos
- App de exemplo demonstrando todas as funcionalidades

#### React Native Plugin
- Inicialização do SDK com API key e secret
- Identificação de usuários com id, name, email e customData
- Rastreamento de eventos com action e data
- Registro de tokens de dispositivo para push notifications
- Interceptação de push notifications (Android e iOS)
- Tratamento de erros robusto com mensagens descritivas
- Validação de parâmetros
- Documentação completa com exemplos
- App de exemplo demonstrando todas as funcionalidades

#### Cross-Platform
- APIs unificadas para Flutter e React Native
- Suporte completo para iOS e Android
- Integração com SDKs nativos Dito
- Métodos estáticos para interceptação de push notifications
- Verificação de channel="Dito" para push notifications

### Documentação
- README completo para Flutter plugin
- README completo para React Native plugin
- README do monorepo com visão geral
- Guias de integração para push notifications
- Seções de troubleshooting
- Exemplos de código para todas as funcionalidades

### Testes
- Testes unitários para Flutter
- Testes unitários para React Native
- Testes de integração para push notifications
- Cobertura de testes para funcionalidades principais

## [0.0.1] - 2024-01-XX

### Adicionado
- Estrutura inicial do monorepo
- SDKs nativas iOS e Android
- Estrutura base para plugins Flutter e React Native

[3.0.1]: https://github.com/ditointernet/sdk-mobile/releases/tag/v3.0.1
[1.0.0]: https://github.com/ditointernet/sdk-mobile/releases/tag/v1.0.0
[0.0.1]: https://github.com/ditointernet/sdk-mobile/releases/tag/v0.0.1

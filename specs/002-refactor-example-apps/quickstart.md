# Quickstart: Aplicações de Exemplo

**Feature**: 002-refactor-example-apps
**Date**: 2025-01-27

## Visão Geral

Este guia mostra como configurar e executar as aplicações de exemplo em cada plataforma.

## Pré-requisitos

### Todas as Plataformas
- Credenciais da API Dito (API Key e API Secret)
- Arquivo `.env.development.local` configurado

### iOS
- Xcode 14+
- iOS 16.0+
- CocoaPods ou Swift Package Manager

### Android
- Android Studio
- Android SDK API 24+
- Gradle

### Flutter
- Flutter 3.3.0+
- Dart 3.10.7+

### React Native
- Node.js 16+
- React Native 0.72.0+
- CocoaPods (para iOS)

## Configuração Inicial

### 1. Criar Arquivo .env.development.local

Crie um arquivo `.env.development.local` na raiz de cada aplicação de exemplo:

**iOS**: `ios/SampleApplication/.env.development.local`
**Android**: `android/example-app/.env.development.local`
**Flutter**: `flutter/example/.env.development.local`
**React Native**: `react-native/example/.env.development.local`

**Template**:
```env
API_KEY=your-api-key-here
API_SECRET=your-api-secret-here
USER_ID=user123
USER_NAME=John Doe
USER_EMAIL=john@example.com
USER_PHONE=+5511999999999
USER_ADDRESS=123 Main St
USER_CITY=São Paulo
USER_STATE=SP
USER_ZIP=01234-567
USER_COUNTRY=Brazil
```

### 2. Criar Arquivo .env.development.local.example

Crie também um arquivo `.env.development.local.example` como template (sem valores sensíveis):

```env
API_KEY=
API_SECRET=
USER_ID=
USER_NAME=
USER_EMAIL=
USER_PHONE=
USER_ADDRESS=
USER_CITY=
USER_STATE=
USER_ZIP=
USER_COUNTRY=
```

## Executando as Aplicações

### iOS

1. Abrir projeto no Xcode:
```bash
cd ios/SampleApplication
open SampleApplication.xcworkspace
```

2. Instalar dependências (se usando CocoaPods):
```bash
pod install
```

3. Configurar arquivo .env:
   - Adicionar `.env.development.local` ao projeto
   - Garantir que está incluído no bundle

4. Executar no simulador ou dispositivo

### Android

1. Abrir projeto no Android Studio:
```bash
cd android/example-app
```

2. Configurar arquivo .env:
   - Colocar `.env.development.local` em `src/main/assets/`
   - Ou configurar via `gradle.properties`

3. Sincronizar projeto Gradle

4. Executar no emulador ou dispositivo

### Flutter

1. Instalar dependências:
```bash
cd flutter/example
flutter pub get
```

2. Configurar arquivo .env:
   - Colocar `.env.development.local` na raiz do exemplo
   - Adicionar ao `pubspec.yaml` em `flutter.assets`

3. Executar:
```bash
flutter run
```

### React Native

1. Instalar dependências:
```bash
cd react-native/example
npm install
```

2. Configurar arquivo .env:
   - Colocar `.env.development.local` na raiz do exemplo
   - Configurar `react-native-config` se necessário

3. Executar iOS:
```bash
cd ios
pod install
cd ..
npm run ios
```

4. Executar Android:
```bash
npm run android
```

## Fluxo de Uso

### 1. Inicializar SDK

1. Abrir aplicação
2. Campos API Key e API Secret devem estar preenchidos do `.env`
3. Clicar em "Initialize"
4. Verificar status mudar para "Initialized"

### 2. Identificar Usuário

1. Campos de usuário devem estar preenchidos do `.env`
2. Verificar/corrigir campos obrigatórios (User ID, Email)
3. Clicar em "Identify User"
4. Verificar status mudar para "User Identified"

### 3. Rastrear Evento

1. Preencher campo "Event Name" (ex: "purchase")
2. Clicar em "Track Event"
3. Verificar mensagem de sucesso

### 4. Registrar Token

1. Preencher campo "FCM Device Token"
2. Clicar em "Register Token"
3. Verificar mensagem de sucesso

### 5. Desregistrar Token (Opcional)

1. Preencher campo "FCM Device Token"
2. Clicar em "Unregister Token"
3. Verificar mensagem de sucesso

## Validação

### Checklist de Validação

- [ ] Arquivo `.env.development.local` existe e está configurado
- [ ] Aplicação carrega valores do `.env` corretamente
- [ ] Inicialização do SDK funciona
- [ ] Identificação de usuário funciona
- [ ] Rastreamento de eventos funciona
- [ ] Registro de token funciona
- [ ] Desregistro de token funciona (se disponível)
- [ ] Validação de campos obrigatórios funciona
- [ ] Mensagens de erro são claras
- [ ] Interface é responsiva e intuitiva

## Troubleshooting

### Valores do .env não são carregados

**iOS**: Verificar se arquivo está incluído no bundle do app
**Android**: Verificar se arquivo está em `src/main/assets/`
**Flutter**: Verificar se arquivo está listado em `pubspec.yaml`
**React Native**: Verificar configuração do `react-native-config`

### SDK não inicializa

- Verificar se API Key e API Secret estão corretos
- Verificar logs de erro no console
- Verificar se SDK nativo está configurado corretamente

### Campos não são validados

- Verificar implementação de validação
- Verificar se campos obrigatórios estão marcados corretamente
- Verificar mensagens de erro

## Próximos Passos

Após validar as aplicações de exemplo:
1. Testar em diferentes dispositivos/versões
2. Verificar comportamento consistente entre plataformas
3. Documentar qualquer diferença de comportamento
4. Atualizar documentação conforme necessário

# Feature Specification: Refatorar Aplicações de Exemplo

**Feature ID**: 002-refactor-example-apps
**Priority**: P2
**Status**: Planning

## Objetivo

Refatorar as aplicações de exemplo em cada projeto (iOS, Android, Flutter, React Native) para usar o novo plugin Dito SDK, garantindo consistência de comportamento e interface entre todas as plataformas.

## Requisitos Funcionais

### RF1: Campos de Configuração Obrigatórios
- Campo de texto para API Key (obrigatório)
- Campo de texto para API Secret (obrigatório)
- Campo de texto para User ID (obrigatório)
- Campo de texto para User Email (obrigatório)

### RF2: Campos de Dados do Usuário Opcionais
- Campo de texto para User Name
- Campo de texto para User Phone
- Campo de texto para User Address
- Campo de texto para User City
- Campo de texto para User State
- Campo de texto para User ZIP
- Campo de texto para User Country

### RF3: Ações do SDK
- Botão para registrar/identificar usuário (identify)
- Botão para disparar evento (track) com campo de texto para nome do evento
- Botão para registrar token de dispositivo (registerDeviceToken)
- Botão para desregistrar token de dispositivo (unregisterDeviceToken)

### RF4: Carregamento de Configuração
- Todos os campos devem ser preenchidos automaticamente com valores do arquivo `.env.development.local`
- O arquivo deve ser lido em tempo de execução (não build time)
- Valores padrão devem ser fornecidos se o arquivo não existir

### RF5: Consistência Cross-Platform
- As telas devem ter o mesmo comportamento em todas as plataformas (iOS, Android, Flutter, React Native)
- Layout e UX devem ser consistentes entre plataformas
- Validação de campos deve ser idêntica em todas as plataformas
- Mensagens de erro devem ser consistentes

## Requisitos Não-Funcionais

### RNF1: Performance
- Carregamento inicial da tela < 500ms
- Operações do SDK devem manter performance < 100ms init, < 16ms ops

### RNF2: Usabilidade
- Interface intuitiva e fácil de usar
- Feedback visual claro para ações do usuário
- Mensagens de erro descritivas

### RNF3: Manutenibilidade
- Código deve seguir padrões de cada plataforma
- Estrutura de código consistente entre exemplos
- Documentação inline adequada

## Plataformas Alvo

- iOS (Swift/UIKit ou SwiftUI)
- Android (Kotlin/Android Views ou Jetpack Compose)
- Flutter (Dart/Material Design)
- React Native (TypeScript/React Native Components)

## Arquivos de Exemplo Existentes

- iOS: `ios/SampleApplication/`
- Android: `android/` (verificar estrutura)
- Flutter: `flutter/example/lib/main.dart`
- React Native: `react-native/example/App.tsx`

## Dependências

- Dito SDK Plugin (já implementado)
- Suporte a arquivos `.env` em cada plataforma:
  - iOS: SwiftDotenv ou similar
  - Android: gradle.properties ou BuildConfig
  - Flutter: flutter_dotenv
  - React Native: react-native-dotenv ou react-native-config

## Entregas

1. Aplicação de exemplo iOS refatorada
2. Aplicação de exemplo Android refatorada
3. Aplicação de exemplo Flutter refatorada
4. Aplicação de exemplo React Native refatorada
5. Arquivo `.env.development.local.example` para cada plataforma
6. Documentação de uso dos exemplos

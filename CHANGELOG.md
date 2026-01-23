# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

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

[1.0.0]: https://github.com/ditointernet/dito_sdk_flutter/releases/tag/v1.0.0
[0.0.1]: https://github.com/ditointernet/dito_sdk_flutter/releases/tag/v0.0.1

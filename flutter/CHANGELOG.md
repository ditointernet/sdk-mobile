### Outros

- refactor(flutter): Simplify error handling in DitoSdk methods (fe7db44)

### Funcionalidades

- feat(docs): Update README and configuration for background notification tracking in Android and iOS (fac2d56)
- feat(android): Enhance Firebase Messaging integration and update dependencies (08f6411)

### Correções

- fix(dependencies): downgrade flutter_lints version in pubspec.yaml files (b12c4e6)

### Outros

- chore(pubspec): update SDK constraints in pubspec.yaml files (4467436)
- chore(pubspec): remove pubspec.lock and add resolution directive (4155703)
- refactor(workflows): update example directory references in CI configurations (5fef648)

# Changelog

Todas as mudanças notáveis neste plugin serão documentadas neste arquivo.

## [1.0.0] - 2024-01-XX

### Adicionado
- Inicialização do SDK com `initialize(apiKey, apiSecret)`
- Identificação de usuários com `identify(id, name, email, customData)`
- Rastreamento de eventos com `track(action, data)`
- Registro de tokens de dispositivo com `registerDeviceToken(token)`
- Interceptação de push notifications via métodos estáticos
- Tratamento de erros robusto com mensagens descritivas
- Validação de parâmetros (API keys, emails, IDs, etc.)
- Documentação completa com exemplos
- App de exemplo demonstrando todas as funcionalidades

### Melhorado
- Mensagens de erro mais descritivas e úteis
- Documentação com guias de integração para push notifications
- Exemplos de código atualizados

## [0.0.1] - 2024-01-XX

### Adicionado
- Estrutura inicial do plugin Flutter
- Integração básica com SDKs nativas

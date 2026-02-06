### Funcionalidades

- feat(notification): add global callback for notification clicks and deeplinks (8e88d08)

### Outros

- chore(flutter): update .pubignore and CHANGELOG (e173f66)

## [3.1.3] - 2025-02-05

### Correções
- Corrigido uso de `rethrow` em tratamento de exceções para seguir melhores práticas do Dart
- Corrigido uso de `initializing formals` em construtores

### Outros
- Removida `sample_application` do pacote publicável
- Adicionado `.pubignore` para exclusão de arquivos desnecessários
- Removida configuração de workspace do pubspec
- Excluída `sample_application` da análise de código do SDK
- Removidos builds de exemplo dos workflows de CI

### Outros

- chore(dependencies): update pubspec.lock with version downgrades and updated checksums (b0327de)
- chore(flutter): Add .pubignore and update pubspec files (c78643e)

### Outros

- chore(flutter): Exclude sample application from analysis (633e8fe)

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

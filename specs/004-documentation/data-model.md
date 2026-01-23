# Data Model: Estrutura de Documentação

**Feature**: 004-documentation
**Date**: 2025-01-27

## Entidades de Documentação

### README Principal (raiz)

**Arquivo**: `README.md`
**Localização**: Raiz do repositório

**Estrutura**:
- Visão geral do monorepo
- Links para documentação de cada plataforma
- Guia rápido de início
- Lista de TODOs/FIXMEs
- Seção sobre licença (link para LICENSE)
- Troubleshooting geral

**Relacionamentos**:
- Linka para: iOS README, Android README, Flutter README, React Native README
- Linka para: docs/push-notifications.md
- Linka para: docs/todos.md
- Linka para: LICENSE

### README iOS

**Arquivo**: `ios/README.md`
**Localização**: Diretório iOS

**Estrutura**:
- Visão geral iOS SDK
- Requisitos (iOS version, Xcode, Swift)
- Instalação (CocoaPods, SPM)
- Configuração inicial (Info.plist)
- Métodos públicos documentados
- Push Notifications iOS
- Tratamento de erros
- Troubleshooting
- Exemplos
- Licença (referência ao LICENSE)

**Métodos a Documentar**:
- `Dito.configure()`
- `Dito.identify(id:name:email:customData:)`
- `Dito.track(action:data:)`
- `Dito.registerDevice(token:)`
- `Dito.unregisterDevice(token:)`
- `Dito.notificationRead(userInfo:token:)`
- `Dito.notificationClick(userInfo:callback:)`

### README Android

**Arquivo**: `android/README.md`
**Localização**: Diretório Android

**Estrutura**:
- Visão geral Android SDK
- Requisitos (Android API, Kotlin, Gradle)
- Instalação (Gradle)
- Configuração inicial (AndroidManifest.xml)
- Métodos públicos documentados
- Push Notifications Android
- Tratamento de erros
- Troubleshooting
- Exemplos
- Licença (referência ao LICENSE)

**Métodos a Documentar**:
- `Dito.init(context, options)`
- `Dito.identify(id, name, email, customData)`
- `Dito.track(action, data)`
- `Dito.registerDevice(token)`
- `Dito.unregisterDevice(token)`
- `Dito.notificationRead(userInfo)`
- `Dito.notificationClick(userInfo, callback)`

### README Flutter

**Arquivo**: `flutter/README.md`
**Localização**: Diretório Flutter

**Estrutura**:
- Visão geral Flutter Plugin
- Requisitos (Flutter, Dart)
- Instalação (pubspec.yaml)
- Configuração inicial
- Métodos públicos documentados
- Push Notifications Flutter
- Tratamento de erros
- Troubleshooting
- Exemplos
- Licença (referência ao LICENSE)

**Métodos a Documentar**:
- `DitoSdk.initialize(apiKey, apiSecret)`
- `DitoSdk.identify({id, name, email, customData})`
- `DitoSdk.track({action, data})`
- `DitoSdk.registerDeviceToken(token)`
- `DitoSdk.unregisterDeviceToken(token)`

### README React Native

**Arquivo**: `react-native/README.md`
**Localização**: Diretório React Native

**Estrutura**:
- Visão geral React Native Plugin
- Requisitos (React Native, TypeScript, Node.js)
- Instalação (npm/yarn)
- Configuração inicial (linking)
- Métodos públicos documentados
- Push Notifications React Native
- Tratamento de erros
- Troubleshooting
- Exemplos
- Licença (referência ao LICENSE)

**Métodos a Documentar**:
- `DitoSdk.initialize({apiKey, apiSecret})`
- `DitoSdk.identify({id, name, email, customData})`
- `DitoSdk.track({action, data})`
- `DitoSdk.registerDeviceToken(token)`
- `DitoSdk.unregisterDeviceToken(token)`

### Guia de Push Notifications

**Arquivo**: `docs/push-notifications.md`
**Localização**: Diretório docs

**Estrutura**:
- Visão geral Push Notifications
- Configuração Firebase
- Interceptação de notificações
- Tracking automático
- Handling de clicks
- Deeplinks
- Troubleshooting unificado

### Lista de TODOs

**Arquivo**: `docs/todos.md`
**Localização**: Diretório docs

**Estrutura**:
- TODOs por plataforma
- FIXMEs encontrados
- Melhorias planejadas
- Issues conhecidas

### Arquivo LICENSE

**Arquivo**: `LICENSE`
**Localização**: Raiz do repositório

**Estrutura**:
- Cabeçalho com copyright
- Permissões (uso das SDKs)
- Restrições (proibição de modificação e cópia)
- Avisos legais
- Informações de contato

**Conteúdo**:
- Permite uso das SDKs em aplicações comerciais
- Proíbe modificação do código fonte
- Proíbe cópia e redistribuição do código
- Requer manutenção de avisos de copyright
- Permite uso em aplicações próprias dos clientes

**Relacionamentos**:
- Referenciado por: README principal, READMEs de plataforma
- Pode ter versões específicas em: ios/LICENSE, flutter/LICENSE (devem referenciar LICENSE raiz)

## Modelo de Método Documentado

### Estrutura Padrão

```markdown
### Método: nomeDoMetodo

**Descrição**: Descrição clara do que o método faz

**Assinatura**:
```linguagem
assinatura completa do método
```

**Parâmetros**:
| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| param1 | Tipo | Sim | Descrição do parâmetro |

**Retorno**:
- Tipo: Descrição do retorno

**Possíveis Erros**:
- `ERROR_CODE`: Descrição do erro e quando ocorre

**Exemplo**:
```linguagem
exemplo de código completo
```

**Notas**:
- Informações adicionais importantes
```

## Validação

### Regras de Validação

1. Todos os métodos públicos devem estar documentados
2. Todas as assinaturas devem estar corretas
3. Todos os exemplos devem ser testáveis
4. Todos os links devem estar funcionais
5. Estrutura deve ser consistente entre plataformas

### Checklist de Qualidade

- [ ] Instalação passo a passo completa
- [ ] Configuração inicial documentada
- [ ] Todos os métodos públicos documentados
- [ ] Tipagens corretas
- [ ] Exemplos de código funcionais
- [ ] Tratamento de erros documentado
- [ ] Troubleshooting incluído
- [ ] Links externos funcionais
- [ ] Formatação consistente

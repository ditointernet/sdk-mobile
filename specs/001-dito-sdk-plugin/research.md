# Research & Technical Decisions

**Feature**: Plugin Flutter dito_sdk
**Date**: 2025-01-27

## Decisões Técnicas

### D1: Arquitetura de Comunicação Flutter-Native

**Decision**: Usar Flutter MethodChannel com nome 'br.com.dito/dito_sdk'

**Rationale**:
- MethodChannel é o mecanismo padrão do Flutter para comunicação com código nativo
- Permite chamadas assíncronas sem bloquear a thread principal
- Suporta tipos de dados complexos (Map, List) necessários para customData
- Nome do channel segue convenção de reverse domain notation

**Alternatives considered**:
- EventChannel: Rejeitado - não necessário para operações request/response
- Platform Views: Rejeitado - não há necessidade de UI nativa
- Pigeon: Considerado mas rejeitado - adiciona complexidade desnecessária para este caso

### D2: Estrutura da API Dart

**Decision**: Classe estática `DitoSdk` com métodos estáticos assíncronos

**Rationale**:
- API estática é mais simples para desenvolvedores (não precisa instanciar)
- Padrão comum em plugins Flutter (ex: Firebase, Analytics)
- Métodos assíncronos permitem operações não-bloqueantes
- Facilita uso: `await DitoSdk.initialize(...)`

**Alternatives considered**:
- Classe instanciável: Rejeitado - adiciona complexidade sem benefício
- Singleton: Considerado mas rejeitado - estático é mais simples e suficiente

### D3: Tratamento de Push Notifications

**Decision**: Métodos estáticos nos plugins nativos para interceptação seletiva

**Rationale**:
- Push notifications precisam ser interceptadas no código nativo antes de chegar ao Flutter
- Verificação do campo "channel" == "Dito" permite processar apenas notificações relevantes
- Métodos estáticos permitem chamada direta do código do app host (Firebase Messaging, etc.)
- Retorno booleano indica se a notificação foi processada pela Dito SDK

**Android Implementation**:
- `handleNotification(context, message)` - compatível com Firebase Messaging
- Verifica `message.data["channel"] == "Dito"`
- Chama `Dito.registerDevice()` se necessário

**iOS Implementation**:
- `didReceiveNotificationRequest(_ request)` - compatível com UNUserNotificationCenter
- Verifica `request.content.userInfo["channel"] == "Dito"`
- Chama método correspondente da DitoSDK

**Alternatives considered**:
- Processar todas as notificações: Rejeitado - pode interferir com outras funcionalidades
- EventChannel para notificações: Rejeitado - interceptação precisa ser no nível nativo

### D4: Gerenciamento de Dependências Nativas

**Decision**:
- Android: `implementation 'br.com.dito:dito-sdk:2.+'` em build.gradle
- iOS: `s.dependency 'DitoSDK'` em podspec

**Rationale**:
- Versão 2.+ no Android permite atualizações automáticas de patch e minor
- Dependência via podspec é padrão para plugins Flutter iOS
- Mantém compatibilidade com versões futuras das SDKs nativas

**Alternatives considered**:
- Versão fixa (ex: 2.0.0): Rejeitado - requer atualizações manuais frequentes
- Versão major (2.+): Aceito - balance entre estabilidade e atualizações

### D5: Tratamento de Erros

**Decision**: Usar PlatformException para erros nativos, Exception para erros Dart

**Rationale**:
- PlatformException é padrão do Flutter para erros de platform channels
- Permite passar código de erro, mensagem e detalhes
- Desenvolvedores podem tratar erros específicos por código
- Mensagens descritivas facilitam debugging

**Error Codes Planejados**:
- `INITIALIZATION_FAILED`: Falha na inicialização
- `INVALID_CREDENTIALS`: Credenciais inválidas
- `NOT_INITIALIZED`: Plugin não inicializado
- `NETWORK_ERROR`: Erro de rede
- `INVALID_PARAMETERS`: Parâmetros inválidos

**Alternatives considered**:
- Custom Exception classes: Rejeitado - PlatformException é suficiente e padrão
- Result objects (Success/Error): Considerado mas rejeitado - adiciona complexidade sem benefício claro

### D6: Validação de Parâmetros

**Decision**: Validar parâmetros no lado Dart antes de chamar nativo

**Rationale**:
- Validação em Dart é mais rápida (não precisa fazer round-trip para nativo)
- Mensagens de erro mais claras para desenvolvedores
- Reduz chamadas desnecessárias ao código nativo
- Mantém lógica de validação centralizada

**Alternatives considered**:
- Validar apenas no nativo: Rejeitado - menos eficiente e mensagens menos claras
- Validar em ambos: Considerado mas rejeitado - redundante, Dart é suficiente

### D7: APIs Específicas das SDKs Nativas

**Decision**: Mapear métodos Dart para APIs específicas de cada plataforma nativa

**iOS SDK (DitoSDK)** - Baseado em [dito_ios](https://github.com/ditointernet/dito_ios):
- Inicialização: `Dito.shared.configure()` ou via Info.plist (DitoApiKey, DitoApiSecret)
- Identificação: `Dito.identify(id: String, data: [String: Any]?)`
- Tracking: `Dito.track(event: DitoEvent)` onde `DitoEvent` contém `name` e `data`
- Token: `Dito.registerDevice(token: String)`
- Push Notifications:
  - `Dito.notificationRead(with userInfo: [AnyHashable: Any], token: String)` - quando notificação é recebida
  - `Dito.notificationClick(with userInfo: [AnyHashable: Any])` - quando usuário clica na notificação
- Ordem crítica: Firebase deve ser configurado ANTES do Dito SDK (iOS 18+)

**Android SDK** - Baseado em [sdk_mobile_android](https://github.com/ditointernet/sdk_mobile_android):
- Inicialização: `br.com.dito.ditosdk.Dito.init(apiKey: String, apiSecret: String)`
- Identificação: `Dito.identify(id: String, name: String?, email: String?, customData: Map<String, Any>?)`
- Tracking: `Dito.track(action: String, data: Map<String, Any>?)`
- Token: `Dito.registerDevice(token: String)`
- Push Notifications: Processamento via Firebase Messaging Service

**Rationale**:
- APIs nativas têm estruturas diferentes (iOS usa objetos, Android usa parâmetros diretos)
- Plugin deve abstrair essas diferenças fornecendo interface unificada
- Push notifications requerem tratamento específico em cada plataforma

**Mapeamento Dart → Nativo**:
- `initialize()` → iOS: `Dito.shared.configure()`, Android: `Dito.init()`
- `identify()` → iOS: `Dito.identify(id:data:)`, Android: `Dito.identify(id, name, email, customData)`
- `track()` → iOS: `Dito.track(event:)`, Android: `Dito.track(action, data)`
- `registerDeviceToken()` → iOS: `Dito.registerDevice(token:)`, Android: `Dito.registerDevice(token)`

**Alternatives considered**:
- Expor APIs nativas diretamente: Rejeitado - quebra abstração e consistência
- Criar objetos intermediários: Considerado mas rejeitado - adiciona complexidade sem benefício

### D8: Tratamento de Push Notifications - Detalhes Específicos

**Decision**: Implementar métodos estáticos nativos que chamam APIs específicas de push da Dito SDK

**iOS Implementation**:
- `didReceiveNotificationRequest` deve chamar:
  - `Dito.notificationRead(with: userInfo, token: fcmToken)` quando notificação é recebida
  - `Dito.notificationClick(with: userInfo)` quando usuário interage com notificação
- Requer FCM token disponível para `notificationRead`
- Deve ser chamado nos delegates do UNUserNotificationCenter

**Android Implementation**:
- `handleNotification` deve processar via Firebase Messaging Service
- Verificar `channel == "Dito"` antes de processar
- Chamar métodos correspondentes da SDK Android

**Rationale**:
- SDKs nativas têm métodos específicos para tracking de push notifications
- Permite analytics precisos sobre abertura e cliques em notificações
- Mantém compatibilidade com Firebase Messaging

**Alternatives considered**:
- Ignorar tracking de push: Rejeitado - funcionalidade importante para analytics
- Processar apenas no Flutter: Rejeitado - precisa ser no nível nativo para funcionar corretamente

## Referências e Padrões

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Flutter Plugin Development](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Firebase Cloud Messaging Android](https://firebase.google.com/docs/cloud-messaging/android/client)
- [UNUserNotificationCenter iOS](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)
- [Dito iOS SDK](https://github.com/ditointernet/dito_ios) - Repositório oficial
- [Dito Android SDK](https://github.com/ditointernet/sdk_mobile_android) - Repositório oficial

### D9: Estrutura de Monorepo

**Decision**: Criar monorepo unificado contendo iOS, Android, Flutter e React Native

**Rationale**:
- Facilita manutenção e sincronização de versões entre plataformas
- Permite refatoração coordenada de nomenclatura entre iOS e Android
- Simplifica CI/CD com workflows unificados
- Facilita compartilhamento de documentação e exemplos
- Reduz overhead de gerenciar múltiplos repositórios

**Estrutura**:
- `ios/`: SDK iOS nativa (migrada de dito_ios)
- `android/`: SDK Android nativa (migrada de sdk_mobile_android)
- `flutter/`: Plugin Flutter (nova implementação)
- `react-native/`: Plugin React Native (nova implementação)

**Alternatives considered**:
- Múltiplos repositórios separados: Rejeitado - dificulta sincronização e manutenção
- Apenas wrappers, SDKs nativas externas: Rejeitado - não permite refatoração coordenada

### D10: Estratégia de Migração

**Decision**: Migrar código existente preservando funcionalidades e estrutura, depois refatorar

**iOS Migration**:
- Fonte: `https://github.com/ditointernet/dito_ios/tree/feat/notification-service-extension`
- Preservar: Estrutura Xcode, notification service extension, todas as funcionalidades
- Migrar: Todo conteúdo do repositório para `ios/`
- Manter: Compatibilidade com versões existentes durante transição

**Android Migration**:
- Fonte: `https://github.com/ditointernet/sdk_mobile_android`
- Preservar: Estrutura Gradle, todas as funcionalidades
- Migrar: Todo conteúdo do repositório para `android/`
- Manter: Compatibilidade com versões existentes durante transição

**Rationale**:
- Migração preserva funcionalidades existentes
- Permite refatoração incremental sem quebrar código existente
- Facilita validação de que migração não introduziu regressões

**Alternatives considered**:
- Reescrever do zero: Rejeitado - perde funcionalidades e histórico
- Migrar e refatorar simultaneamente: Rejeitado - aumenta risco de introduzir bugs

### D11: Padronização de Nomenclatura

**Decision**: Refatorar iOS e Android para manter nomenclatura consistente e organizada

**Objetivos**:
- Mesmos nomes de métodos públicos (adaptados às convenções de cada linguagem)
- Mesmos padrões de parâmetros (quando possível)
- Mesma estrutura conceitual de classes/objetos
- Mesmos códigos de erro

**Processo**:
1. Analisar APIs existentes de ambas as plataformas
2. Definir nomenclatura padrão baseada em:
   - Convenções Swift para iOS
   - Convenções Kotlin para Android
   - Consistência conceitual entre plataformas
3. Criar documento de mapeamento de nomenclatura
4. Refatorar iOS primeiro (estabelecer padrão)
5. Refatorar Android para seguir padrão
6. Validar que wrappers funcionam com ambas

**Exemplos de Padronização**:
- Inicialização: iOS `Dito.shared.configure()`, Android `Dito.init()` - conceitualmente equivalente
- Identificação: Padronizar estrutura de dados mesmo que sintaxe difira
- Tracking: Padronizar nomes de eventos e estrutura de dados
- Erros: Códigos de erro idênticos entre plataformas

**Rationale**:
- Facilita manutenção e desenvolvimento de wrappers
- Reduz curva de aprendizado para desenvolvedores
- Melhora consistência da experiência do usuário
- Facilita documentação unificada

**Alternatives considered**:
- Manter nomenclaturas diferentes: Rejeitado - quebra requisito explícito
- Forçar nomenclatura idêntica: Rejeitado - violaria convenções de cada linguagem

### D12: Wrappers Flutter e React Native

**Decision**: Implementar wrappers que usam SDKs nativas como dependências locais

**Flutter Wrapper**:
- Usa MethodChannel para comunicação com código nativo
- Depende de SDKs nativas via paths locais durante desenvolvimento
- Abstrai diferenças entre iOS e Android
- Fornece API Dart unificada

**React Native Wrapper**:
- Usa Native Modules para comunicação com código nativo
- Depende de SDKs nativas via paths locais durante desenvolvimento
- Abstrai diferenças entre iOS e Android
- Fornece API TypeScript/JavaScript unificada

**Rationale**:
- Wrappers permitem desenvolvedores usar SDKs sem escrever código nativo
- Abstração unifica experiência entre plataformas
- Dependências locais facilitam desenvolvimento e testes

**Alternatives considered**:
- Wrappers como dependências externas: Rejeitado - dificulta desenvolvimento coordenado
- SDKs nativas como dependências externas: Rejeitado - quebra estrutura de monorepo

## Notas de Implementação

- MethodChannel deve ser criado uma única vez e reutilizado
- Operações assíncronas devem usar `async/await` no Dart
- Push notification handlers devem ser chamados pelo código do app host, não pelo plugin diretamente
- Documentação deve incluir exemplos de integração com Firebase Messaging (Android) e UNUserNotificationCenter (iOS)
- **iOS**: Ordem de inicialização é crítica - Firebase PRIMEIRO, depois Dito SDK
- **iOS**: FCM token deve estar disponível antes de chamar `notificationRead`
- **iOS**: Usar `DitoEvent` para tracking (contém `name` e `data`)
- **Android**: SDK usa parâmetros diretos, não objetos
- Ambos: Verificar `channel == "Dito"` antes de processar push notifications
- **Monorepo**: CI/CD deve testar todas as plataformas em cada PR
- **Migração**: Validar que código migrado mantém todas as funcionalidades
- **Refatoração**: Fazer em etapas, validando após cada mudança
- **Nomenclatura**: Documentar mapeamento entre iOS e Android após padronização

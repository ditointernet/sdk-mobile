# Research: Refatoração de Métodos

**Feature**: 003-refactor-methods
**Date**: 2025-01-27

## Decisões Técnicas

### 1. Estratégia de Refatoração

**Decision**: Refatoração incremental por plataforma, mantendo compatibilidade com APIs públicas

**Rationale**:
- Refatoração não deve quebrar código existente que usa as SDKs
- Mudanças devem ser internas, melhorando apenas implementação
- Cada plataforma pode ser refatorada independentemente
- Testes existentes devem continuar funcionando

**Alternatives Considered**:
- Refatoração completa com breaking changes: Rejeitado - quebraria compatibilidade
- Refatoração apenas de código interno: Escolhido - mantém compatibilidade

### 2. Padrões de Código por Plataforma

#### iOS (Swift)

**Decision**: Seguir padrões definidos em `.cursor/rules/ios.mdc`

**Padrões Aplicáveis**:
- Usar Swift's latest features e protocol-oriented programming
- Preferir value types (structs) sobre classes
- Usar async/await para concorrência
- Result type para erros
- Nomes descritivos em inglês
- camelCase para vars/funcs, PascalCase para types
- Funções curtas com propósito único (< 20 instruções)
- Complexidade ciclomática < 10

**Arquivos a Refatorar**:
- `ios/DitoSDK/Sources/Controllers/Dito.swift`
- `ios/DitoSDK/Sources/Controllers/DitoIdentify.swift`
- `ios/DitoSDK/Sources/Controllers/DitoTrack.swift`
- `ios/DitoSDK/Sources/Controllers/DitoNotification.swift`

#### Android (Kotlin)

**Decision**: Seguir padrões definidos em `.cursor/rules/android.mdc`

**Padrões Aplicáveis**:
- Usar clean architecture
- Funções curtas com propósito único (< 20 instruções)
- Usar data classes para dados
- Preferir imutabilidade
- Evitar aninhamento de blocos (early returns)
- Usar higher-order functions (map, filter, reduce)
- Nomes descritivos em inglês
- camelCase para variáveis/funções, PascalCase para classes
- Complexidade ciclomática < 10

**Arquivos a Refatorar**:
- `android/dito-sdk/src/main/java/br/com/dito/ditosdk/Dito.kt`
- `android/dito-sdk/src/main/java/br/com/dito/ditosdk/tracking/Tracker.kt`

#### Flutter (Dart)

**Decision**: Seguir padrões definidos em `.cursor/rules/flutter.mdc`

**Padrões Aplicáveis**:
- Usar clean architecture
- Funções curtas com propósito único (< 20 instruções)
- Evitar aninhamento profundo de widgets
- Usar const constructors quando possível
- Nomes descritivos em inglês
- camelCase para variáveis/funções, PascalCase para classes
- Complexidade ciclomática < 10
- Documentação DartDoc para funções públicas

**Arquivos a Refatorar**:
- `flutter/lib/dito_sdk.dart`
- `flutter/lib/dito_sdk_method_channel.dart`
- `flutter/lib/dito_sdk_platform_interface.dart`

#### React Native (TypeScript)

**Decision**: Seguir padrões definidos em `.cursor/rules/react-native.mdc`

**Padrões Aplicáveis**:
- Usar TypeScript com strict mode
- Preferir interfaces sobre types
- Evitar enums (usar maps)
- Usar functional components
- Funções curtas com propósito único
- Early returns para evitar aninhamento
- Nomes descritivos em inglês
- camelCase para variáveis/funções, PascalCase para interfaces/classes
- Complexidade ciclomática < 10

**Arquivos a Refatorar**:
- `react-native/src/index.ts`

### 3. Refatoração do Método receiveNotification

**Decision**: Implementar tracking automático de evento quando notificação é recebida, usando iOS como referência

**iOS Implementation (Referência)**:
```swift
nonisolated public static func notificationRead(
  userInfo: [AnyHashable: Any],
  token: String
) {
  DispatchQueue.main.async {
    let dtTrack = DitoTrack()
    let notificationReceived = DitoNotificationReceived(with: userInfo)
    let dtIdentify = DitoIdentify()

    // Ensure we have a valid userId for identification
    dtIdentify.identify(
      id: notificationReceived.userId,
      data: DitoUser()
    )
    dtTrack.track(
      data: DitoEvent(
        action: "receive-ios-notification",
        customData: [
          "canal": "mobile",
          "token": token,
          "id-disparo": notificationReceived.logId,
          "id-notificacao": notificationReceived.notification,
          "nome_notificacao": notificationReceived.notificationName,
          "provedor": "firebase",
          "sistema_operacional": "Apple iPhone",
        ]
      )
    )
  }
}
```

**Android Implementation (A Replicar)**:
- Atualmente `notificationRead` apenas registra a leitura da notificação
- Precisa adicionar tracking automático similar ao iOS
- Dados a incluir no evento:
  - action: "receive-android-notification"
  - canal: "mobile"
  - token: FCM token
  - id-disparo: logId da notificação
  - id-notificacao: notification ID
  - nome_notificacao: notification name
  - provedor: "firebase"
  - sistema_operacional: "Android"

**Rationale**:
- Tracking automático de recebimento de notificação é importante para analytics
- iOS já implementa isso corretamente
- Android precisa replicar o mesmo comportamento
- Dados devem ser consistentes entre plataformas

**Alternatives Considered**:
- Manter comportamento atual do Android: Rejeitado - falta tracking automático
- Implementar tracking apenas no iOS: Rejeitado - inconsistência entre plataformas

### 4. Consistência de Assinaturas

**Decision**: Manter assinaturas públicas consistentes entre plataformas

**Assinaturas Atuais**:

**identify**:
- iOS: `identify(id:name:email:customData:)`
- Android: `identify(id:name:email:customData:)`
- Flutter: `identify({required String id, String? name, String? email, Map<String, dynamic>? customData})`
- React Native: `identify({id: string, name?: string, email?: string, customData?: Record<string, any>})`

**Status**: ✅ Já consistente

**track**:
- iOS: `track(action:data:)`
- Android: `track(action:data:)`
- Flutter: `track({required String action, Map<String, dynamic>? data})`
- React Native: `track({action: string, data?: Record<string, any>})`

**Status**: ✅ Já consistente

**registerDeviceToken**:
- iOS: `registerDevice(token:)`
- Android: `registerDevice(token:)`
- Flutter: `registerDeviceToken(String token)`
- React Native: `registerDeviceToken(token: string)`

**Status**: ✅ Já consistente (pequena diferença de nomenclatura - registerDevice vs registerDeviceToken)

**unregisterDeviceToken**:
- iOS: `unregisterDevice(token:)`
- Android: `unregisterDevice(token:)`
- Flutter: Não implementado ainda
- React Native: Não implementado ainda

**Status**: ⚠️ Precisa implementar em Flutter e React Native

**clickNotification**:
- iOS: `notificationClick(userInfo:callback:)`
- Android: `notificationClick(userInfo:callback:)`
- Flutter: Implementado via métodos estáticos no plugin
- React Native: Implementado via métodos estáticos no módulo

**Status**: ✅ Já consistente

**receiveNotification**:
- iOS: `notificationRead(userInfo:token:)` - dispara track automaticamente
- Android: `notificationRead(userInfo:)` - não dispara track automaticamente
- Flutter: Implementado via métodos estáticos no plugin
- React Native: Implementado via métodos estáticos no módulo

**Status**: ⚠️ Android precisa adicionar tracking automático

### 5. Tratamento de Erros

**Decision**: Manter tratamento de erros existente, melhorando apenas mensagens e consistência

**Rationale**:
- Tratamento de erros já está implementado e funcionando
- Refatoração não deve alterar comportamento de erros
- Apenas melhorar legibilidade do código de tratamento de erros

### 6. Testes

**Decision**: Manter testes existentes, atualizar apenas se necessário durante refatoração

**Rationale**:
- Testes existentes validam comportamento correto
- Refatoração não deve alterar comportamento público
- Se testes quebrarem, indica que comportamento foi alterado incorretamente

**Alternatives Considered**:
- Reescrever todos os testes: Rejeitado - desnecessário se comportamento não muda
- Não atualizar testes: Escolhido - manter como estão

## Referências e Padrões

- [Swift Style Guide](https://swift.org/documentation/api-design-guidelines/)
- [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [TypeScript Style Guide](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)
- Arquivos de regras: `.cursor/rules/*.mdc`

# Guia de Migração - Padronização de Nomenclatura

**Data**: 2025-01-27
**Versão**: SDKs iOS e Android após refatoração de nomenclatura

## Visão Geral

Os SDKs iOS e Android foram refatorados para ter nomenclatura consistente entre plataformas. Métodos antigos foram marcados como deprecated mas continuam funcionando para manter compatibilidade.

## Mudanças Principais

### 1. Identificação de Usuário

#### iOS

**Antes (Deprecated)**:
```swift
let user = DitoUser(name: "João", email: "joao@example.com")
Dito.identify(id: userId, data: user)
```

**Agora (Recomendado)**:
```swift
Dito.identify(
    id: userId,
    name: "João",
    email: "joao@example.com",
    customData: ["tipo_cliente": "premium"]
)
```

#### Android

**Antes (Deprecated)**:
```kotlin
val identify = Identify("user123").apply {
    name = "João"
    email = "joao@example.com"
}
Dito.identify(identify) { /* callback */ }
```

**Agora (Recomendado)**:
```kotlin
Dito.identify(
    id = "user123",
    name = "João",
    email = "joao@example.com",
    customData = mapOf("tipo_cliente" to "premium")
)
```

### 2. Tracking de Eventos

#### iOS

**Antes (Deprecated)**:
```swift
let event = DitoEvent(action: "purchase", customData: ["product": "item123"])
Dito.track(event: event)
```

**Agora (Recomendado)**:
```swift
Dito.track(
    action: "purchase",
    data: ["product": "item123", "price": 99.99]
)
```

#### Android

**Antes (Deprecated)**:
```kotlin
val event = Event("purchase", revenue = 99.99)
event.data = CustomData().apply {
    add("product", "item123")
}
Dito.track(event)
```

**Agora (Recomendado)**:
```kotlin
Dito.track(
    action = "purchase",
    data = mapOf("product" to "item123", "price" to 99.99)
)
```

### 3. Leitura de Notificações

#### iOS

**Antes (Deprecated)**:
```swift
Dito.notificationRead(with: userInfo, token: fcmToken)
```

**Agora (Recomendado)**:
```swift
Dito.notificationRead(userInfo: userInfo, token: fcmToken)
```

#### Android

**Antes (Deprecated)**:
```kotlin
Dito.notificationRead("notif123", "user123")
```

**Agora (Recomendado)**:
```kotlin
val userInfo = mapOf(
    "notification" to "notif123",
    "reference" to "user123"
)
Dito.notificationRead(userInfo)
```

### 4. Clique em Notificações

#### iOS

**Antes (Deprecated)**:
```swift
Dito.notificationClick(with: userInfo) { deeplink in
    // processar deeplink
}
```

**Agora (Recomendado)**:
```swift
Dito.notificationClick(userInfo: userInfo) { deeplink in
    // processar deeplink
}
```

#### Android

**Novo (Não existia antes)**:
```kotlin
val notificationInfo = mapOf(
    "notification" to "notif123",
    "reference" to "user123",
    "deeplink" to "https://app.example.com/product/123"
)
val result = Dito.notificationClick(notificationInfo) { deeplink ->
    // processar deeplink
}
```

## Estratégia de Migração

### Fase 1: Atualizar Gradualmente (Recomendado)

1. **Mantenha código antigo funcionando**: Métodos deprecated continuam funcionando
2. **Atualize código novo**: Use novos métodos em código novo
3. **Refatore gradualmente**: Atualize código existente quando fizer sentido

### Fase 2: Remover Deprecations (Futuro)

Após período de transição (2+ versões major):
1. Métodos deprecated serão removidos
2. Atualize todo código para usar novos métodos
3. Teste completamente antes de atualizar

## Checklist de Migração

### iOS

- [ ] Substituir `Dito.identify(id:data:)` por `Dito.identify(id:name:email:customData:)`
- [ ] Substituir `Dito.track(event:)` por `Dito.track(action:data:)`
- [ ] Substituir `Dito.notificationRead(with:token:)` por `Dito.notificationRead(userInfo:token:)`
- [ ] Substituir `Dito.notificationClick(with:callback:)` por `Dito.notificationClick(userInfo:callback:)`
- [ ] Testar todas as funcionalidades após migração

### Android

- [ ] Substituir `Dito.identify(identify, callback)` por `Dito.identify(id, name, email, customData)`
- [ ] Substituir `Dito.track(event)` por `Dito.track(action, data)`
- [ ] Substituir `Dito.notificationRead(notification, reference)` por `Dito.notificationRead(userInfo)`
- [ ] Adicionar `Dito.notificationClick(userInfo, callback)` onde necessário
- [ ] Testar todas as funcionalidades após migração

## Benefícios da Migração

1. **Consistência**: Mesmas assinaturas entre iOS e Android
2. **Simplicidade**: Parâmetros diretos em vez de objetos complexos
3. **Manutenibilidade**: Código mais fácil de entender e manter
4. **Compatibilidade**: Wrappers Flutter e React Native podem usar APIs unificadas

## Suporte

Se encontrar problemas durante a migração:

1. Consulte `docs/nomenclature-analysis-ios.md` e `docs/nomenclature-analysis-android.md` para detalhes das APIs
2. Consulte `docs/nomenclature-mapping.md` para mapeamento completo
3. Abra uma issue no repositório do monorepo

## Notas Importantes

- ⚠️ Métodos deprecated continuam funcionando mas podem ser removidos em versões futuras
- ✅ Novos métodos são recomendados para código novo
- 🔄 Migração pode ser feita gradualmente sem quebrar código existente
- 📚 Documentação completa disponível em `docs/`

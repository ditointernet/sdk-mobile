# Android SDK — Migration Guide

## DitoNotificationOptions — migrando de `Options.iconNotification`

### Contexto

O campo `Options.iconNotification` foi **depreciado** em favor da nova API `DitoNotificationOptions`, que centraliza todas as opções visuais de notificação e possui precedência explícita sobre o campo legado.

### Antes (depreciado)

```kotlin
val options = Options(retry = 3).apply {
    iconNotification = R.drawable.ic_notification
}
Dito.initialize(context, apiKey, sha256Key, options)
```

### Depois (recomendado)

```kotlin
val options = Options(retry = 3)
Dito.initialize(context, apiKey, sha256Key, options)

Dito.setNotificationOptions(
    DitoNotificationOptions(smallIconResId = R.drawable.ic_notification)
)
```

### Regra de prioridade

Quando `DitoNotificationOptions.smallIconResId` está definido, ele **sempre** tem precedência sobre `Options.iconNotification`. O campo legado só é usado como fallback quando `DitoNotificationOptions` não foi configurado.

### Por que migrar?

- `Options.iconNotification` será removido em uma versão futura.
- `DitoNotificationOptions` permite customizar ícone grande, cor de acento e outros atributos visuais em um único lugar.
- A nova API pode ser chamada a qualquer momento após `initialize`, sem precisar reinicializar o SDK.

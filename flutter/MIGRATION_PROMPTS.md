# Prompts de Migração - Dito SDK Flutter 3.0.0+

Este arquivo contém prompts prontos para usar no Cursor AI para automatizar a migração da SDK antiga para a versão 3.0.0+.

## 📋 Como Usar Este Arquivo

1. Abra seu projeto Flutter no Cursor
2. Copie e cole cada prompt na ordem apresentada
3. Revise as mudanças sugeridas pelo Cursor
4. Execute os testes após cada etapa crítica
5. Marque cada etapa como concluída usando o checkbox

---

## ✅ Checklist de Progresso

- [ ] Etapa 1: Atualização de Dependências
- [ ] Etapa 2: Migração da Inicialização
- [ ] Etapa 3: Migração de Identificação
- [ ] Etapa 4: Migração de Eventos
- [ ] Etapa 5: Migração de Push Tokens
- [ ] Etapa 6: Remoção de Métodos Descontinuados
- [ ] Etapa 7: Configuração Android
- [ ] Etapa 8: Limpeza iOS
- [ ] Etapa 9: Validação Final

---

## 🚀 Etapa 1: Atualização de Dependências

### Prompt para o Cursor:

```
Atualize o arquivo pubspec.yaml:

1. Altere a dependência do dito_sdk para a versão ^3.0.0
2. Verifique se firebase_core e firebase_messaging estão presentes (mínimo ^14.0.0)
3. Adicione crypto: ^3.0.0 se não estiver presente (necessário para sha1)

Após fazer as alterações, me mostre o diff do que foi modificado.
```

**Após executar**: Rode `flutter pub get` no terminal

---

## 🔧 Etapa 2: Migração da Inicialização do SDK

### Prompt para o Cursor:

```
Encontre todas as chamadas de inicialização do Dito SDK no projeto e faça as seguintes alterações:

1. Localize todas as instâncias de `DitoSDK()` e mude para `DitoSdk()` (minúsculo no "dk")
2. Encontre todas as chamadas de `initialize()` e altere:
   - Parâmetro `apiKey` para `appKey`
   - Parâmetro `secretKey` para `appSecret`
3. Adicione `await` antes de `initialize()` se não estiver presente
4. Envolva a chamada em try-catch com PlatformException se não estiver
5. Remova TODAS as chamadas de `initializePushService()` ou `initializePushNotificationService()` - esse método não existe mais

Exemplo do resultado esperado:
```dart
final ditoSdk = DitoSdk();
try {
  await ditoSdk.initialize(
    appKey: 'sua-api-key',
    appSecret: 'seu-api-secret',
  );
  print('SDK inicializado com sucesso');
} on PlatformException catch (e) {
  print('Erro ao inicializar: ${e.message}');
}
```

Me mostre todos os arquivos que foram modificados e o que foi alterado.
```

---

## 👤 Etapa 3: Migração de Identificação de Usuários

### Prompt para o Cursor:

```
Migre TODAS as chamadas de identificação de usuários no projeto:

1. Encontre todas as instâncias da classe `User` e remova-as (essa classe não existe mais)
2. Localize todas as chamadas de `identify()` e altere para usar parâmetros nomeados:
   - Primeiro parâmetro vira `id:`
   - Segundo parâmetro vira `name:`
   - Terceiro parâmetro vira `email:`
   - Parâmetros `location`, `gender`, `birthday` devem ser movidos para `customData`
3. Remova TODAS as chamadas de `identifyUser()` - esse método não existe mais
   - O método `identify()` já envia os dados automaticamente
4. Garanta que `identify()` seja chamado com `await`
5. Adicione try-catch se não houver

Transforme código como este:
```dart
// ANTES
dito.identify(userId, name, email, location, gender, birthday, customData);
await dito.identifyUser();
```

Em código como este:
```dart
// DEPOIS
await ditoSdk.identify(
  id: userId,
  name: name,
  email: email,
  customData: {
    'location': location,
    'gender': gender,
    'birthday': birthday,
    ...?customData,
  },
);
```

Me mostre todos os arquivos modificados com antes/depois.
```

---

## 📊 Etapa 4: Migração de Rastreamento de Eventos

### Prompt para o Cursor:

```
Migre TODAS as chamadas de rastreamento de eventos:

1. Encontre todas as chamadas de `trackEvent()` e renomeie para `track()`
2. Altere os parâmetros:
   - `eventName` → `action`
   - `customData` → `data`
   - Se houver `revenue`, mova para dentro do objeto `data`
3. Garanta que todas as chamadas tenham `await`
4. Adicione try-catch se não houver

Transforme código como este:
```dart
// ANTES
await dito.trackEvent(
  eventName: 'comprou_produto',
  revenue: 99.90,
  customData: {'produto': 'X', 'sku': '123'}
);
```

Em código como este:
```dart
// DEPOIS
await ditoSdk.track(
  action: 'comprou_produto',
  data: {
    'produto': 'X',
    'sku': '123',
    'revenue': 99.90,
  },
);
```

Liste todos os arquivos modificados e o número de eventos migrados.
```

---

## 🔔 Etapa 5: Migração de Push Tokens

### Prompt para o Cursor:

```
Migre TODAS as chamadas relacionadas a tokens de push:

1. Encontre `registryMobileToken()` e renomeie para `registerDeviceToken()`
2. Encontre `removeMobileToken()` e renomeie para `unregisterDeviceToken()`
3. Remova o parâmetro `platform` de ambos os métodos (é detectado automaticamente)
4. Os métodos agora recebem apenas o token como parâmetro String
5. Garanta que ambos sejam chamados com `await`

Transforme código como este:
```dart
// ANTES
await dito.registryMobileToken(token: fcmToken, platform: 'Android');
await dito.removeMobileToken(token: fcmToken, platform: 'iPhone');
```

Em código como este:
```dart
// DEPOIS
await ditoSdk.registerDeviceToken(fcmToken);
await ditoSdk.unregisterDeviceToken(fcmToken);
```

Me mostre os arquivos modificados.
```

---

## 🗑️ Etapa 6: Remoção de Métodos e Classes Descontinuados

### Prompt para o Cursor:

```
Remova TODOS os usos de funcionalidades descontinuadas:

1. Remova todas as importações e usos de:
   - Classe `User`
   - Classe `DataPayload`
   - Classe `CustomNotification`
   - `notificationService()`
   - `openNotification()`

2. Se houver código de notificações locais usando `notificationService().showLocalNotification()`:
   - Comente esse código
   - Adicione um comentário: "// TODO: Implementar notificações locais usando Firebase Messaging diretamente"

3. Se houver handlers de `_firebaseMessagingBackgroundHandler` que usam `DataPayload`:
   - Remova o parse de DataPayload
   - Mantenha apenas a estrutura básica do handler
   - Adicione comentário explicativo

4. Remova completamente chamadas de `openNotification()` - esse rastreamento não existe mais

Me mostre uma lista de:
- Arquivos modificados
- Linhas removidas
- TODOs adicionados
```

---

## 📱 Etapa 7: Configuração Nativa Android

### Prompt para o Cursor:

```
Configure o Android para a nova SDK:

1. Verifique se existe um arquivo de serviço Firebase customizado em:
   android/app/src/main/kotlin/<package>/

2. Se NÃO existir, crie um arquivo chamado `CustomMessagingService.kt` com este conteúdo:

```kotlin
package <SUBSTITUA_PELO_PACKAGE>

import br.com.dito.ditosdk.DitoMessagingServiceHelper
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CustomMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val handled = DitoMessagingServiceHelper.handleMessage(
            applicationContext,
            remoteMessage
        )
        if (!handled) {
            super.onMessageReceived(remoteMessage)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        DitoMessagingServiceHelper.handleNewToken(applicationContext, token)
    }
}
```

3. Abra o AndroidManifest.xml e verifique se o service está registrado:
   - Se não estiver, adicione dentro de <application>:

```xml
<service
    android:name=".CustomMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

Substitua <SUBSTITUA_PELO_PACKAGE> pelo package correto do projeto.

Me confirme:
- O package encontrado
- Se o arquivo foi criado ou já existia
- Se o AndroidManifest foi modificado
```

---

## 🍎 Etapa 8: Limpeza de Configuração iOS

### Prompt para o Cursor:

```
Limpe a configuração iOS que não é mais necessária:

1. Abra o arquivo ios/Runner/AppDelegate.swift
2. Procure por código de configuração manual do Firebase Messaging
3. Se houver código como:
   - `FirebaseApp.configure()`
   - Implementações de `UNUserNotificationCenterDelegate`
   - Código de registro manual de push

4. REMOVA esse código - o plugin agora configura automaticamente

5. O AppDelegate deve ficar simples, similar a:
```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Me mostre:
- O conteúdo do AppDelegate antes e depois
- Linhas removidas
- Se algum arquivo adicional foi identificado para limpeza
```

---

## ✅ Etapa 9: Validação Final

### Prompt para o Cursor:

```
Faça uma revisão completa do projeto para validar a migração:

1. Busque no projeto por:
   - "DitoSDK" (maiúsculo) - deve ser "DitoSdk" (minúsculo no dk)
   - "apiKey:" ou "secretKey:" em chamadas initialize
   - "identifyUser()" - não deve existir mais
   - "trackEvent(" - deve ser "track("
   - "registryMobileToken" ou "removeMobileToken"
   - "initializePushService" ou "initializePushNotificationService"
   - "openNotification("
   - "notificationService("
   - Classes: User, DataPayload, CustomNotification

2. Verifique se todas as chamadas assíncronas do SDK têm:
   - `await` antes da chamada
   - Try-catch apropriado

3. Gere um relatório com:
   - Total de arquivos modificados
   - Número de ocorrências de cada mudança
   - Lista de possíveis problemas encontrados
   - Lista de TODOs adicionados que precisam de atenção manual

4. Me forneça um resumo executivo da migração.
```

---

## 🧪 Testes Manuais Recomendados

Após executar todos os prompts, teste manualmente:

### Teste 1: Inicialização
```
1. Execute o app
2. Verifique nos logs se "SDK inicializado com sucesso" aparece
3. Verifique se não há erros de inicialização
```

### Teste 2: Identificação
```
1. Execute a função de identificação de usuário
2. Verifique no painel Dito se o usuário aparece
3. Confirme que customData está correto
```

### Teste 3: Eventos
```
1. Execute uma ação que dispara um evento
2. Verifique no painel Dito se o evento aparece
3. Confirme que os dados do evento estão corretos
```

### Teste 4: Push Notifications
```
1. Registre o token de push
2. Envie uma notificação de teste do painel Dito
3. Verifique se a notificação chega no Android
4. Verifique se a notificação chega no iOS
5. Teste abertura da notificação
```

---

## 🐛 Prompt de Troubleshooting

Se algo não funcionar, use este prompt:

```
Analise o seguinte erro que estou recebendo após a migração do Dito SDK:

[COLE O ERRO AQUI]

Contexto:
- Migrei da versão antiga do Dito SDK para 3.0.0+
- Já executei os seguintes passos: [LISTE OS PASSOS CONCLUÍDOS]
- O erro acontece quando: [DESCREVA O CENÁRIO]

Por favor:
1. Identifique a causa raiz do problema
2. Verifique se é relacionado à migração ou outra coisa
3. Forneça a solução específica com código
4. Me diga se preciso reverter alguma mudança
```

---

## 📊 Prompt para Gerar Relatório de Migração

Após concluir todas as etapas, gere um relatório:

```
Gere um relatório completo da migração do Dito SDK com:

1. Estatísticas:
   - Total de arquivos modificados
   - Total de linhas adicionadas/removidas
   - Número de cada tipo de mudança (initialize, identify, track, etc)

2. Arquivos Críticos Modificados:
   - Liste os 10 arquivos mais impactados
   - Descreva brevemente o que foi mudado em cada um

3. Breaking Changes Aplicados:
   - Liste todas as breaking changes da migração
   - Para cada uma, mostre exemplo antes/depois

4. Pendências:
   - Liste TODOs adicionados que precisam atenção manual
   - Identifique configurações nativas que precisam validação

5. Checklist de Testes:
   - Gere uma lista de cenários que devem ser testados
   - Organize por prioridade

Formate o relatório em Markdown para fácil compartilhamento.
```

---

## 🎯 Prompt de Otimização (Opcional)

Se quiser otimizar o código após a migração:

```
Agora que a migração está completa, analise o código e sugira otimizações:

1. Identifique código duplicado relacionado ao Dito SDK que pode ser centralizado
2. Sugira padrões de uso (ex: criar uma classe DitoService wrapper)
3. Identifique oportunidades de melhoria no tratamento de erros
4. Sugira melhorias na estrutura de customData e eventos
5. Verifique se há oportunidades para usar async/await de forma mais eficiente

Para cada sugestão:
- Explique o benefício
- Mostre exemplo de código
- Indique se é opcional ou recomendado
```

---

## 📝 Notas Importantes

### Ordem de Execução
- ⚠️ Execute os prompts NA ORDEM apresentada
- ⚠️ Não pule etapas, mesmo que pareçam não aplicáveis
- ⚠️ Revise cada mudança antes de aceitar

### Backup
- 💾 Faça commit do código antes de iniciar
- 💾 Considere criar uma branch específica para migração

### Revisão
- 👀 Sempre revise as mudanças sugeridas pelo Cursor
- 👀 O AI pode não entender 100% do contexto do seu app
- 👀 Ajuste conforme necessário para seu caso específico

### Testes
- 🧪 Execute `flutter analyze` após cada etapa crítica
- 🧪 Rode os testes automatizados se você tiver
- 🧪 Teste manualmente funcionalidades críticas

---

## 🆘 Suporte

Se os prompts não funcionarem como esperado:

1. 📚 Consulte o [MIGRATION.md](./MIGRATION.md) para detalhes técnicos
2. 📖 Veja o [README.md](./README.md) da nova SDK
3. 👀 Analise o [código de exemplo](./sample_application)
4. 🌐 Acesse [developers.dito.com.br](https://developers.dito.com.br)

---

**Versão**: 1.0.0
**Compatível com**: Dito SDK Flutter 3.0.0+
**Última atualização**: Janeiro 2024

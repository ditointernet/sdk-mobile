# Dito SDK Example App

Aplicativo de exemplo para testar o Dito SDK no Android.

## Configuração

### 1. Criar arquivo .env.development.local

Crie o arquivo `src/main/assets/.env.development.local` com o seguinte conteúdo:

```
API_KEY=your-api-key-here
API_SECRET=your-api-secret-here

IDENTIFY_ID=user123
IDENTIFY_NAME=John Doe
IDENTIFY_EMAIL=john.doe@example.com
IDENTIFY_CUSTOM_DATA={"age": 30, "city": "São Paulo"}

TRACK_ACTION=purchase
TRACK_DATA={"product_id": "123", "price": 99.99}

REGISTER_TOKEN=your-device-token-here
UNREGISTER_TOKEN=your-device-token-here
```

**Importante**: Substitua `your-api-key-here` e `your-api-secret-here` pelas suas credenciais reais do Dito SDK.

### 2. Build e Execução

#### Opção A: Via Android Studio

1. Abra o Android Studio
2. Selecione **File > Open** e navegue até o diretório `android/`
3. Aguarde o Gradle sincronizar o projeto
4. Selecione o módulo `example-app` no dropdown de configurações de execução
5. Clique em **Run** (ou pressione Shift+F10)

**Nota**: Se o módulo `example-app` não aparecer nas configurações:
- Vá em **File > Project Structure**
- Verifique se o módulo `example-app` está listado
- Se não estiver, clique em **+** e adicione o módulo manualmente

#### Opção B: Via Linha de Comando

```bash
cd android
./gradlew :example-app:assembleDebug
./gradlew :example-app:installDebug
```

#### Opção C: Script Automatizado

Use o script fornecido para facilitar a execução:

```bash
cd android/example-app
./run_emulator.sh
```

Este script:
- Verifica se há um emulador rodando
- Faz o build do APK
- Instala no emulador
- Inicia o aplicativo

## Funcionalidades

O aplicativo permite testar os seguintes métodos do Dito SDK:

1. **Identify**: Identificar usuário com id, name, email e customData
2. **Track**: Rastrear eventos com action e data
3. **RegisterDevice**: Registrar token de dispositivo
4. **UnregisterDevice**: Desregistrar token de dispositivo

Todos os campos são pré-preenchidos com valores do arquivo `.env.development.local` e podem ser editados antes de testar.

## Firebase Cloud Messaging (FCM)

O aplicativo inclui suporte completo para Firebase Cloud Messaging:

### Configuração

1. O arquivo `google-services.json` já está configurado no projeto
2. O Firebase é inicializado automaticamente na `DitoExampleApplication`
3. O `DitoMessagingService` do SDK processa notificações recebidas automaticamente

### Funcionalidades FCM

- **Obter Token FCM**: Botão na interface para obter e exibir o token FCM
- **Registro Automático**: Token FCM é automaticamente registrado no Dito SDK quando obtido
- **Processamento de Notificações**: Notificações recebidas são processadas e integradas com o Dito SDK
- **Exibição de Notificações**: Notificações são exibidas no sistema quando recebidas

### Como Usar

1. Execute o aplicativo
2. Clique em "Obter Token FCM" para obter o token do dispositivo
3. O token será automaticamente preenchido no campo "Register Token"
4. Use o token para enviar notificações push via Firebase Console ou API do Dito

### Estrutura de Notificações

As notificações devem seguir o formato esperado pelo Dito SDK:

```json
{
  "data": {
    "notification": "notification_id",
    "reference": "user_reference",
    "log_id": "log_id",
    "user_id": "user_id",
    "details": {
      "title": "Título da Notificação",
      "message": "Mensagem da Notificação",
      "link": "deeplink://app/path",
      "notification_name": "Nome da Notificação"
    }
  }
}
```

## Estrutura

- `DitoExampleApplication`: Classe Application que inicializa Firebase e Dito SDK
- `MainActivity`: Activity principal com interface para testar o SDK e obter token FCM
- `DitoMessagingService` (do SDK): Serviço que processa notificações FCM automaticamente
- `EnvLoader`: Utilitário para carregar variáveis do arquivo .env

### Serviço de Mensagens

O app usa o `DitoMessagingService` fornecido pelo SDK, que:
- Processa notificações push automaticamente
- Registra o token FCM no Dito
- Chama `Dito.notificationRead()` quando notificações são recebidas
- Exibe notificações no sistema
- Gerencia deep links automaticamente

Para usar em seu app, adicione no `AndroidManifest.xml`:

```xml
<service
    android:name="br.com.dito.ditosdk.notification.DitoMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

## Troubleshooting

### Arquivo .env não está sendo carregado

Se você ver o warning `Could not load .env.development.local` nos logs, significa que o arquivo não está incluído no APK instalado.

**Solução**: Faça um rebuild completo do app:

```bash
# Via Android Studio
Build > Clean Project
Build > Rebuild Project

# Via linha de comando
cd android
./gradlew :example-app:clean
./gradlew :example-app:assembleDebug
./gradlew :example-app:installDebug
```

Para mais detalhes sobre problemas comuns, consulte `TROUBLESHOOTING.md`.

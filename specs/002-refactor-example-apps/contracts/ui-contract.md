# UI Contract: Aplicações de Exemplo

**Feature**: 002-refactor-example-apps
**Date**: 2025-01-27

## Visão Geral

Este contrato define a estrutura e comportamento da interface das aplicações de exemplo em todas as plataformas (iOS, Android, Flutter, React Native).

## Estrutura da Tela

### Seção 1: Status do SDK

**Elementos**:
- Label: "Status"
- Valor: "Not Initialized" | "Initialized" | "User Identified" | "Error: [mensagem]"
- Label: "Initialized"
- Valor: "Yes" | "No"

### Seção 2: Configuração do SDK

**Campos**:
1. **API Key** (TextField)
   - Label: "API Key"
   - Placeholder: "your-api-key"
   - Obrigatório: Sim
   - Tipo: Text (secure: false)
   - Valor padrão: Do `.env.development.local`

2. **API Secret** (TextField)
   - Label: "API Secret"
   - Placeholder: "your-api-secret"
   - Obrigatório: Sim
   - Tipo: Text (secure: true - password)
   - Valor padrão: Do `.env.development.local`

3. **Botão: Initialize**
   - Label: "Initialize"
   - Ação: Chama `DitoSdk.initialize(apiKey, apiSecret)`
   - Feedback: Snackbar/Alert com sucesso ou erro

### Seção 3: Dados do Usuário

**Campos**:
1. **User ID** (TextField)
   - Label: "User ID"
   - Placeholder: "user123"
   - Obrigatório: Sim
   - Valor padrão: Do `.env.development.local`

2. **User Name** (TextField)
   - Label: "Name"
   - Placeholder: "John Doe"
   - Obrigatório: Não
   - Valor padrão: Do `.env.development.local`

3. **User Email** (TextField)
   - Label: "Email"
   - Placeholder: "john@example.com"
   - Obrigatório: Sim
   - Tipo: Email keyboard
   - Validação: Formato de email válido
   - Valor padrão: Do `.env.development.local`

4. **User Phone** (TextField)
   - Label: "Phone"
   - Placeholder: "+5511999999999"
   - Obrigatório: Não
   - Tipo: Phone keyboard
   - Valor padrão: Do `.env.development.local`

5. **User Address** (TextField)
   - Label: "Address"
   - Placeholder: "123 Main St"
   - Obrigatório: Não
   - Valor padrão: Do `.env.development.local`

6. **User City** (TextField)
   - Label: "City"
   - Placeholder: "São Paulo"
   - Obrigatório: Não
   - Valor padrão: Do `.env.development.local`

7. **User State** (TextField)
   - Label: "State"
   - Placeholder: "SP"
   - Obrigatório: Não
   - Valor padrão: Do `.env.development.local`

8. **User ZIP** (TextField)
   - Label: "ZIP"
   - Placeholder: "01234-567"
   - Obrigatório: Não
   - Tipo: Numeric keyboard
   - Valor padrão: Do `.env.development.local`

9. **User Country** (TextField)
   - Label: "Country"
   - Placeholder: "Brazil"
   - Obrigatório: Não
   - Valor padrão: Do `.env.development.local`

10. **Botão: Identify User**
    - Label: "Identify User"
    - Ação: Chama `DitoSdk.identify()` com todos os campos preenchidos
    - Validação: Verifica campos obrigatórios antes de chamar
    - Feedback: Snackbar/Alert com sucesso ou erro

### Seção 4: Rastreamento de Eventos

**Campos**:
1. **Event Name** (TextField)
   - Label: "Event Name"
   - Placeholder: "purchase"
   - Obrigatório: Sim
   - Valor padrão: "purchase"

2. **Botão: Track Event**
   - Label: "Track Event"
   - Ação: Chama `DitoSdk.track(action: eventName, data: {...})`
   - Validação: Verifica se eventName não está vazio
   - Feedback: Snackbar/Alert com sucesso ou erro

### Seção 5: Tokens de Dispositivo

**Campos**:
1. **Device Token** (TextField)
   - Label: "FCM Device Token"
   - Placeholder: "fcm-device-token"
   - Obrigatório: Sim
   - Valor padrão: Do `.env.development.local` ou valor mock

2. **Botão: Register Token**
   - Label: "Register Token"
   - Ação: Chama `DitoSdk.registerDeviceToken(token)`
   - Validação: Verifica se token não está vazio
   - Feedback: Snackbar/Alert com sucesso ou erro

3. **Botão: Unregister Token**
   - Label: "Unregister Token"
   - Ação: Chama `DitoSdk.unregisterDeviceToken(token)` (se disponível)
   - Validação: Verifica se token não está vazio
   - Feedback: Snackbar/Alert com sucesso ou erro

## Comportamento Consistente

### Validação de Campos

**Regras**:
1. Campos obrigatórios devem ser validados antes de ações
2. Email deve ter formato válido (se fornecido)
3. Mensagens de erro devem ser claras e consistentes
4. Validação deve ocorrer em tempo real ou ao tentar ação

### Feedback ao Usuário

**Sucesso**:
- Mensagem: "Operation completed successfully"
- Tipo: Snackbar (Android/Flutter) ou Alert (iOS/React Native)
- Duração: 2-3 segundos

**Erro**:
- Mensagem: Mensagem de erro do SDK ou validação
- Tipo: Snackbar/Alert com estilo de erro
- Duração: Até usuário fechar ou 5 segundos

### Estados de Botões

**Habilitado**: Quando SDK está inicializado e campos obrigatórios estão preenchidos
**Desabilitado**: Quando SDK não está inicializado ou campos obrigatórios estão vazios

### Carregamento de Valores do .env

**Comportamento**:
1. Ao iniciar aplicação, carregar `.env.development.local`
2. Preencher campos com valores do arquivo
3. Se arquivo não existir, usar valores padrão vazios
4. Se arquivo existir mas campo não estiver presente, usar valor padrão vazio

## Layout Responsivo

### iOS
- Usar Auto Layout ou SwiftUI Layout
- ScrollView para conteúdo que não cabe na tela
- Espaçamento consistente entre elementos

### Android
- Usar ConstraintLayout ou Jetpack Compose
- ScrollView/NestedScrollView para conteúdo longo
- Material Design spacing guidelines

### Flutter
- Usar Column/ListView com SingleChildScrollView
- Padding e spacing consistentes
- Material Design ou Cupertino widgets

### React Native
- Usar ScrollView para conteúdo longo
- StyleSheet com valores consistentes
- Flexbox layout

## Acessibilidade

- Labels descritivos para todos os campos
- Placeholders informativos
- Mensagens de erro acessíveis
- Navegação por teclado (Android/Desktop)

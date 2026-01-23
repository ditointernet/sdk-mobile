# Data Model: Aplicações de Exemplo

**Feature**: 002-refactor-example-apps
**Date**: 2025-01-27

## Entidades

### Configuration (Configuração do SDK)

**Campos Obrigatórios**:
- `apiKey` (String): Chave da API Dito
- `apiSecret` (String): Secret da API Dito

**Validação**:
- Não podem ser vazios
- Devem ser carregados do arquivo `.env.development.local`

### UserData (Dados do Usuário)

**Campos Obrigatórios**:
- `userId` (String): ID único do usuário
- `userEmail` (String): Email do usuário

**Campos Opcionais**:
- `userName` (String?): Nome do usuário
- `userPhone` (String?): Telefone do usuário
- `userAddress` (String?): Endereço do usuário
- `userCity` (String?): Cidade do usuário
- `userState` (String?): Estado do usuário
- `userZip` (String?): CEP do usuário
- `userCountry` (String?): País do usuário

**Validação**:
- `userId`: Não pode ser vazio
- `userEmail`: Formato de email válido (se fornecido)
- `userPhone`: Formato de telefone válido (se fornecido, opcional)

### EventData (Dados do Evento)

**Campos Obrigatórios**:
- `eventName` (String): Nome do evento a ser rastreado

**Campos Opcionais**:
- `eventData` (Map<String, Any>?): Dados adicionais do evento

**Validação**:
- `eventName`: Não pode ser vazio

### DeviceToken (Token de Dispositivo)

**Campos Obrigatórios**:
- `token` (String): Token FCM do dispositivo

**Validação**:
- `token`: Não pode ser vazio

## Relacionamentos

- **Configuration** → **UserData**: Configuração é necessária antes de identificar usuário
- **Configuration** → **EventData**: Configuração é necessária antes de rastrear eventos
- **Configuration** → **DeviceToken**: Configuração é necessária antes de registrar/desregistrar tokens
- **UserData** → **EventData**: Usuário deve ser identificado antes de rastrear eventos (opcional, mas recomendado)

## Estado da Aplicação

### Estados Possíveis

1. **Not Initialized**: SDK não foi inicializado
2. **Initialized**: SDK foi inicializado com sucesso
3. **User Identified**: Usuário foi identificado
4. **Error**: Erro ocorreu (deve incluir mensagem)

### Transições de Estado

```
Not Initialized → Initialized (via initialize)
Initialized → User Identified (via identify)
Initialized → Error (se initialize falhar)
User Identified → Error (se identify falhar)
Any State → Error (se operação falhar)
```

## Estrutura do Arquivo .env.development.local

```env
# Dito SDK Configuration
API_KEY=your-api-key-here
API_SECRET=your-api-secret-here

# User Defaults
USER_ID=user123
USER_NAME=John Doe
USER_EMAIL=john@example.com
USER_PHONE=+5511999999999
USER_ADDRESS=123 Main St
USER_CITY=São Paulo
USER_STATE=SP
USER_ZIP=01234-567
USER_COUNTRY=Brazil
```

## Validações por Campo

### API Key
- Tipo: String
- Obrigatório: Sim
- Validação: Não vazio, trim aplicado

### API Secret
- Tipo: String
- Obrigatório: Sim
- Validação: Não vazio, trim aplicado

### User ID
- Tipo: String
- Obrigatório: Sim
- Validação: Não vazio, trim aplicado

### User Email
- Tipo: String
- Obrigatório: Sim
- Validação: Formato de email válido (regex: `^[^\s@]+@[^\s@]+\.[^\s@]+$`)

### User Phone
- Tipo: String
- Obrigatório: Não
- Validação: Formato de telefone válido (opcional, se fornecido)

### User Address, City, State, ZIP, Country
- Tipo: String
- Obrigatório: Não
- Validação: Nenhuma (campos livres)

### Event Name
- Tipo: String
- Obrigatório: Sim
- Validação: Não vazio, trim aplicado

### Device Token
- Tipo: String
- Obrigatório: Sim
- Validação: Não vazio, trim aplicado

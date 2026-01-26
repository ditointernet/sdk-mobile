#!/bin/bash

# Script auxiliar para enviar notificações de teste
# Uso: ./test_notification.sh <FCM_TOKEN>

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BINARY="$SCRIPT_DIR/send_test_notification"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se o token foi fornecido
if [ -z "$1" ]; then
    echo -e "${RED}❌ Erro: Token FCM não fornecido${NC}"
    echo ""
    echo "Uso: $0 <FCM_TOKEN> [options]"
    echo ""
    echo "Exemplos:"
    echo "  $0 'seu_token_fcm_aqui'"
    echo "  $0 'seu_token_fcm_aqui' -title 'Teste' -message 'Mensagem'"
    echo ""
    exit 1
fi

FCM_TOKEN="$1"
shift

# Verificar se o binário existe, caso contrário compilar
if [ ! -f "$BINARY" ]; then
    echo -e "${YELLOW}⚠️  Binário não encontrado, compilando...${NC}"

    # Verificar se Go está instalado
    if ! command -v go &> /dev/null; then
        echo -e "${RED}❌ Erro: Go não está instalado${NC}"
        echo ""
        echo "Instale Go em: https://golang.org/dl/"
        exit 1
    fi

    cd "$SCRIPT_DIR"
    go mod download
    go build -o send_test_notification send_test_notification.go
    echo -e "${GREEN}✅ Compilação concluída${NC}"
fi

# Verificar se GOOGLE_APPLICATION_CREDENTIALS está definido
if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo -e "${RED}❌ Erro: GOOGLE_APPLICATION_CREDENTIALS não está definido${NC}"
    echo ""
    echo "Configure a variável de ambiente:"
    echo "  export GOOGLE_APPLICATION_CREDENTIALS='./serviceAccountKey.json'"
    echo ""
    echo "Ou adicione ao seu ~/.bashrc ou ~/.zshrc"
    echo "Ou use -credentials para especificar o arquivo"
    exit 1
fi

# Verificar se o arquivo de credenciais existe
if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo -e "${RED}❌ Erro: Arquivo de credenciais não encontrado${NC}"
    echo "  Arquivo: $GOOGLE_APPLICATION_CREDENTIALS"
    exit 1
fi

echo -e "${GREEN}✅ Enviando notificação do sample_notification.json...${NC}"
"$BINARY" -from-sample -token "$FCM_TOKEN" "$@"

#!/bin/bash
#
# Gera ios/Flutter/Dito.xcconfig com as credenciais que o Info.plist do Runner referencia
# como $(DITO_APP_KEY) e $(DITO_APP_SECRET).
#
# A fonte é `.env.development.local`, o **mesmo** arquivo que o Dart lê em
# lib/env_loader.dart. Ter uma fonte só é o ponto: se o nativo e o Dart autenticarem com
# chaves diferentes, o app aberto funciona e só o clique em processo novo falha, porque é
# ele que depende do Info.plist e não do que o Dart inicializou.
#
# O arquivo gerado não é versionado (ver .gitignore). O Info.plist versionado carrega só a
# referência ao build setting, nunca o valor.
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE="../.env.development.local"
OUT="Flutter/Dito.xcconfig"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE não existe. É a mesma fonte que o Dart usa; crie-o com API_KEY e API_SECRET." >&2
  exit 1
fi

read_env() {
  sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*(.*)$/\1/p" "$ENV_FILE" \
    | head -n 1 | tr -d '"'"'"' \r'
}

KEY="$(read_env API_KEY)"
SECRET="$(read_env API_SECRET)"

if [ -z "$KEY" ]; then
  echo "❌ API_KEY ausente ou vazia em $ENV_FILE" >&2
  exit 1
fi

# `//` inicia comentário em xcconfig e cortaria o valor pela metade, sem erro de build.
# Uma chave base64 pode conter `/`, então isto não é hipotético.
for pair in "API_KEY:$KEY" "API_SECRET:$SECRET"; do
  name="${pair%%:*}"
  value="${pair#*:}"
  case "$value" in
    *//*|*'$'*|*';'*)
      echo "❌ $name contém caractere que o xcconfig interpreta (// \$ ;). Este mecanismo não serve para esse valor." >&2
      exit 1
      ;;
  esac
done

cat > "$OUT" <<EOF
// Gerado por generate-dito-xcconfig.sh a partir de .env.development.local.
// Não versionar e não editar à mão.
DITO_APP_KEY=$KEY
DITO_APP_SECRET=$SECRET
EOF

echo "✅ $OUT gerado (key ${#KEY} chars, secret ${#SECRET} chars)"

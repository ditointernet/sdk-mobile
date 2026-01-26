#!/bin/bash

# Script para rodar o example-app no emulador Android

set -e

echo "🚀 Configurando e executando Example App no emulador..."

# Navegar para o diretório android
cd "$(dirname "$0")/.." || exit

# Verificar se há emuladores disponíveis
echo "📱 Verificando emuladores disponíveis..."
emulators=$(adb devices | grep "emulator" | wc -l)

if [ "$emulators" -eq 0 ]; then
    echo "⚠️  Nenhum emulador encontrado rodando."
    echo "💡 Inicie um emulador manualmente ou use:"
    echo "   emulator -avd <nome_do_avd>"
    echo ""
    echo "📋 Listando AVDs disponíveis:"
    emulator -list-avds
    exit 1
fi

echo "✅ Emulador encontrado!"

# Limpar build anterior (opcional)
read -p "Deseja limpar o build anterior? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🧹 Limpando build anterior..."
    ./gradlew :example-app:clean
fi

# Build do APK
echo "🔨 Construindo APK..."
./gradlew :example-app:assembleDebug

# Instalar no emulador
echo "📦 Instalando no emulador..."
./gradlew :example-app:installDebug

# Executar o app
echo "▶️  Iniciando aplicativo..."
adb shell am start -n br.com.dito.example/.MainActivity

echo "✅ Aplicativo iniciado no emulador!"
echo "📊 Para ver os logs: adb logcat | grep -E '(DitoExample|ExampleFCM)'"

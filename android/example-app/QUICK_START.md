# Quick Start - Example App

Guia rápido para executar o example-app no Android Studio.

## ⚡ Início Rápido (3 passos)

### 1. Abrir Projeto no Android Studio

```
File > Open > Selecionar pasta "android/"
```

**⚠️ IMPORTANTE**: Abra a pasta `android/`, não `example-app/`

### 2. Aguardar Sincronização

- O Android Studio vai sincronizar o Gradle automaticamente
- Aguarde até aparecer "Gradle sync finished"

### 3. Executar

1. No topo, selecione **"Example App"** no dropdown de configurações
2. Selecione um emulador/dispositivo
3. Clique em **Run** ▶️

## 📋 Checklist Pré-Execução

Antes de executar, verifique:

- [ ] Arquivo `.env.development.local` existe em `src/main/assets/`
- [ ] Arquivo `google-services.json` existe em `src/main/`
- [ ] API_KEY e API_SECRET configurados no `.env.development.local`
- [ ] Emulador Android rodando ou dispositivo físico conectado

## 🔧 Se Não Funcionar

### Módulo não aparece?

1. **File > Project Structure > Modules**
2. Verifique se `example-app` está listado
3. Se não estiver: **+ > Import Module** > selecione `example-app`

### Erro de build?

1. **File > Invalidate Caches / Restart**
2. Selecione **Invalidate and Restart**
3. Aguarde o Android Studio reiniciar

### Emulador não aparece?

1. **Tools > Device Manager**
2. Clique em **Create Device**
3. Escolha um dispositivo e imagem do sistema (API 25+)
4. Inicie o emulador

## 📱 Testando o App

Após executar:

1. O app deve abrir mostrando campos para testar o SDK
2. Clique em **"Obter Token FCM"** para obter o token Firebase
3. Preencha os campos e teste os métodos do SDK
4. Verifique os logs em **View > Tool Windows > Logcat**

## 🐛 Logs Úteis

Para ver logs do app:

```bash
adb logcat | grep -E "(DitoExample|ExampleFCM)"
```

Ou no Android Studio: **View > Tool Windows > Logcat** e filtre por `DitoExample`

## ⚠️ Problema Comum: .env não carrega

Se você ver `Warning: Could not load .env.development.local` nos logs:

**Causa**: O arquivo `.env.development.local` foi criado/modificado depois do último build, então não está no APK instalado.

**Solução Rápida**:
1. **Build > Clean Project**
2. **Build > Rebuild Project**
3. Execute o app novamente

## 📚 Documentação Completa

Para mais detalhes, consulte:
- `TROUBLESHOOTING.md` - Soluções para problemas comuns
- `ANDROID_STUDIO_SETUP.md` - Guia completo de configuração
- `README.md` - Documentação completa do app

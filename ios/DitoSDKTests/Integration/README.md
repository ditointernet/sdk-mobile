# Integration Tests — Configuração de Credenciais

Os testes de integração requerem credenciais reais da plataforma Dito. Por segurança, essas credenciais **não estão versionadas** no repositório e devem ser configuradas localmente ou via secrets de CI.

## Variáveis necessárias

| Variável | Obrigatoriedade | Descrição |
|---|---|---|
| `DITO_TEST_X_API_KEY` | Obrigatória | Token de API da plataforma |
| `DITO_TEST_API_KEY` | Obrigatória (se `API_SECRET` definido) | Chave de plataforma |
| `DITO_TEST_API_SECRET` | Opcional (modo legado) | Secret da API |

Obtenha os valores com a equipe de desenvolvimento.

## Configurar localmente no Xcode

1. No Xcode, acesse **Product → Scheme → Edit Scheme**
2. Selecione a aba **Test**
3. Vá em **Arguments → Environment Variables**
4. Adicione cada variável com seu respectivo valor:
   - `DITO_TEST_X_API_KEY` = `<valor obtido internamente>`
   - `DITO_TEST_API_KEY` = `<valor obtido internamente>`
   - `DITO_TEST_API_SECRET` = `<valor obtido internamente>` (opcional)

Essas configurações ficam no arquivo `.xcscheme` local, que **não é versionado**.

## Configurar em CI (GitHub Actions)

Adicione os secrets no repositório em **Settings → Secrets and variables → Actions** e passe-os como variáveis de ambiente no job:

```yaml
- name: Run integration tests
  env:
    DITO_TEST_X_API_KEY: ${{ secrets.DITO_TEST_X_API_KEY }}
    DITO_TEST_API_KEY: ${{ secrets.DITO_TEST_API_KEY }}
    DITO_TEST_API_SECRET: ${{ secrets.DITO_TEST_API_SECRET }}
  run: xcodebuild test ...
```

## Aviso de segurança — rotação obrigatória

As credenciais que estavam no `DitoSDK.xctestplan` foram removidas, mas o arquivo foi **criado com valores reais visíveis**. Mesmo sem commit anterior no histórico git, as credenciais podem ter sido expostas em sessões de trabalho anteriores.

**Ação obrigatória (fora do escopo deste PR):** notificar a equipe no canal interno para revogar e rotacionar as seguintes credenciais:

- `DITO_TEST_X_API_KEY`
- `DITO_TEST_API_SECRET`
- `DITO_TEST_API_KEY`

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Desligado de propósito. O corpo do commit é onde a evidência de dispositivo
    // fica registrada — stack trace, linha de logcat, saída de `dumpsys` — e ela vale
    // exatamente por ser verbatim. Reflowar um stack frame de 121 colunas para caber
    // em 100 corrompe a prova; foi o que esta regra pediu em `bd77c28`, `840f8f3` e
    // `3c59365`. O limite continua valendo para o cabeçalho (`header-max-length`),
    // que é o que aparece em `git log --oneline` e no changelog.
    'body-max-line-length': [0, 'always', 100],
  },
  ignores: [(message) => message.startsWith('Merge pull request')],
};


module.exports = {
  branches: ['main'],
  tagFormat: 'android-v${version}',
  plugins: [
    [
      '@semantic-release/exec',
      {
        analyzeCommitsCmd: 'bash ./scripts/semantic-release/analyze.sh android android-',
        generateNotesCmd: 'bash ./scripts/semantic-release/notes.sh android android-',
        prepareCmd: 'bash ./scripts/semantic-release/bump-version.sh android ${nextRelease.version}',
      },
    ],
    ['@semantic-release/changelog', { changelogFile: 'android/CHANGELOG.md' }],
    [
      '@semantic-release/git',
      {
        // bump-version.sh também move o default de `version` no build script e o pin que o
        // plugin Flutter usa. Sem os dois aqui, o repositório fica declarando uma versão
        // diferente da que foi publicada — e `scripts/check-version-pins.sh` só compara os
        // dois números entre si, então a divergência com o Maven Central não aparece em CI.
        assets: [
          'android/CHANGELOG.md',
          'android/dito-sdk/build.gradle.kts',
          'flutter/android/build.gradle',
        ],
        message: 'chore(release): android ${nextRelease.version}\n\n${nextRelease.notes}',
      },
    ],
  ],
};


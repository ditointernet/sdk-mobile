module.exports = {
  branches: ['main'],
  tagFormat: 'ios-v${version}',
  plugins: [
    [
      '@semantic-release/exec',
      {
        analyzeCommitsCmd: 'bash ./scripts/semantic-release/analyze.sh ios ios-',
        generateNotesCmd: 'bash ./scripts/semantic-release/notes.sh ios ios-',
        prepareCmd: 'bash ./scripts/semantic-release/bump-version.sh ios ${nextRelease.version}',
      },
    ],
    ['@semantic-release/changelog', { changelogFile: 'ios/CHANGELOG.md' }],
    [
      '@semantic-release/git',
      {
        // Tem de listar **todo** arquivo que bump-version.sh escreve. O que não está aqui é
        // gravado na árvore e descartado sem aviso: o release iOS 3.6.0 foi cortado com os
        // podspecs ainda em 3.5.0 porque `ios/DitoSDK.podspec` já não existia — os podspecs
        // passaram para a raiz — e um asset inexistente é ignorado em silêncio. O `pod trunk
        // push` então lintou a 3.5.0, cujo `s.source` aponta para a tag ios-v3.5.0, uma
        // árvore sem a NSE: "source_files pattern did not match any file".
        assets: [
          'ios/CHANGELOG.md',
          'DitoSDK.podspec',
          'DitoSDKNotificationService.podspec',
          'flutter/ios/dito_sdk.podspec',
        ],
        message: 'chore(release): ios ${nextRelease.version}\n\n${nextRelease.notes}',
      },
    ],
  ],
};


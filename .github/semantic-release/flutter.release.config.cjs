module.exports = {
  branches: ['main'],
  tagFormat: 'flutter-v${version}',
  plugins: [
    [
      '@semantic-release/exec',
      {
        analyzeCommitsCmd: 'bash ./scripts/semantic-release/analyze.sh flutter flutter-',
        generateNotesCmd: 'bash ./scripts/semantic-release/notes.sh flutter flutter-',
        prepareCmd: 'bash ./scripts/semantic-release/bump-version.sh flutter ${nextRelease.version}',
      },
    ],
    ['@semantic-release/changelog', { changelogFile: 'flutter/CHANGELOG.md' }],
    [
      '@semantic-release/git',
      {
        assets: ['flutter/CHANGELOG.md', 'flutter/pubspec.yaml'],
        message: 'chore(release): flutter ${nextRelease.version}\n\n${nextRelease.notes}',
      },
    ],
  ],
};


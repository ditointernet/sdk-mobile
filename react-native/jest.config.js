// O pacote declarava `"test": "jest"` mas nunca teve config nem transform, então nenhum
// dos testes rodava — `jest` morria no primeiro `import` de TypeScript. `tsc --noEmit`
// passava, o que fazia o problema não aparecer no CI de tipos.
//
// A config do Babel fica inline aqui de propósito, em vez de num babel.config.js na raiz
// do pacote: um babel.config.js seria pego também pelo bundler do app de exemplo, e o que
// ele precisa (preset do React Native) não é o que o Jest precisa.
//
// Estado com esta config: 2 de 3 suites rodam, 14 testes passam. A que sobra é
// `__tests__/DitoSdk.test.ts`, pré-existente, que faz `jest.requireActual('react-native')`
// e por isso precisa do ambiente de teste completo do RN, não só de um transform.
// `preset: 'react-native'` foi tentado e é pior — quebra as três suites no setup do
// próprio preset. Consertar aquele arquivo é ticket próprio: o caminho é mockar o
// `NativeModules` sem carregar o react-native de verdade.
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.ts'],
  transform: {
    '^.+\\.[jt]sx?$': [
      'babel-jest',
      {
        presets: [
          ['@babel/preset-env', { targets: { node: 'current' } }],
          '@babel/preset-typescript',
          // O react-native é publicado em Flow com sintaxe de módulo ES, e um dos
          // testes faz `jest.requireActual('react-native')`. Sem o preset do Flow
          // esse arquivo morre no primeiro `import typeof`.
          '@babel/preset-flow',
        ],
      },
    ],
  },
  // node_modules é ignorado por padrão; o react-native precisa ser transformado.
  transformIgnorePatterns: ['/node_modules/(?!react-native/)'],
  // O react-native espera este global, que normalmente vem do bundler.
  globals: { __DEV__: true },
};

import fs from 'fs';
import path from 'path';

const packageJson = require('../package.json');
const packageLock = require('../package-lock.json');

describe('package metadata', () => {
  const androidBuildGradlePath = path.join(__dirname, '../android/build.gradle');
  const changelogPath = path.join(__dirname, '../CHANGELOG.md');
  const iosPodspecPath = path.join(__dirname, '../ios/DitoSdkModule.podspec');

  it('should keep package and lock metadata aligned', () => {
    // Arrange
    const rootLockPackage = packageLock.packages[''];

    // Act & Assert
    expect(packageJson.name).toBe('@ditointernet/dito-sdk');
    expect(packageJson.version).toBe('2.0.0');
    expect(packageLock.name).toBe(packageJson.name);
    expect(packageLock.version).toBe(packageJson.version);
    expect(rootLockPackage.name).toBe(packageJson.name);
    expect(rootLockPackage.version).toBe(packageJson.version);
    expect(packageJson.main).toBe('src/index.ts');
    expect(packageJson.types).toBe('src/index.ts');
  });

  it('should declare React Native package compatibility metadata', () => {
    // Arrange
    const peerDependencies = packageJson.peerDependencies;
    const repository = packageJson.repository;

    // Act & Assert
    expect(peerDependencies.react).toBe('>=18.0.0');
    expect(peerDependencies['react-native']).toBe('>=0.72.0');
    expect(repository.directory).toBe('react-native');
    expect(packageJson.keywords).toEqual(
      expect.arrayContaining(['react-native', 'dito', 'crm', 'push-notifications']),
    );
  });

  it('should reference Android 3.4.0 and iOS 3.3.1 native SDK targets', () => {
    // Arrange
    const androidBuildGradle = fs.readFileSync(androidBuildGradlePath, 'utf8');
    const changelog = fs.readFileSync(changelogPath, 'utf8');
    const iosPodspec = fs.readFileSync(iosPodspecPath, 'utf8');

    // Act & Assert
    expect(androidBuildGradle).toContain("implementation 'br.com.dito:ditosdk:3.4.0'");
    expect(iosPodspec).toContain(":tag => 'ios-v3.3.1'");
    expect(changelog).toContain('Android 3.4.0');
    expect(changelog).toContain('iOS 3.3.1');
  });
});

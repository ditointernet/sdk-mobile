import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readProjectFile(String path) {
    return File('${Directory.current.path}/$path').readAsStringSync();
  }

  test('pubspec declares Flutter package version 3.4.0', () {
    final pubspec = readProjectFile('pubspec.yaml');

    expect(pubspec, contains(RegExp(r'^version:\s*3\.4\.0$', multiLine: true)));
  });

  test('Android metadata targets native SDK 3.4.0', () {
    final buildGradle = readProjectFile('android/build.gradle');

    expect(buildGradle, contains('br.com.dito:ditosdk:3.4.0'));
  });

  test('iOS metadata targets native SDK 3.3.1', () {
    final podspec = readProjectFile('ios/dito_sdk.podspec');

    expect(podspec, contains("s.version          = '3.4.0'"));
    expect(podspec, contains("s.dependency 'DitoSDK', '3.3.1'"));
    expect(podspec, isNot(contains(':git =>')));
  });

  test('changelog records aligned native targets', () {
    final changelog = readProjectFile('CHANGELOG.md');

    expect(changelog, contains('## 3.4.0'));
    expect(changelog, contains('br.com.dito:ditosdk:3.4.0'));
    expect(changelog, contains('ios-v3.3.1'));
    expect(changelog, contains('3.4.0'));
  });
}

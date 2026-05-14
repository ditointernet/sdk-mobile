import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sample_application/main.dart';

void main() {
  test('configures MyApp with DitoSdk', () {
    final ditoSdk = DitoSdk();
    final app = MyApp(ditoSdk: ditoSdk);

    expect(app.ditoSdk, same(ditoSdk));
  });
}

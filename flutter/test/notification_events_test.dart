import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = EventChannel('br.com.dito/notification_events');
  const codec = StandardMethodCodec();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, null);
  });

  test('DitoNotificationClick parses supported native fields', () {
    final click = DitoNotificationClick.fromMap(<Object?, Object?>{
      'deeplink': 'dito://notification',
      'notificationId': 'notification-id',
      'reference': 'reference',
      'logId': 'log-id',
      'notificationName': 'Notification Name',
      'userId': 'user-id',
    });

    expect(click.deeplink, 'dito://notification');
    expect(click.notificationId, 'notification-id');
    expect(click.reference, 'reference');
    expect(click.logId, 'log-id');
    expect(click.notificationName, 'Notification Name');
    expect(click.userId, 'user-id');
  });

  test('DitoSdk.onNotificationClick emits native click events once', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, (ByteData? message) async {
          final call = codec.decodeMethodCall(message);

          if (call.method == 'listen' || call.method == 'cancel') {
            return codec.encodeSuccessEnvelope(null);
          }

          fail('Unexpected event channel method ${call.method}');
        });

    final events = <DitoNotificationClick>[];
    final subscription = DitoSdk.onNotificationClick.listen(events.add);

    await pumpEventQueue();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          eventChannel.name,
          codec.encodeSuccessEnvelope(<String, Object?>{
            'deeplink': 'dito://notification',
            'notificationId': 'notification-id',
            'reference': 'reference',
            'logId': 'log-id',
            'notificationName': 'Notification Name',
            'userId': 'user-id',
          }),
          (_) {},
        );

    await pumpEventQueue();
    await subscription.cancel();

    expect(events, hasLength(1));
    expect(events.single.deeplink, 'dito://notification');
    expect(events.single.notificationId, 'notification-id');
    expect(events.single.reference, 'reference');
    expect(events.single.logId, 'log-id');
    expect(events.single.notificationName, 'Notification Name');
    expect(events.single.userId, 'user-id');
  });
}

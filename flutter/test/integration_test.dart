import 'package:dito_sdk/dito_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Push Notification Integration', () {
    test('DitoNotificationInfo parses complete inbox payload', () {
      final notification = DitoNotificationInfo.fromMap(<Object?, Object?>{
        'id': 'inbox-id',
        'notificationId': 'notification-id',
        'reference': 'reference',
        'title': 'Title',
        'message': 'Message',
        'link': 'dito://notification',
        'receivedAt': 1710000000000,
        'isRead': true,
      });

      expect(notification.id, 'inbox-id');
      expect(notification.notificationId, 'notification-id');
      expect(notification.reference, 'reference');
      expect(notification.title, 'Title');
      expect(notification.message, 'Message');
      expect(notification.link, 'dito://notification');
      expect(
        notification.receivedAt,
        DateTime.fromMillisecondsSinceEpoch(1710000000000),
      );
      expect(notification.isRead, isTrue);
    });

    test('DitoNotificationInfo keeps defaults for partial inbox payloads', () {
      final notification = DitoNotificationInfo.fromMap(<Object?, Object?>{});

      expect(notification.id, isEmpty);
      expect(notification.notificationId, isEmpty);
      expect(notification.reference, isEmpty);
      expect(notification.title, isEmpty);
      expect(notification.message, isEmpty);
      expect(notification.link, isEmpty);
      expect(notification.receivedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(notification.isRead, isFalse);
    });

    test('DitoNotificationOptions maps supported native option fields', () {
      const options = DitoNotificationOptions(
        accentColor: 0xFF336699,
        badgeEnabled: false,
        largeIconResId: 10,
        smallIconResId: 20,
        soundResourceName: 'custom_sound',
      );

      expect(options.toMap(), <String, Object?>{
        'accentColor': 0xFF336699,
        'badgeEnabled': false,
        'largeIconResId': 10,
        'smallIconResId': 20,
        'soundResourceName': 'custom_sound',
      });
    });
  });
}

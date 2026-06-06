import 'package:fanzone/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushNotificationService', () {
    test('registers device tokens only after notification authorization', () {
      expect(
        PushNotificationService.canRegisterDeviceTokenForStatus(
          AuthorizationStatus.authorized,
        ),
        isTrue,
      );
      expect(
        PushNotificationService.canRegisterDeviceTokenForStatus(
          AuthorizationStatus.provisional,
        ),
        isTrue,
      );
      expect(
        PushNotificationService.canRegisterDeviceTokenForStatus(
          AuthorizationStatus.denied,
        ),
        isFalse,
      );
      expect(
        PushNotificationService.canRegisterDeviceTokenForStatus(
          AuthorizationStatus.notDetermined,
        ),
        isFalse,
      );
    });
  });
}

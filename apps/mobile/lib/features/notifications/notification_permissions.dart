import 'package:flutter/services.dart';

class NotificationPermissions {
  static const MethodChannel _channel = MethodChannel('com.certigo.mobileapp/notifications');

  static Future<void> openSettings() async {
    if (await _channel.invokeMethod<bool>('openSettings') != true) {
      throw StateError('Notification settings could not be opened');
    }
  }
}

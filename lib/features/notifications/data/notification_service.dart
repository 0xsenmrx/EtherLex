import 'package:local_notifier/local_notifier.dart';

import '../../../app/app_info.dart';

abstract interface class NotificationService {
  Future<void> show(String title, String body);
}

/// Native desktop toasts (Windows action centre). Failures are swallowed:
/// a missed notification must never break the app.
class LocalNotificationService implements NotificationService {
  bool _ready = false;

  Future<void> _setup() async {
    if (_ready) return;
    await localNotifier.setup(appName: kAppName, shortcutPolicy: ShortcutPolicy.requireCreate);
    _ready = true;
  }

  @override
  Future<void> show(String title, String body) async {
    try {
      await _setup();
      await LocalNotification(title: title, body: body).show();
    } catch (_) {}
  }
}

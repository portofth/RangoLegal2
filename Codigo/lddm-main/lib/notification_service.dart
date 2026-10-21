import 'dart:async';

/// Serviço simples de notificações in-app (Singleton)
/// Uso: NotificationService.instance.notify('profile_updated');
///      NotificationService.instance.stream.listen((e) { ... });
class NotificationService {
  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final StreamController<String> _ctrl = StreamController<String>.broadcast();

  Stream<String> get stream => _ctrl.stream;

  void notify(String event) {
    try {
      // Log for debugging: helps trace when events are emitted
      // ignore: avoid_print
      print('🔔 NotificationService.notify: $event at ${DateTime.now().toIso8601String()}');
      _ctrl.add(event);
    } catch (_) {}
  }

  void dispose() {
    _ctrl.close();
  }
}

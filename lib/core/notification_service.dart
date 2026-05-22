import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handler de mensajes en background — debe ser top-level
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {}

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'encossa_alertas';
  static const _channelName = 'Alertas Control Almacén';

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    // Inicializar flutter_local_notifications
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // Crear canal Android con vibración y sonido
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );

    // Solicitar permiso en Android 13+
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Mostrar notificaciones en primer plano (la app abierta)
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        msg.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);
  }

  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
}

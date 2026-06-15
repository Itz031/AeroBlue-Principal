import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ServicioNotificaciones {
  static final FlutterLocalNotificationsPlugin _notificaciones = FlutterLocalNotificationsPlugin();

  static Future<void> inicializar() async {
    try {
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings configuracion = InitializationSettings(android: androidSettings);
      
      await _notificaciones.initialize(configuracion);

      await _notificaciones
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (error) {
      debugPrint('No se pudo inicializar el servicio de notificaciones: $error');
    }
  }

  static Future<bool> mostrarAlertaSistema({required String titulo, required String cuerpo}) async {
    try {
      const AndroidNotificationDetails detallesAndroid = AndroidNotificationDetails(
        'canal_contingencia_01', 
        'Alertas de Calidad del Aire', 
        channelDescription: 'Avisos urgentes sobre contingencias ambientales en Zacatenco',
        importance: Importance.max, 
        priority: Priority.high,    
        icon: '@mipmap/launcher_icon',
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails detalles = NotificationDetails(android: detallesAndroid);

      await _notificaciones.show(0, titulo, cuerpo, detalles);
      return true;
    } catch (error) {
      debugPrint('No se pudo mostrar la notificación: $error');
      return false;
    }
  }
}
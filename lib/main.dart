import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart'; // <-- 1. IMPORTAMOS EL ESCUDO WEB

// Importa tus pantallas
import 'ui/pantallas/navegacion_principal.dart';

// Importa tus providers y servicios
import 'backend/providers/aire_provider.dart';
import 'backend/servicios/servicio_notificaciones.dart';
import 'backend/servicios/api_clima.dart';
import 'backend/servicios/api_aeroblue.dart';

// === 1. EL CEREBRO EN SEGUNDO PLANO (WORKMANAGER) ===
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Leemos la memoria para saber si hay sesión y cuál es el límite
      final prefs = await SharedPreferences.getInstance();
      bool alertasActivas = prefs.getBool('config_alertas_activas') ?? true;
      double limiteSensibilidad = prefs.getDouble('config_nivel_sensibilidad') ?? 34.0;
      
      // Nombre de usuario para alerta personalizada
      String? nombreUsuario = prefs.getString('sesion_nombre'); 

      // Si las alertas están apagadas, dormimos el proceso y ahorramos batería
      if (!alertasActivas) return Future.value(true);

      // 2. Buscamos el clima (Usamos ESCOM/Zacatenco fijo para evitar bloqueos de GPS en 2do plano)
      final climaReal = await ApiClima.obtenerDatosActuales(19.5045, -99.1469);
      
      // 3. Consultamos la IA
      final prediccion = await ApiAeroBlue.consultarPrediccion(
        no2: climaReal['no2']!, o3: climaReal['o3']!, pm10: climaReal['pm10']!,
        pmco: climaReal['pmco']!, rh: climaReal['rh']!, tmp: climaReal['tmp']!,
        wdr: climaReal['wdr']!, wsp: climaReal['wsp']!,
      );

      if (prediccion != null) {
        double pm25 = prediccion['pm25_calculado'];

        // 4. LÓGICA DE ALERTA PERSONALIZADA
        if (pm25 >= limiteSensibilidad) {
          String tituloAlerta = (nombreUsuario != null && nombreUsuario.isNotEmpty)
              ? '¡Cuidado $nombreUsuario! Contingencia'
              : '¡Alerta AeroBlue!';
              
          await ServicioNotificaciones.mostrarAlertaSistema(
            titulo: tituloAlerta,
            cuerpo: 'El PM2.5 alcanzó los $pm25 µg/m³. Evita actividades al aire libre.',
          );
        }
      }
      return Future.value(true);
    } catch (err) {
      debugPrint("Error en proceso de fondo: $err");
      return Future.value(false);
    }
  });
}

// === 2. INICIO DE LA APP ===
void main() async {
  // Esta línea es OBLIGATORIA siempre que ejecutes código nativo antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Encendemos el canal de notificaciones en el sistema Android
  await ServicioNotificaciones.inicializar();

  // === 2. ESCUDO WEB: Verificamos dónde está corriendo la app ===
  if (!kIsWeb) {
    // Inicializamos Workmanager (El supervisor de tareas en segundo plano) solo si es celular
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Ponlo en true si quieres ver notificaciones de prueba del sistema
    );

    // Registramos la tarea para que se ejecute cada hora
    Workmanager().registerPeriodicTask(
      "1", // ID único de la tarea
      "revision_aire_por_hora", // Nombre interno de la tarea
      frequency: const Duration(hours: 1), // Frecuencia exacta
      constraints: Constraints(
        networkType: NetworkType.connected, // Solo despierta la app si hay internet
      ),
    );
  }

  runApp(
    // ENVOLVEMOS LA APP EN EL PROVIDER
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AireProvider())],
      child: const AeroBlueApp(),
    ),
  );
}

class AeroBlueApp extends StatelessWidget {
  const AeroBlueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroBlue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1565C0),
            letterSpacing: 2,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.green,
            letterSpacing: 1.5,
          ),
          titleMedium: TextStyle(fontSize: 20, color: Colors.black87),
        ),
      ),
      home: const NavegacionPrincipal(),
    );
  }
}
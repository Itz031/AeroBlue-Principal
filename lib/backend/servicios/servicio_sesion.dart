import 'package:shared_preferences/shared_preferences.dart';

class ServicioSesion {
  static const String _claveUsuarioActivo = 'USUARIO_ID_ACTIVO';
  static const String _claveEstadoSesion = 'SESION_ACTIVA';
  // === NUEVA CLAVE PARA LA IA EN SEGUNDO PLANO ===
  static const String _claveNombreUsuario = 'sesion_nombre'; 

  // 1. INICIAR SESIÓN (Ahora también recibe y guarda el nombre)
  static Future<void> iniciarSesion(int userId, String nombreUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveEstadoSesion, true);
    await prefs.setInt(_claveUsuarioActivo, userId);
    // Guardamos el nombre para que la alerta diga "¡Cuidado Luis!"
    await prefs.setString(_claveNombreUsuario, nombreUsuario); 
  }

  // 2. CERRAR SESIÓN (Destrucción quirúrgica de todos los rastros)
  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    // Usamos 'remove' en lugar de 'clear' para NO destruir la base de datos web
    await prefs.remove(_claveEstadoSesion);
    await prefs.remove(_claveUsuarioActivo);
    // Borramos el nombre para que las alertas vuelvan a ser genéricas
    await prefs.remove(_claveNombreUsuario); 
  }

  // 3. VERIFICAR ESTADO (El "Gatekeeper" pregunta si hay alguien logueado)
  static Future<bool> haySesionActiva() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveEstadoSesion) ?? false;
  }

  // 4. OBTENER AL USUARIO ACTUAL (Para que la DB sepa a quién buscar)
  static Future<int?> obtenerIdUsuarioActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_claveUsuarioActivo);
  }

  // 5. OBTENER EL NOMBRE DEL USUARIO (Opcional, útil para la UI)
  static Future<String?> obtenerNombreUsuarioActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveNombreUsuario);
  }
}
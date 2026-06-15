import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ServicioUbicacion {
  // Función para obtener la posición actual (Latitud y Longitud)
  static Future<Position?> obtenerPosicionActual() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    // 1. Verificamos si el GPS del celular está encendido
    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      print('El servicio de ubicación está desactivado.');
      return null;
    }

    // 2. Revisamos si tenemos permiso para usar el GPS
    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        print('Permisos de ubicación denegados.');
        return null;
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      print('Permisos de ubicación denegados permanentemente.');
      return null;
    }

    // 3. Si todo está bien, obtenemos la ubicación con alta precisión
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // Función para convertir Latitud y Longitud en el nombre de la zona
  static Future<String> obtenerNombreLugar(Position posicion) async {
    try {
      List<Placemark> lugares = await placemarkFromCoordinates(
          posicion.latitude, posicion.longitude);

      if (lugares.isNotEmpty) {
        Placemark lugar = lugares[0];
        // Retornamos el municipio/delegación o localidad
        return lugar.subLocality ?? lugar.locality ?? 'Ubicación Desconocida';
      }
    } catch (e) {
      print('Error al traducir las coordenadas: $e');
    }
    return 'Ubicación Desconocida';
  }
}
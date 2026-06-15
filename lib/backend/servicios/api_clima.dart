import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;

class ApiClima {
  static const String _apiKey = '5c4ee00c924dbec84a517f5c8534d00c';

  static Future<Map<String, double>> obtenerDatosActuales(double latitud, double longitud) async {
    try {
      final urlClima = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$latitud&lon=$longitud&units=metric&appid=$_apiKey');
      final urlContaminacion = Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$latitud&lon=$longitud&appid=$_apiKey');

      final respuestaClima = await http.get(urlClima).timeout(const Duration(seconds: 25));
      final respuestaContaminacion = await http.get(urlContaminacion).timeout(const Duration(seconds: 25));

      if (respuestaClima.statusCode == 200 && respuestaContaminacion.statusCode == 200) {
        final datosClima = json.decode(respuestaClima.body);
        final datosContaminacion = json.decode(respuestaContaminacion.body);
        final componentesAire = datosContaminacion['list'][0]['components'];

        return {
          'no2': componentesAire['no2']?.toDouble() ?? 0.0,
          'o3': componentesAire['o3']?.toDouble() ?? 0.0,
          'pm10': componentesAire['pm10']?.toDouble() ?? 0.0,
          'pmco': componentesAire['co']?.toDouble() ?? 0.0, 
          'rh': datosClima['main']['humidity']?.toDouble() ?? 0.0,
          'tmp': datosClima['main']['temp']?.toDouble() ?? 0.0,
          'wdr': datosClima['wind']['deg']?.toDouble() ?? 0.0,
          'wsp': datosClima['wind']['speed']?.toDouble() ?? 0.0,
        };
      } else if (respuestaClima.statusCode == 429 || respuestaContaminacion.statusCode == 429) {
        throw Exception('Límite de peticiones a OpenWeather excedido. Espera un minuto.');
      } else {
        throw Exception('Fallo OpenWeather: Clima ${respuestaClima.statusCode}, Aire ${respuestaContaminacion.statusCode}');
      }
    } on TimeoutException {
      throw Exception('La conexión con OpenWeather expiró por falta de red.');
    } catch (e) {
      throw Exception('Error al conectar con la API de clima: $e');
    }
  }
}
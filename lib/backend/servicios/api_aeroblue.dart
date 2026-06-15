import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiAeroBlue {
  // Aquí pones la URL exacta que te dio Render
  static const String _baseUrl = 'https://aeroblue-api.onrender.com';

  /// Envía los datos del clima al modelo de Machine Learning y devuelve la predicción
  static Future<Map<String, dynamic>?> consultarPrediccion({
    required double no2,
    required double o3,
    required double pm10,
    required double pmco,
    required double rh,
    required double tmp,
    required double wdr,
    required double wsp,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/predecir');
      
      // Empaquetamos los datos exactamente como los pide el "Cadenero" de FastAPI
      final payload = {
        "NO2": no2,
        "O3": o3,
        "PM10": pm10,
        "PMCO": pmco,
        "RH": rh,
        "TMP": tmp,
        "WDR": wdr,
        "WSP": wsp,
      };

      // Hacemos el disparo HTTP POST hacia la nube
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      // Código 200 significa éxito total
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Predicción recibida: ${data['pm25_calculado']} PM2.5");
        return data; 
      } else {
        print("❌ Error del servidor: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("❌ Error de conexión: $e");
      return null;
    }
  }
}
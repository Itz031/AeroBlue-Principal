import 'dart:convert';
import 'package:http/http.dart' as http;
import '../modelos/modelo_pronostico.dart';

class AeroBlueApiService {
  static const String baseUrl = 'https://api.aeroblue.mx/v1';

  Future<PronosticoAire> obtenerPronosticoZacatenco() async {
    try {
      final url = Uri.parse('$baseUrl/pronostico/zacatenco');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return PronosticoAire.fromJson(json.decode(response.body));
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      // Retorno simulado si no hay conexión o la API no existe aún
      return PronosticoAire(
        aqi: 35, 
        temperatura: 28.5, 
        clasificacion: 'EXCELENTE (Simulado)', 
        contaminantePrincipal: 'PM2.5'
      );
    }
  }
}
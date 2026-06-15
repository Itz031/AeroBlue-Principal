import 'dart:convert';
import 'dart:async'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// === IMPORTAMOS TUS APIS REALES ===
import 'servicio_ubicacion.dart';
import 'api_clima.dart';
import 'api_aeroblue.dart';

class AireService {
  
  // 1. ESTADO ACTUAL (100% REAL: GPS -> Clima -> IA)
  Future<Map<String, dynamic>> obtenerEstadoActual() async {
    try {
      // A. Obtenemos coordenadas (con el Escudo ESCOM como respaldo)
      final posicion = await ServicioUbicacion.obtenerPosicionActual();
      double lat = posicion?.latitude ?? 19.5045;
      double lon = posicion?.longitude ?? -99.1469;

      // B. Consultamos el clima en esa ubicación
      final climaReal = await ApiClima.obtenerDatosActuales(lat, lon);

      // C. Le pasamos los datos atmosféricos a tu modelo de Machine Learning
      final prediccion = await ApiAeroBlue.consultarPrediccion(
        no2: climaReal['no2']!, 
        o3: climaReal['o3']!, 
        pm10: climaReal['pm10']!,
        pmco: climaReal['pmco']!, 
        rh: climaReal['rh']!, 
        tmp: climaReal['tmp']!,
        wdr: climaReal['wdr']!, 
        wsp: climaReal['wsp']!,
      );

      // Si la IA falla, usamos un valor por defecto de seguridad
      double pm25 = prediccion != null ? (prediccion['pm25_calculado'] ?? 0.0) : 0.0;

      // D. Lógica de semáforo basada en el resultado real
      String calidadTexto = "EXCELENTE";
      Color colorCalidad = const Color(0xFF4CAF50);
      
      if (pm25 > 35.4) {
        calidadTexto = "MALA / PELIGRO";
        colorCalidad = const Color(0xFFE53935);
      } else if (pm25 > 12.0) {
        calidadTexto = "MODERADA";
        colorCalidad = const Color(0xFFFFB300);
      }

      // E. Devolvemos la información procesada para la interfaz
      return {
        'temperatura': '${climaReal['tmp']?.round() ?? '--'}°',
        'calidad': calidadTexto,
        'color': colorCalidad,
        'pm25_real': pm25, // Guardamos el valor exacto por si se necesita
      };

    } catch (e) {
      debugPrint('Error en obtenerEstadoActual: $e');
      rethrow; 
    }
  }

  // 2. PRONÓSTICOS DE GRÁFICAS (CONECTADO A RENDER)
  Future<Map<String, dynamic>?> obtenerPronosticosAQI() async {
    try {
      // 1. Obtenemos el clima actual real para pasárselo a tu IA
      final posicion = await ServicioUbicacion.obtenerPosicionActual();
      double lat = posicion?.latitude ?? 19.5045;
      double lon = posicion?.longitude ?? -99.1469;
      final climaReal = await ApiClima.obtenerDatosActuales(lat, lon);

      // 2. Empaquetamos los datos tal como los exige tu clase DatosAtmosfericos en FastAPI
      final bodyPeticion = json.encode({
        "NO2": climaReal['no2'],
        "O3": climaReal['o3'],
        "PM10": climaReal['pm10'],
        "PMCO": climaReal['pmco'],
        "RH": climaReal['rh'],
        "TMP": climaReal['tmp'],
        "WDR": climaReal['wdr'],
        "WSP": climaReal['wsp']
      });

      // 3. ¡EL DISPARO A TU SERVIDOR EN RENDER!
      final response = await http.post(
        Uri.parse('https://aeroblue-api.onrender.com/api/pronostico_graficas/'),
        headers: {"Content-Type": "application/json"},
        body: bodyPeticion,
      ).timeout(const Duration(seconds: 10));

      // 4. Procesamos la respuesta
      if (response.statusCode == 200) {
        // FastAPI nos devolvió la matriz de 45 puntos exactamente como Flutter la necesita
        return json.decode(response.body);
} else if (response.statusCode == 429) {
        throw Exception('El servidor de pronósticos está saturado (Error 429). Intenta más tarde.');
      } else {
        throw Exception('Fallo del servidor de Gráficas: Código ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('La solicitud de pronósticos expiró por tiempo de espera.');
    } catch (e) {
      debugPrint('Error de red al conectar con Render: $e');
      rethrow;
    }
  }

  // 3. ANÁLISIS HISTÓRICO (CONECTADO A RENDER)
  Future<Map<String, dynamic>?> obtenerDatosHistoricos(String fechaYYYYMMDD) async {
    try {
      // Disparamos la petición a la nueva ruta algorítmica en Python
      final url = Uri.parse('https://aeroblue-api.onrender.com/api/historico/$fechaYYYYMMDD');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Devolvemos el JSON con las 24 horas y las estadísticas (Promedio, Max, Min)
        return json.decode(response.body);
      } else {
        debugPrint('Error en histórico: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error de red al conectar con histórico: $e');
      return null;
    }
  }

  Color _colorSegunAqi(int aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.orange;
    return Colors.red;
  }
}

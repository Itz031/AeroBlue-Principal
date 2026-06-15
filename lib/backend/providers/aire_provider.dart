import 'dart:math';
import 'package:flutter/material.dart';
import '../servicios/aire_service.dart';
import '../servicios/excepciones_app.dart';

class AireProvider extends ChangeNotifier {
  final AireService _servicio = AireService();

  bool _cargando = false;
  bool get cargando => _cargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  bool _tieneError = false;
  bool get tieneError => _tieneError;

  DateTime? _ultimaActualizacion;
  DateTime? get ultimaActualizacion => _ultimaActualizacion;

  Map<String, dynamic> _datosActuales = {
    'temperatura': '--°',
    'calidad': 'Cargando...',
    'color': Colors.grey,
  };
  Map<String, dynamic> get datosActuales => _datosActuales;

  List<double> _prediccionHoyPorHora = [];
  List<double> get prediccionHoyPorHora => _prediccionHoyPorHora;

  Map<String, List<double>> _prediccionesRestoDelMes = {};
  Map<String, List<double>> get prediccionesRestoDelMes => _prediccionesRestoDelMes;

  Future<void> actualizarDatos() async {
    _cargando = true;
    _tieneError = false;
    _mensajeError = null;
    notifyListeners();

    try {
      _datosActuales = await _servicio.obtenerEstadoActual();
      _ultimaActualizacion = DateTime.now();
      _generarPrediccionesSimuladas();
    } on AeroBlueException catch (error) {
      _tieneError = true;
      _mensajeError = error.mensaje;
      _datosActuales = {
        'temperatura': '--°',
        'calidad': 'Sin conexión',
        'color': Colors.grey,
      };
      _generarPrediccionesSimuladas();
    } catch (_) {
      _tieneError = true;
      _mensajeError = 'Ocurrió un error inesperado al actualizar los datos.';
      _datosActuales['calidad'] = 'Error';
      _datosActuales['color'] = Colors.red;
      
      final pronostico = await _servicio.obtenerPronosticosAQI();
      
      if (pronostico != null) {
        _prediccionHoyPorHora = List<double>.from(pronostico['hoy']);
        _prediccionesRestoDelMes = {};
        (pronostico['mes'] as Map<String, dynamic>).forEach((llave, valores) {
          _prediccionesRestoDelMes[llave] = List<double>.from(valores);
        });
      } else {
        _prediccionHoyPorHora = [];
        _prediccionesRestoDelMes = {};
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void _generarPrediccionesSimuladas() {
    _prediccionHoyPorHora = List.generate(24, (hora) {
      if (hora > 12 && hora < 16) return 80.0 + Random().nextInt(40);
      return 20.0 + Random().nextInt(30);
    });

    _prediccionesRestoDelMes = {
      'Semana 2 del mes': [30.0, 45.0, 60.0, 110.0, 80.0, 40.0, 25.0],
      'Semana 3 del mes': [25.0, 30.0, 35.0, 40.0, 45.0, 30.0, 20.0],
      'Semana 4 del mes': [50.0, 55.0, 60.0, 50.0, 40.0, 35.0, 30.0],
    };
  }
}
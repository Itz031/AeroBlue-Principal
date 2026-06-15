import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../backend/servicios/servicio_notificaciones.dart';
import '../../backend/servicios/aire_service.dart';

class PantallaAlertas extends StatefulWidget {
  const PantallaAlertas({super.key});

  @override
  State<PantallaAlertas> createState() => _PantallaAlertasState();
}

class _PantallaAlertasState extends State<PantallaAlertas> {
  bool _alertasActivas = true;
  double _nivelSensibilidad = 34; 
  bool _analizando = true;
  double _pm25Actual = 0.0;
  String _calidadActual = "Buscando datos...";
  Color _colorActual = Colors.grey;

  final AireService _aireService = AireService();

  @override
  void initState() {
    super.initState();
    _cargarMemoriaLocal().then((_) {
      _consultarEstadoAire();
    });
  }

  Future<void> _cargarMemoriaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _alertasActivas = prefs.getBool('config_alertas_activas') ?? true;
        _nivelSensibilidad = prefs.getDouble('config_nivel_sensibilidad') ?? 34.0;
        _pm25Actual = prefs.getDouble('cache_pm25') ?? 0.0;
        _calidadActual = prefs.getString('cache_calidad') ?? "Sin datos previos";
        int? colorGuardado = prefs.getInt('cache_color');
        _colorActual = colorGuardado != null ? Color(colorGuardado) : Colors.grey;
      });
    }
  }

  Future<void> _guardarConfiguracionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('config_alertas_activas', _alertasActivas);
    await prefs.setDouble('config_nivel_sensibilidad', _nivelSensibilidad);
  }

  Future<void> _guardarPrediccionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cache_pm25', _pm25Actual);
    await prefs.setString('cache_calidad', _calidadActual);
    await prefs.setInt('cache_color', _colorActual.value);
  }

  Future<void> _consultarEstadoAire() async {
    setState(() => _analizando = true);
    final resultado = await _aireService.obtenerEstadoActual();
    
    if (mounted) {
      if (resultado['calidad'] == 'ERROR DE RED') {
        setState(() => _analizando = false);
        if (_pm25Actual == 0.0) _calidadActual = "Sin conexión";
        _mostrarConfirmacionRapida('Sin conexión. Mostrando último dato', esError: true);
      } else {
        setState(() {
          _pm25Actual = resultado['pm25_real'];
          _calidadActual = resultado['calidad'];
          _colorActual = resultado['color'];
          _analizando = false;
        });

        _guardarPrediccionLocal();

        if (_alertasActivas && _pm25Actual >= _nivelSensibilidad) {
          ServicioNotificaciones.mostrarAlertaSistema(
            titulo: '¡Contingencia AeroBlue!',
            cuerpo: 'PM2.5 en $_pm25Actual. Evita actividades prolongadas al aire libre.',
          );
        }
      }
    }
  }

  Map<String, dynamic> _obtenerRecomendacionSalud() {
    if (_analizando) return {"icono": Icons.sync_rounded, "texto": "Consultando cerebro de IA...", "color": Colors.grey};
    
    if (_pm25Actual == 0.0 && _calidadActual == "Sin conexión") {
      return {"icono": Icons.wifi_off_rounded, "texto": "Conéctate a internet para obtener tu primer diagnóstico ambiental.", "color": Colors.grey};
    }

    if (_pm25Actual <= 12.0) {
      return {"icono": Icons.directions_run_rounded, "texto": "¡Aire limpio! Excelente momento para hacer ejercicio o abrir ventanas.", "color": const Color(0xFF4CAF50)};
    } else if (_pm25Actual <= 35.4) {
      return {"icono": Icons.masks_rounded, "texto": "Calidad aceptable. Grupos sensibles (asma/alergias) deben limitar esfuerzo prolongado.", "color": const Color(0xFFFFB300)};
    } else {
      return {"icono": Icons.warning_rounded, "texto": "¡Peligro! Cierra ventanas, evita el deporte al aire libre y usa mascarilla N95.", "color": const Color(0xFFE53935)};
    }
  }

  Color _obtenerColorAQI(double valor) {
    if (valor <= 12.0) return const Color(0xFF4CAF50); 
    if (valor <= 35.4) return const Color(0xFFFFB300); 
    if (valor <= 55.4) return Colors.orange; 
    return const Color(0xFFE53935); 
  }

  String _obtenerTextoAQI(double valor) {
    if (valor <= 12.0) return 'Excelente';
    if (valor <= 35.4) return 'Moderada';
    if (valor <= 55.4) return 'Mala';
    return 'Peligro';
  }

  void _mostrarConfirmacionRapida(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0, behavior: SnackBarBehavior.floating, backgroundColor: Colors.transparent,
        duration: const Duration(milliseconds: 1500),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.1, left: 40, right: 40),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
            children: [
              Icon(esError ? Icons.wifi_off_rounded : Icons.check_circle_rounded, color: esError ? Colors.grey : const Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorDinamico = _obtenerColorAQI(_nivelSensibilidad);
    final recomendacion = _obtenerRecomendacionSalud();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: const Text('Centro de Salud Ambiental', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, elevation: 0, centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('DIAGNÓSTICO IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.2)),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _colorActual.withOpacity(0.3), width: 2),
              boxShadow: [BoxShadow(color: _colorActual.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PM2.5 Actual', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 5),
                        _analizando && _pm25Actual == 0.0
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('${_pm25Actual.toStringAsFixed(1)} µg/m³', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _colorActual)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: _colorActual.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(_calidadActual, style: TextStyle(color: _colorActual, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
                Row(
                  children: [
                    Icon(recomendacion['icono'], color: recomendacion['color'] ?? Colors.grey, size: 28),
                    const SizedBox(width: 15),
                    Expanded(child: Text(recomendacion['texto'], style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.4))),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('CONFIGURACIÓN DE NOTIFICACIONES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.2)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              title: const Text('Alertas de Contingencia', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              subtitle: const Text('Avisos PUSH en tiempo real', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              value: _alertasActivas,
              activeTrackColor: const Color(0xFF1E88E5).withOpacity(0.3),
              activeThumbColor: const Color(0xFF1E88E5),
              onChanged: (bool value) {
                setState(() => _alertasActivas = value);
                _guardarConfiguracionLocal();
                _mostrarConfirmacionRapida(value ? 'Alertas activadas' : 'Alertas silenciadas', esError: !value);
              },
            ),
          ),
          const SizedBox(height: 20),

          AnimatedOpacity(
            duration: const Duration(milliseconds: 300), opacity: _alertasActivas ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Avisar si supera (µg/m³):', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: colorDinamico.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_nivelSensibilidad.round().toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorDinamico)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Nivel de contingencia: ${_obtenerTextoAQI(_nivelSensibilidad)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorDinamico.withOpacity(0.8))),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6, activeTrackColor: colorDinamico, inactiveTrackColor: colorDinamico.withOpacity(0.15),
                      thumbColor: colorDinamico, overlayColor: colorDinamico.withOpacity(0.1),
                      valueIndicatorTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                      activeTickMarkColor: Colors.white.withOpacity(0.5),
                      inactiveTickMarkColor: colorDinamico.withOpacity(0.3),
                    ),
                    child: Slider(
                      value: _nivelSensibilidad, min: 12, max: 100, divisions: 4, label: _nivelSensibilidad.round().toString(),
                      onChanged: _alertasActivas ? (double value) => setState(() => _nivelSensibilidad = value) : null,
                      onChangeEnd: (value) { 
                        if (_alertasActivas) {
                          _guardarConfiguracionLocal();
                          _mostrarConfirmacionRapida('Límite actualizado a ${value.round()} µg/m³'); 
                        }
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estricto', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text('Peligro', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          ElevatedButton.icon(
            onPressed: () async {
              _mostrarConfirmacionRapida('Solicitando alerta a Android...');
              final exito = await ServicioNotificaciones.mostrarAlertaSistema(
                titulo: '¡Contingencia Ambiental!',
                cuerpo: 'El AQI ha superado el límite de ${_nivelSensibilidad.round()}. Evita actividades al aire libre.',
              );
              if (!exito && mounted) {
                _mostrarConfirmacionRapida('No se pudo enviar la notificación. Revisa permisos.');
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Probar Notificación de Sistema'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Colors.blueAccent, width: 0.5),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: SizedBox(
              width: double.infinity, height: 54, 
              child: ElevatedButton.icon(
                onPressed: () {
                  _mostrarConfirmacionRapida('Re-sincronizando...');
                  _consultarEstadoAire();
                },
                icon: const Icon(Icons.sync_rounded, size: 20),
                label: const Text('Actualizar Diagnóstico', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
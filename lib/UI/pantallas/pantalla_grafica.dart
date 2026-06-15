import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/providers/aire_provider.dart';
import '../../backend/servicios/servicio_ubicacion.dart';
import '../../backend/servicios/api_clima.dart' as clima_api;
import '../../backend/servicios/api_aeroblue.dart';

class PantallaGrafica extends StatefulWidget {
  const PantallaGrafica({super.key});

  @override
  State<PantallaGrafica> createState() => _PantallaGraficaState();
}

class _PantallaGraficaState extends State<PantallaGrafica> {
  bool _verGraficaDiaria = true;
  String _nombreUbicacion = "LOCALIZANDO...";
  String _temperaturaLocal = "--°";
  IconData _iconoClima = Icons.cloud_rounded;
  
  List<Color> _gradienteFondo = const [Color(0xFF4CA1AF), Color(0xFFC4E0E5)]; 
  final Color _colorTextoClima = Colors.black87;

  String _calidadAireTexto = "Calculando...";
  Color _colorCalidad = Colors.grey;
  bool _cargandoEntorno = true;

  @override
  void initState() {
    super.initState();
    _cargarCacheLocal().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AireProvider>().actualizarDatos();
      });
      _cargarDatosDelMundoReal();
    });
  }

  Future<void> _cargarCacheLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nombreUbicacion = prefs.getString('inicio_nombre') ?? "LOCALIZANDO...";
        _temperaturaLocal = prefs.getString('inicio_temp') ?? "--°";
        _calidadAireTexto = prefs.getString('inicio_calidad') ?? "Buscando red...";
        
        int? color1 = prefs.getInt('inicio_grad1');
        int? color2 = prefs.getInt('inicio_grad2');
        if (color1 != null && color2 != null) {
          _gradienteFondo = [Color(color1), Color(color2)];
        }
        
        int? colorCalidad = prefs.getInt('inicio_color_calidad');
        if (colorCalidad != null) _colorCalidad = Color(colorCalidad);

        int tipoIcono = prefs.getInt('inicio_icono') ?? 0;
        if (tipoIcono == 1) {
          _iconoClima = Icons.wb_sunny_rounded;
        } else if (tipoIcono == 2) {
          _iconoClima = Icons.water_drop_rounded;
        } else {
          _iconoClima = Icons.cloud_rounded;
        }
        
        if (_temperaturaLocal != "--°") _cargandoEntorno = false;
      });
    }
  }

  Future<void> _guardarCacheLocal(int tipoIcono) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('inicio_nombre', _nombreUbicacion);
    await prefs.setString('inicio_temp', _temperaturaLocal);
    await prefs.setString('inicio_calidad', _calidadAireTexto);
    await prefs.setInt('inicio_grad1', _gradienteFondo[0].value);
    await prefs.setInt('inicio_grad2', _gradienteFondo[1].value);
    await prefs.setInt('inicio_color_calidad', _colorCalidad.value);
    await prefs.setInt('inicio_icono', tipoIcono);
  }

  Future<void> _cargarDatosDelMundoReal() async {
    setState(() => _cargandoEntorno = true);
    final posicion = await ServicioUbicacion.obtenerPosicionActual();
    double latitudRequerida = 19.5045;
    double longitudRequerida = -99.1469;
    String nombreRequerido = "ESCOM - IPN";

    if (posicion != null) {
      latitudRequerida = posicion.latitude;
      longitudRequerida = posicion.longitude;
      nombreRequerido = await ServicioUbicacion.obtenerNombreLugar(posicion);
    }

    final climaReal = await clima_api.ApiClima.obtenerDatosActuales(latitudRequerida, longitudRequerida);
    
    if (climaReal != null && mounted) {
      double temp = climaReal['tmp']!;
      int tipoIconoGuardar = 0;

      setState(() {
        _nombreUbicacion = nombreRequerido.toUpperCase();
        _temperaturaLocal = "${temp.round()}°";
        
        if (temp > 25) {
          _iconoClima = Icons.wb_sunny_rounded;
          _gradienteFondo = const [Color(0xFFFF8008), Color(0xFFFFC837)];
          tipoIconoGuardar = 1;
        } else if (climaReal['rh']! > 70) {
          _iconoClima = Icons.water_drop_rounded;
          _gradienteFondo = const [Color(0xFF283E51), Color(0xFF4B79A1)];
          tipoIconoGuardar = 2;
        } else {
          _iconoClima = Icons.cloud_rounded;
          _gradienteFondo = const [Color(0xFF4CA1AF), Color(0xFFC4E0E5)];
          tipoIconoGuardar = 0;
        }
      });

      final prediccion = await ApiAeroBlue.consultarPrediccion(
        no2: climaReal['no2']!, o3: climaReal['o3']!, pm10: climaReal['pm10']!,
        pmco: climaReal['pmco']!, rh: climaReal['rh']!, tmp: climaReal['tmp']!,
        wdr: climaReal['wdr']!, wsp: climaReal['wsp']!,
      );

      if (prediccion != null && mounted) {
        double pm25 = prediccion['pm25_calculado'];
        setState(() {
          if (pm25 <= 12.0) {
            _calidadAireTexto = "EXCELENTE";
            _colorCalidad = const Color(0xFF4CAF50);
          } else if (pm25 <= 35.4) {
            _calidadAireTexto = "MODERADA";
            _colorCalidad = const Color(0xFFFFB300);
          } else {
            _calidadAireTexto = "MALA / PELIGRO";
            _colorCalidad = const Color(0xFFE53935);
          }
          _cargandoEntorno = false;
        });
        _guardarCacheLocal(tipoIconoGuardar);
      }
    } else {
      if (mounted) {
        setState(() => _cargandoEntorno = false);
        _mostrarNotificacionOffline();
      }
    }
  }

  void _mostrarNotificacionOffline() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        content: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Sin conexión. Mostrando caché offline.', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  String _formatearHora(DateTime fecha) {
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  Widget _crearGraficaLineal(List<double> datos, Color colorLinea, {required bool esPorHora}) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, _) { 
                if (value % 40 == 0) {
                  return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, 
              getTitlesWidget: (value, _) { 
                if (esPorHora) {
                  int hora = value.toInt();
                  if (hora % 6 == 0 && hora < 24) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('${hora.toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
                    );
                  }
                } else {
                  const dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                  if (value.toInt() >= 0 && value.toInt() < dias.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(dias[value.toInt()], style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  }
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: datos.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: colorLinea,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false), 
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [colorLinea.withOpacity(0.3), colorLinea.withOpacity(0.0)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final proveedorAire = context.watch<AireProvider>();
    final datos = proveedorAire.datosActuales;
    final prediccionHoy = proveedorAire.prediccionHoyPorHora; 
    final prediccionMes = proveedorAire.prediccionesRestoDelMes;
    final List<double> prediccionSemana = prediccionMes.isNotEmpty ? prediccionMes.values.first : [];

    return RefreshIndicator(
      onRefresh: () => proveedorAire.actualizarDatos(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        children: [
          if (proveedorAire.tieneError)
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No se pudo conectar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                        Text(proveedorAire.mensajeError ?? 'Simulando datos.', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconoClima, size: 80, color: _gradienteFondo.first),
              const SizedBox(width: 15),
              proveedorAire.cargando 
                  ? const CircularProgressIndicator()
                  : Text(_temperaturaLocal, style: const TextStyle(fontSize: 70, fontWeight: FontWeight.w300)),
            ],
          ),
          const SizedBox(height: 20),
          Center(child: Text(_nombreUbicacion, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: _colorTextoClima))),
          const SizedBox(height: 10),
          Center(child: Text('Calidad del aire actual', style: textTheme.titleMedium)),
          Center(child: Text(_calidadAireTexto, style: textTheme.headlineMedium?.copyWith(color: _colorCalidad, fontWeight: FontWeight.bold))),
          if (proveedorAire.ultimaActualizacion != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Actualizado a las ${_formatearHora(proveedorAire.ultimaActualizacion!)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ),
            ),

          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Evolución AQI', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _verGraficaDiaria = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: _verGraficaDiaria ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                        child: Text('24 hrs', style: TextStyle(color: _verGraficaDiaria ? _gradienteFondo.first : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _verGraficaDiaria = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: !_verGraficaDiaria ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                        child: Text('Semana', style: TextStyle(color: !_verGraficaDiaria ? _gradienteFondo.first : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 250,
            padding: const EdgeInsets.only(top: 30, right: 20, left: 10, bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: proveedorAire.cargando && prediccionHoy.isEmpty
                ? Center(child: CircularProgressIndicator(color: _gradienteFondo.first))
                : (prediccionHoy.isEmpty
                    ? const Center(child: Text('Sin conexión a red', style: TextStyle(color: Colors.black54)))
                    : _crearGraficaLineal(
                        _verGraficaDiaria ? prediccionHoy : prediccionSemana,
                        _colorCalidad == Colors.grey ? const Color(0xFF4CAF50) : _colorCalidad, 
                        esPorHora: _verGraficaDiaria,
                      )),
          ),
          const SizedBox(height: 30),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('Pronóstico extendido del mes', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
                subtitle: const Text('Toca para expandir las semanas', style: TextStyle(color: Colors.black54)),
                leading: Icon(Icons.calendar_month, color: _gradienteFondo.first),
                childrenPadding: const EdgeInsets.all(15),
                children: prediccionMes.entries.map((entrada) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(entrada.key, style: TextStyle(fontWeight: FontWeight.bold, color: _gradienteFondo.first)),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 150,
                        child: _crearGraficaLineal(entrada.value, Colors.blueGrey, esPorHora: false),
                      ),
                      const Divider(height: 30, color: Colors.black12),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
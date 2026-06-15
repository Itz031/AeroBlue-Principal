import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

// === IMPORTAMOS TU SERVICIO REAL ===
import '../../backend/servicios/aire_service.dart';

class PantallaHistorico extends StatefulWidget {
  const PantallaHistorico({super.key});

  @override
  State<PantallaHistorico> createState() => _PantallaHistoricoState();
}

class _PantallaHistoricoState extends State<PantallaHistorico> {
  String _contaminanteSeleccionado = 'PM2.5';
  DateTime _fechaSeleccionada = DateTime.now();
  bool _estaCargando = true; // Empieza cargando porque hará la petición a la API

  // Instanciamos tu servicio
  final AireService _aireService = AireService();

  // Ahora empiezan vacíos, se llenarán con lo que devuelva Render
  final Map<String, List<FlSpot>> _basesDeDatos = {
    'PM2.5': [],
    'PM10': [],
    'O3': [],
  };

  final Map<String, Color> _coloresContaminantes = {
    'PM2.5': const Color(0xFF1E88E5),
    'PM10': const Color(0xFF4CAF50),
    'O3': const Color(0xFFFFB300),
  };

  List<FlSpot> _datosActuales = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosHistoricosReales();
  }

  // === LA CONEXIÓN CON TU API ===
  Future<void> _cargarDatosHistoricosReales() async {
    setState(() { _estaCargando = true; });

    // 1. Formateamos la fecha seleccionada a YYYY-MM-DD para tu API en Python
    String fechaFormateada = "${_fechaSeleccionada.year}-${_fechaSeleccionada.month.toString().padLeft(2, '0')}-${_fechaSeleccionada.day.toString().padLeft(2, '0')}";

    // 2. Disparamos la petición a Render
    final respuestaAPI = await _aireService.obtenerDatosHistoricos(fechaFormateada);

    if (respuestaAPI != null && mounted) {
      setState(() {
        // 3. Convertimos los arreglos numéricos de Python en puntos para la gráfica (FlSpot)
        _basesDeDatos['PM2.5'] = _convertirListaASpots(respuestaAPI['pm25']);
        _basesDeDatos['PM10'] = _convertirListaASpots(respuestaAPI['pm10']);
        _basesDeDatos['O3'] = _convertirListaASpots(respuestaAPI['o3']);
        
        // 4. Mostramos el contaminante que esté seleccionado
        _datosActuales = _basesDeDatos[_contaminanteSeleccionado]!;
        _estaCargando = false;
      });
    } else if (mounted) {
      setState(() { _estaCargando = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener datos. Intenta nuevamente.', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFFE53935)),
      );
    }
  }

  // Utilidad para transformar la lista de tu API a los puntos que requiere Fl_Chart
  List<FlSpot> _convertirListaASpots(List<dynamic> lista) {
    List<FlSpot> spots = [];
    for (int i = 0; i < lista.length; i++) {
      spots.add(FlSpot(i.toDouble(), (lista[i] as num).toDouble()));
    }
    return spots;
  }

  // Calculamos las estadísticas basándonos en los datos que seleccionó el usuario
  double get _promedio => _datosActuales.isEmpty ? 0.0 : _datosActuales.map((e) => e.y).reduce((a, b) => a + b) / _datosActuales.length;
  double get _maximo => _datosActuales.isEmpty ? 10.0 : _datosActuales.map((e) => e.y).reduce(max);
  double get _minimo => _datosActuales.isEmpty ? 0.0 : _datosActuales.map((e) => e.y).reduce(min);

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1E88E5))),
          child: child!,
        );
      },
    );

    if (fechaElegida != null && fechaElegida != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = fechaElegida;
      });
      // Volvemos a consultar la API con la nueva fecha
      _cargarDatosHistoricosReales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorActual = _coloresContaminantes[_contaminanteSeleccionado]!;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Histórico de Datos', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () => _seleccionarFecha(context),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text('${_fechaSeleccionada.day.toString().padLeft(2, '0')}/${_fechaSeleccionada.month.toString().padLeft(2, '0')}/${_fechaSeleccionada.year}'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1E88E5), side: const BorderSide(color: Color(0xFF1E88E5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PM2.5', label: Text('PM2.5', style: TextStyle(fontWeight: FontWeight.w600))),
                ButtonSegment(value: 'PM10', label: Text('PM10', style: TextStyle(fontWeight: FontWeight.w600))),
                ButtonSegment(value: 'O3', label: Text('O3', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              selected: {_contaminanteSeleccionado},
              style: SegmentedButton.styleFrom(selectedForegroundColor: Colors.white, selectedBackgroundColor: colorActual),
              onSelectionChanged: (Set<String> newSelection) {
                if (_contaminanteSeleccionado != newSelection.first) {
                  setState(() { 
                    _contaminanteSeleccionado = newSelection.first; 
                    // Ya no llamamos a la API aquí porque la API nos bajó los 3 arreglos de golpe
                    _datosActuales = _basesDeDatos[_contaminanteSeleccionado]!;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 30, right: 20, left: 10, bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: _estaCargando 
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: colorActual), const SizedBox(height: 15), const Text('Sincronizando con IA...', style: TextStyle(color: Colors.grey))]))
                  : _construirGrafica(colorActual),
            ),
          ),
          const SizedBox(height: 30),
          Text('Estadísticas del día', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _crearDatoEstadistico('Promedio', _estaCargando ? '--' : '${_promedio.toStringAsFixed(1)} µg/m³', colorActual),
                Container(height: 40, width: 1, color: Colors.grey.shade200),
                _crearDatoEstadistico('Máximo', _estaCargando ? '--' : '${_maximo.toStringAsFixed(1)} µg/m³', const Color(0xFFE53935)),
                Container(height: 40, width: 1, color: Colors.grey.shade200),
                _crearDatoEstadistico('Mínimo', _estaCargando ? '--' : '${_minimo.toStringAsFixed(1)} µg/m³', const Color(0xFF4CAF50)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirGrafica(Color colorActual) {
    // Protección de UI en caso de que el servidor no mande datos
    if (_datosActuales.isEmpty) return const Center(child: Text("No hay datos para esta fecha"));

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueGrey.shade800,
            getTooltipItems: (touchedSpots) => touchedSpots.map((LineBarSpot touchedSpot) => LineTooltipItem('${touchedSpot.y} µg/m³\n', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), children: [TextSpan(text: '${touchedSpot.x.toInt()}:00 hrs', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal))])).toList(),
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 4,
              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 10.0), child: Text('${value.toInt().toString().padLeft(2, '0')}:00', style: const TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold))),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0, maxX: 23, minY: 0, maxY: _maximo * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: _datosActuales, isCurved: true, curveSmoothness: 0.35, color: colorActual, barWidth: 4, isStrokeCapRound: true, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [colorActual.withOpacity(0.4), colorActual.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _crearDatoEstadistico(String titulo, String valor, Color colorValor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(titulo, style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorValor)),
      ],
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../backend/servicios/servicio_ubicacion.dart';
// === IMPORTAMOS TUS APIS REALES ===
import '../../backend/servicios/api_clima.dart';
import '../../backend/servicios/api_aeroblue.dart';

class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  final LatLng _centroZacatenco = const LatLng(19.5045, -99.1469);
  late LatLng _ubicacionActual;

  final MapController _mapController = MapController();
  final TextEditingController _controladorBusqueda = TextEditingController();

  bool _buscando = false;
  LatLng? _ubicacionBuscada;
  String _nombreUbicacionBuscada = '';

  // === ESTADOS DE LOS FILTROS ===
  bool _filtroSensores = true;
  bool _filtroZonasRiesgo = false;
  bool _filtroCalorAQI = true;

  // === ESTADO DE CARGA DE IA ===
  bool _cargandoIA = true;

  // === DATOS DINÁMICOS: Empiezan en gris hasta que responda Render ===
  List<Map<String, dynamic>> _estacionesMonitoreo = [
    {'ubicacion': const LatLng(19.5045, -99.1469), 'color': Colors.grey, 'aqi': 0.0, 'nombre': 'Estación ESCOM'},
    {'ubicacion': const LatLng(19.4880, -99.1330), 'color': Colors.grey, 'aqi': 0.0, 'nombre': 'Estación Lindavista'},
    {'ubicacion': const LatLng(19.5180, -99.1200), 'color': Colors.grey, 'aqi': 0.0, 'nombre': 'Estación Ticomán'},
  ];

  @override
  void initState() {
    super.initState();
    _ubicacionActual = _centroZacatenco;

    _controladorBusqueda.addListener(() {
      setState(() {});
    });

    _obtenerUbicacionGPS();
    _cargarDatosEstacionesReales(); // Disparamos la consulta a Render al iniciar
  }

  // === LA MAGIA: CONEXIÓN DE CADA PIN CON TU MODELO DE ML ===
  Future<void> _cargarDatosEstacionesReales() async {
    List<Map<String, dynamic>> estacionesActualizadas = [];

    for (var estacion in _estacionesMonitoreo) {
      try {
        final lat = estacion['ubicacion'].latitude;
        final lon = estacion['ubicacion'].longitude;

        // 1. Obtenemos clima real de esa coordenada
        final clima = await ApiClima.obtenerDatosActuales(lat, lon);
        
        // 2. Mandamos a predecir a la IA en Render
        final prediccion = await ApiAeroBlue.consultarPrediccion(
          no2: clima['no2']!, o3: clima['o3']!, pm10: clima['pm10']!,
          pmco: clima['pmco']!, rh: clima['rh']!, tmp: clima['tmp']!,
          wdr: clima['wdr']!, wsp: clima['wsp']!
        );

        double pm25 = prediccion != null ? (prediccion['pm25_calculado'] ?? 0.0) : 0.0;
        
        // 3. Lógica de colores según la OMS
        Color color = const Color(0xFF4CAF50); // Verde (Excelente)
        if (pm25 > 35.4) {
          color = const Color(0xFFE53935); // Rojo (Peligro)
        } else if (pm25 > 12.0) {
          color = const Color(0xFFFFB300); // Amarillo (Moderada)
        }

        estacionesActualizadas.add({
          'ubicacion': estacion['ubicacion'],
          'nombre': estacion['nombre'],
          'aqi': pm25,
          'color': color,
        });
      } catch (e) {
        // Si hay error de red, mantenemos el pin original
        estacionesActualizadas.add(estacion);
      }
    }

    if (mounted) {
      setState(() {
        _estacionesMonitoreo = estacionesActualizadas;
        _cargandoIA = false;
      });
      // Notificamos al usuario que la IA terminó
      _mostrarNotificacionFlotante('IA AeroBlue Sincronizada', Icons.cloud_done_rounded, const Color(0xFF1E88E5));
    }
  }

  Future<void> _obtenerUbicacionGPS() async {
    final posicion = await ServicioUbicacion.obtenerPosicionActual();

    if (posicion != null && mounted) {
      setState(() {
        _ubicacionActual = LatLng(posicion.latitude, posicion.longitude);
      });
      _mapController.move(_ubicacionActual, 14.5); 
    } else if (mounted) {
      _mostrarNotificacionFlotante('Ubicación no encontrada. Mostrando ESCOM.', Icons.location_off_rounded, const Color(0xFFFFB300));
    }
  }

  void _mostrarNotificacionFlotante(String texto, IconData icono, Color colorIcono) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.15,
          left: 40,
          right: 40,
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: colorIcono, size: 22),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buscarUbicacion() async {
    final textoBusqueda = _controladorBusqueda.text.trim();
    if (textoBusqueda.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _buscando = true);

    try {
      final query = Uri.encodeComponent('$textoBusqueda, Ciudad de México');
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

      // 2. Hacemos la petición HTTP
      final response = await http.get(
        url,
        // Es obligatorio mandar un User-Agent en Nominatim
        headers: {'User-Agent': 'AeroBlueApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List resultados = json.decode(response.body);

        if (resultados.isNotEmpty) {
          final latitud = double.parse(resultados[0]['lat']);
          final longitud = double.parse(resultados[0]['lon']);
          final nombreCompleto = resultados[0]['display_name'];

          setState(() {
            _ubicacionBuscada = LatLng(latitud, longitud);
            _nombreUbicacionBuscada = nombreCompleto.split(',').take(2).join(',');
          });

          _mapController.move(_ubicacionBuscada!, 15.0);

          if (mounted) {
            _mostrarNotificacionFlotante('Ubicación encontrada', Icons.check_circle_rounded, const Color(0xFF4CAF50));
          }
        } else {
          if (mounted) _mostrarNotificacionFlotante('No se encontró el lugar', Icons.search_off_rounded, const Color(0xFFE53935));
        }
      } else {
        // El servidor de búsqueda respondió con un error (4xx/5xx)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('El servicio de búsqueda no está disponible (código ${response.statusCode}).'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } on SocketException {
      // No hay conexión a internet
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión a internet. Verifica tu red e inténtalo de nuevo.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on TimeoutException {
      // El servidor tardó demasiado en responder
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La búsqueda tardó demasiado. Inténtalo de nuevo.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on FormatException {
      // La respuesta del servidor no se pudo interpretar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo interpretar la respuesta del servidor.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocurrió un error inesperado. Inténtalo de nuevo.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      if (mounted) _mostrarNotificacionFlotante('Error de conexión', Icons.wifi_off_rounded, Colors.grey);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _limpiarBusqueda() {
    setState(() {
      _controladorBusqueda.clear();
      _ubicacionBuscada = null;
    });
    _mapController.move(_ubicacionActual, 14.5);
    FocusScope.of(context).unfocus();
  }

  void _abrirPanelFiltros() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              padding: EdgeInsets.only(
                top: 15, left: 24, right: 24, bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.layers_rounded, color: Color(0xFF1E88E5), size: 28),
                      const SizedBox(width: 12),
                      const Text('Capas del Mapa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const Spacer(),
                      if (_cargandoIA) 
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Selecciona la información ambiental que deseas visualizar en tiempo real.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),
                  
                  _crearOpcionFiltro(
                    titulo: 'Sensores de Calidad (AQI)',
                    subtitulo: 'Muestra los pines de monitoreo activos.',
                    icono: Icons.sensors_rounded,
                    colorIcono: Colors.blueAccent,
                    valor: _filtroSensores,
                    alCambiar: (bool valor) {
                      setModalState(() => _filtroSensores = valor);
                      setState(() => _filtroSensores = valor);
                    },
                  ),
                  _crearOpcionFiltro(
                    titulo: 'Mapa de Calor de Partículas',
                    subtitulo: 'Visualiza la dispersión de PM2.5.',
                    icono: Icons.blur_on_rounded,
                    colorIcono: Colors.orangeAccent,
                    valor: _filtroCalorAQI,
                    alCambiar: (bool valor) {
                      setModalState(() => _filtroCalorAQI = valor);
                      setState(() => _filtroCalorAQI = valor);
                    },
                  ),
                  _crearOpcionFiltro(
                    titulo: 'Zonas de Riesgo',
                    subtitulo: 'Resalta polígonos con contingencia actual.',
                    icono: Icons.warning_rounded,
                    colorIcono: Colors.redAccent,
                    valor: _filtroZonasRiesgo,
                    alCambiar: (bool valor) {
                      setModalState(() => _filtroZonasRiesgo = valor);
                      setState(() => _filtroZonasRiesgo = valor);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _crearOpcionFiltro({
    required String titulo, required String subtitulo, required IconData icono, required Color colorIcono,
    required bool valor, required ValueChanged<bool> alCambiar,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: valor ? colorIcono.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: valor ? colorIcono.withOpacity(0.3) : Colors.grey.shade200, width: 1.5),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: valor ? colorIcono.withOpacity(0.2) : Colors.grey.shade200, shape: BoxShape.circle),
          child: Icon(icono, color: valor ? colorIcono : Colors.grey),
        ),
        value: valor,
        activeThumbColor: colorIcono,
        onChanged: alCambiar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Buscamos el color dinámico de Ticomán para el polígono de riesgo
    Color colorPoligonoTicoman = Colors.transparent;
    if (_estacionesMonitoreo.isNotEmpty) {
      final estacionTicoman = _estacionesMonitoreo.firstWhere((e) => e['nombre'].contains('Ticomán'), orElse: () => _estacionesMonitoreo[0]);
      // Solo lo pintamos si el modelo indicó Peligro o Moderado
      if (estacionTicoman['aqi'] > 12.0) {
        colorPoligonoTicoman = estacionTicoman['color'];
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _centroZacatenco,
            initialZoom: 14.5,
            maxZoom: 18.0,
            minZoom: 10.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aeroblue.app',
            ),
            
            // --- FILTRO 3: ZONAS DE RIESGO ---
            // Ahora el polígono se pinta dinámicamente con el color que dictó la IA
            if (_filtroZonasRiesgo && colorPoligonoTicoman != Colors.transparent)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: const [
                      LatLng(19.5250, -99.1300), 
                      LatLng(19.5250, -99.1100),
                      LatLng(19.5100, -99.1100),
                      LatLng(19.5100, -99.1300),
                    ],
                    color: colorPoligonoTicoman.withOpacity(0.3),
                    isFilled: true,
                    borderColor: colorPoligonoTicoman,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),

            // --- FILTRO 2: MAPA DE CALOR ---
            if (_filtroCalorAQI)
              CircleLayer(
                circles: _estacionesMonitoreo.map((sensor) {
                  return CircleMarker(
                    point: sensor['ubicacion'],
                    color: (sensor['color'] as Color).withOpacity(0.25),
                    borderColor: (sensor['color'] as Color).withOpacity(0.6),
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: 1200,
                  );
                }).toList(),
              ),

            // --- FILTRO 1: PINES DEL MAPA ---
            MarkerLayer(
              markers: [
                _crearMarcadorPremium(
                  ubicacion: _ubicacionActual,
                  colorFondo: const Color(0xFF8E24AA),
                  icono: Icons.person_pin_circle_rounded,
                  titulo: 'Tú estás aquí',
                ),
                if (_ubicacionBuscada != null)
                  _crearMarcadorPremium(
                    ubicacion: _ubicacionBuscada!,
                    colorFondo: const Color(0xFF4CAF50),
                    icono: Icons.place_rounded,
                    titulo: _nombreUbicacionBuscada,
                  ),
                if (_filtroSensores)
                  ..._estacionesMonitoreo.map((sensor) {
                    return _crearMarcadorPremium(
                      ubicacion: sensor['ubicacion'],
                      colorFondo: sensor['color'],
                      icono: Icons.sensors_rounded,
                      titulo: '${sensor['nombre']} (AQI: ${sensor['aqi']})',
                    );
                  }),
              ],
            ),
          ],
        ),

        Positioned(
          top: 16, left: 16, right: 16,
          child: SafeArea(child: _crearBarraBusqueda()),
        ),

        Positioned(
          bottom: 24, right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: "btnFiltros",
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E88E5), 
                elevation: 4,
                onPressed: _abrirPanelFiltros,
                child: const Icon(Icons.layers_rounded, size: 22),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: "btnUbicacion",
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () {
                  _mapController.move(_ubicacionActual, 14.5);
                  if (_ubicacionBuscada != null) _limpiarBusqueda();
                },
                child: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Marker _crearMarcadorPremium({required LatLng ubicacion, required Color colorFondo, required IconData icono, required String titulo}) {
    return Marker(
      point: ubicacion, width: 45, height: 45,
      child: GestureDetector(
        onTap: () => _mostrarNotificacionFlotante(titulo, icono, colorFondo),
        child: Container(
          decoration: BoxDecoration(
            color: colorFondo, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: colorFondo.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Icon(icono, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _crearBarraBusqueda() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: _controladorBusqueda,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Buscar zona (Ej. Lindavista)',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
          suffixIcon: _buscando
              ? const Padding(padding: EdgeInsets.all(14.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1E88E5))))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controladorBusqueda.text.isNotEmpty)
                      IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20), onPressed: _limpiarBusqueda, splashRadius: 20),
                    IconButton(icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1E88E5), size: 22), onPressed: _buscarUbicacion, splashRadius: 20),
                    const SizedBox(width: 4),
                  ],
                ),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _buscarUbicacion(),
      ),
    );
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }
}
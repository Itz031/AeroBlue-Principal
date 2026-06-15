import 'package:flutter/material.dart';
import 'pantalla_grafica.dart';
import 'pantalla_mapa.dart';
import 'pantalla_historico.dart';
import 'pantalla_perfil.dart';
import 'pantalla_alertas.dart'; 
import '../../backend/servicios/servicio_ubicacion.dart';
import '../../backend/servicios/api_clima.dart' as clima_api;

class NavegacionPrincipal extends StatefulWidget {
  const NavegacionPrincipal({super.key});

  @override
  State<NavegacionPrincipal> createState() => _NavegacionPrincipalState();
}

class _NavegacionPrincipalState extends State<NavegacionPrincipal> {
  int _indiceActual = 0;

  final List<Widget> _pantallas = [
    const PantallaGrafica(),
    const PantallaMapa(),
    const PantallaHistorico(),
    const PantallaPerfil(),
  ];

  final List<String> _titulos = [
    'AeroBlue',
    'Mapa de Calidad',
    'Análisis Histórico',
    'Mi Perfil',
  ];

  List<Color> _gradienteFondo = const [Color(0xFF4CA1AF), Color(0xFFC4E0E5)];

  @override
  void initState() {
    super.initState();
    _sincronizarColorConElClima();
  }

  Future<void> _sincronizarColorConElClima() async {
    final posicion = await ServicioUbicacion.obtenerPosicionActual();
    double lat = posicion?.latitude ?? 19.5045; 
    double lon = posicion?.longitude ?? -99.1469;

    final climaReal = await clima_api.ApiClima.obtenerDatosActuales(lat, lon);
    
    if (climaReal != null && mounted) {
      double temp = climaReal['tmp']!;
      setState(() {
        if (temp > 25) {
          _gradienteFondo = const [Color(0xFFFF8008), Color(0xFFFFC837)]; 
        } else if (climaReal['rh']! > 70) {
          _gradienteFondo = const [Color(0xFF283E51), Color(0xFF4B79A1)]; 
        } else {
          _gradienteFondo = const [Color(0xFF4CA1AF), Color(0xFFC4E0E5)]; 
        }
      });
    }
  }

  void _mostrarComoFunciona(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('¿Cómo funciona AeroBlue?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Detectamos tu ubicación, analizamos el clima y mediante IA predecimos la concentración de PM2.5.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido', style: TextStyle(color: Color(0xFF1E88E5))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(_titulos[_indiceActual], style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradienteFondo, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('AeroBlue\nPanel de Control', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const Divider(color: Colors.white30),
                Expanded(
                  child: ListView(
                    children: [
                      _crearElementoDrawer(
                        icono: Icons.notifications_active_rounded,
                        texto: 'Gestión de Alertas',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const PantallaAlertas()) 
                          );
                        },
                      ),
                      _crearElementoDrawer(
                        icono: Icons.help_outline_rounded,
                        texto: 'Cómo funciona',
                        onTap: () {
                          Navigator.pop(context);
                          _mostrarComoFunciona(context);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _pantallas[_indiceActual]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (int index) => setState(() => _indiceActual = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded), label: 'Datos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _crearElementoDrawer({required IconData icono, required String texto, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icono, color: Colors.white),
      title: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
}
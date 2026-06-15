import 'package:flutter/material.dart';
import '../../backend/servicios/database_repository.dart';
import '../../backend/modelos/registro_aire.dart';

class PantallaOpciones extends StatefulWidget {
  const PantallaOpciones({super.key});

  @override
  State<PantallaOpciones> createState() => _PantallaOpcionesState();
}

class _PantallaOpcionesState extends State<PantallaOpciones> {
  String vistaSeleccionada = 'Semana';
  final AeroBlueRepository _repository = AeroBlueRepository();
  List<RegistroAire> _historialAire = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial(); 
  }

  Future<void> _cargarHistorial() async {
    try {
      final datosObtenidos = await _repository.obtenerHistorial();
      if (!mounted) return;
      setState(() {
        _historialAire = datosObtenidos;
        _estaCargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _mostrarError('No se pudo cargar el historial guardado en el dispositivo.');
    }
  }

  Future<void> _agregarDatoPrueba() async {
    try {
      final nuevoRegistro = RegistroAire(
        fecha: DateTime.now().toString().substring(0, 16),
        aqi: 55,
        nivel: 'Regular',
      );
      await _repository.insertarRegistro(nuevoRegistro);
      await _cargarHistorial();
    } catch (e) {
      _mostrarError('No se pudo guardar el pronóstico. Intenta de nuevo.');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFF5252),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Hoy', label: Text('Hoy')),
              ButtonSegment(value: 'Semana', label: Text('Histórico (SQLite)')),
            ],
            selected: {vistaSeleccionada},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() { vistaSeleccionada = newSelection.first; });
            },
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _agregarDatoPrueba, 
            icon: const Icon(Icons.save),
            label: const Text('Guardar pronóstico local'),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _estaCargando 
              ? const Center(child: CircularProgressIndicator()) 
              : _historialAire.isEmpty
                  ? const Center(child: Text('No hay historial guardado en el dispositivo.'))
                  : ListView.builder(
                      itemCount: _historialAire.length,
                      itemBuilder: (context, index) {
                        final registro = _historialAire[index];
                        Color colorNivel = registro.nivel == 'Excelente' ? Colors.green : Colors.orange;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(Icons.air, size: 40, color: colorNivel),
                            title: Text('AQI: ${registro.aqi} - ${registro.nivel}', 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Fecha: ${registro.fecha}'),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
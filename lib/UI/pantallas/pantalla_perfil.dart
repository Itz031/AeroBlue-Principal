import 'package:flutter/material.dart';
import '../../backend/db/db_helper.dart';
import '../../backend/servicios/servicio_sesion.dart';
import 'dart:convert'; 
import 'package:http/http.dart' as http;


class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  bool _cargandoDatos = true;
  bool _estaLogueado = false; 
  bool _modoEdicion = false;
  bool _modoRegistro = false; 

  late TextEditingController _ctrlNombre;
  late TextEditingController _ctrlApellidos;
  late TextEditingController _ctrlCorreo;
  late TextEditingController _ctrlInstitucion;
  late TextEditingController _ctrlRegistroPassword; 

  final TextEditingController _ctrlLoginCorreo = TextEditingController();
  final TextEditingController _ctrlLoginPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrlNombre = TextEditingController();
    _ctrlApellidos = TextEditingController();
    _ctrlCorreo = TextEditingController();
    _ctrlInstitucion = TextEditingController();
    _ctrlRegistroPassword = TextEditingController();
    
    _verificarEstadoSesion();
  }

  Future<void> _verificarEstadoSesion() async {
    setState(() => _cargandoDatos = true);
    bool activa = await ServicioSesion.haySesionActiva();
    
    if (activa) {
      await _cargarDatosDelUsuario();
    } else {
      setState(() {
        _estaLogueado = false;
        _cargandoDatos = false;
      });
    }
  }

  Future<void> _cargarDatosDelUsuario() async {
    final data = await DBHelper.obtenerUsuario();
    
    if (data != null) {
      setState(() {
        _ctrlNombre.text = data['nombre'] ?? '';
        _ctrlApellidos.text = data['apellidos'] ?? '';
        _ctrlCorreo.text = data['correo'] ?? '';
        _ctrlInstitucion.text = data['institucion'] ?? '';
        _estaLogueado = true;
        _cargandoDatos = false;
      });
    } else {
      await ServicioSesion.cerrarSesion();
      setState(() {
        _estaLogueado = false;
        _cargandoDatos = false;
      });
    }
  }

  Future<void> _iniciarSesionReal() async {
    FocusScope.of(context).unfocus(); 
    
    final correoIngresado = _ctrlLoginCorreo.text.trim();
    final passwordIngresado = _ctrlLoginPassword.text.trim();

    if (correoIngresado.isEmpty || passwordIngresado.isEmpty) {
      _mostrarNotificacion('Ingresa correo y contraseña', Icons.warning_rounded, Colors.orange);
      return;
    }

    setState(() => _cargandoDatos = true);
    await Future.delayed(const Duration(milliseconds: 800)); 
    
    final idEncontrado = await DBHelper.validarCredenciales(correoIngresado, passwordIngresado);

    if (idEncontrado != null) {
      await ServicioSesion.iniciarSesion(idEncontrado, "Usuario");
      await _cargarDatosDelUsuario(); 
      await ServicioSesion.iniciarSesion(idEncontrado, _ctrlNombre.text);
      _mostrarNotificacion('¡Bienvenido de nuevo!', Icons.waving_hand_rounded, const Color(0xFF1E88E5));
    } else {
      setState(() => _cargandoDatos = false);
      _mostrarNotificacion('Correo o contraseña incorrectos', Icons.error_outline_rounded, const Color(0xFFE53935));
    }
  }

  Future<void> _crearCuentaReal() async {
    FocusScope.of(context).unfocus();

    if (_ctrlNombre.text.isEmpty || _ctrlCorreo.text.isEmpty || _ctrlRegistroPassword.text.isEmpty) {
      _mostrarNotificacion('Por favor, llena los campos obligatorios', Icons.warning_rounded, Colors.orange);
      return;
    }

    setState(() => _cargandoDatos = true);
    await Future.delayed(const Duration(milliseconds: 800)); 

    final nuevoId = await DBHelper.crearCuenta({
      'nombre': _ctrlNombre.text.trim(),
      'apellidos': _ctrlApellidos.text.trim(),
      'correo': _ctrlCorreo.text.trim(),
      'institucion': _ctrlInstitucion.text.trim(),
      'password': _ctrlRegistroPassword.text.trim(),
    });

    if (nuevoId != null) {
      await ServicioSesion.iniciarSesion(nuevoId, _ctrlNombre.text.trim());
      await _cargarDatosDelUsuario();
      _mostrarNotificacion('¡Cuenta creada exitosamente!', Icons.check_circle_rounded, const Color(0xFF4CAF50));
    } else {
      setState(() => _cargandoDatos = false);
      _mostrarNotificacion('Este correo ya está registrado', Icons.error_outline_rounded, const Color(0xFFE53935));
    }
  }

  Future<void> _guardarPerfilEnDB() async {
    await DBHelper.actualizarPerfil({
      'nombre': _ctrlNombre.text,
      'apellidos': _ctrlApellidos.text,
      'correo': _ctrlCorreo.text,
      'institucion': _ctrlInstitucion.text
    });
    
    final idActivo = await ServicioSesion.obtenerIdUsuarioActivo();
    if (idActivo != null) {
      await ServicioSesion.iniciarSesion(idActivo, _ctrlNombre.text);
    }
  }

  void _limpiarFormularios() {
    _ctrlNombre.clear();
    _ctrlApellidos.clear();
    _ctrlCorreo.clear();
    _ctrlInstitucion.clear();
    _ctrlRegistroPassword.clear();
    _ctrlLoginCorreo.clear();
    _ctrlLoginPassword.clear();
  }

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlApellidos.dispose();
    _ctrlCorreo.dispose();
    _ctrlInstitucion.dispose();
    _ctrlRegistroPassword.dispose();
    _ctrlLoginCorreo.dispose();
    _ctrlLoginPassword.dispose();
    super.dispose();
  }

  void _mostrarNotificacion(String mensaje, IconData icono, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0, behavior: SnackBarBehavior.floating, backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2), margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 22), const SizedBox(width: 12),
              Flexible(child: Text(mensaje, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  // DIÁLOGO DE REPORTE INTEGRADO EN LA APP
  void _mostrarDialogoReporte(BuildContext context) {
    final TextEditingController ctrlReporte = TextEditingController();
    bool enviando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (contextoDialogo) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Reportar un problema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tu correo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: TextEditingController(text: _ctrlCorreo.text), // Toma el correo de la sesión
                      enabled: false, // Lo bloquea para que no lo editen
                      style: const TextStyle(color: Colors.grey),
                      decoration: InputDecoration(
                        filled: true, fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text('Descripción del problema:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: ctrlReporte,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ej. La aplicación se cierra al abrir el mapa...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: enviando ? null : () => Navigator.pop(contextoDialogo),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: enviando ? null : () async {
                    if (ctrlReporte.text.trim().isEmpty) return;
                    setStateDialog(() => enviando = true);
                    
                    try {
                      // LLAMADA REAL A INTERNET: Reemplaza con tu url de Render
                      final urlApi = Uri.parse('https://aeroblue-soporte-yfd1.onrender.com');
                      
                      final respuesta = await http.post(
                        urlApi,
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode({
                          "correo": _ctrlCorreo.text.trim(),
                          "descripcion": ctrlReporte.text.trim()
                        }),
                      );

                      if (respuesta.statusCode == 200 && mounted) {
                        Navigator.pop(contextoDialogo);
                        _mostrarNotificacion('Reporte enviado con éxito. Te avisaremos cuando se resuelva.', Icons.check_circle_rounded, Colors.green);
                      } else {
                        throw Exception("Error del servidor");
                      }
                    } catch (e) {
                      setStateDialog(() => enviando = false);
                      _mostrarNotificacion('Error de conexión. Inténtalo más tarde.', Icons.error_outline_rounded, Colors.red);
                    }
                  },
                  child: enviando 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('Enviar'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _mostrarDialogoCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext contextoDialogo) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0, backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 32)),
                const SizedBox(height: 20),
                const Text('¿Cerrar Sesión?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 12),
                const Text('Dejarás de recibir alertas personalizadas de AeroBlue.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(contextoDialogo), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(contextoDialogo);
                          setState(() => _cargandoDatos = true);
                          await ServicioSesion.cerrarSesion();
                          _limpiarFormularios(); 
                          _verificarEstadoSesion();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Sí, salir', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoDatos) {
      return const Scaffold(backgroundColor: Color(0xFFF1F5F9), body: Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _estaLogueado 
          ? _construirVistaPerfil() 
          : (_modoRegistro ? _construirVistaRegistro() : _construirVistaLogin()),
    );
  }

  Widget _construirVistaLogin() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.cloud_rounded, size: 80, color: Color(0xFF1E88E5))),
            const SizedBox(height: 32),
            const Text('Acceso a AeroBlue', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('Inicia sesión para recibir alertas.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
            const SizedBox(height: 40),
            
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  _crearCampoTexto('Correo electrónico', _ctrlLoginCorreo, Icons.email_outlined, activoSiempre: true, esCorreo: true),
                  const Divider(height: 1, indent: 50),
                  _crearCampoTexto('Contraseña', _ctrlLoginPassword, Icons.lock_outline_rounded, activoSiempre: true, esPassword: true),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _iniciarSesionReal,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _limpiarFormularios();
                setState(() => _modoRegistro = true);
              },
              child: const Text('¿No tienes cuenta? Regístrate aquí', style: TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirVistaRegistro() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_add_rounded, size: 50, color: Color(0xFF4CAF50))),
            const SizedBox(height: 24),
            const Text('Crear Cuenta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('Únete para personalizar tu experiencia.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
            const SizedBox(height: 30),
            
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  _crearCampoTexto('Nombre(s)', _ctrlNombre, Icons.badge_outlined, activoSiempre: true),
                  const Divider(height: 1, indent: 50),
                  _crearCampoTexto('Apellidos', _ctrlApellidos, Icons.family_restroom_outlined, activoSiempre: true),
                  const Divider(height: 1, indent: 50),
                  _crearCampoTexto('Correo Electrónico', _ctrlCorreo, Icons.email_outlined, esCorreo: true, activoSiempre: true),
                  const Divider(height: 1, indent: 50),
                  _crearCampoTexto('Institución (Opcional)', _ctrlInstitucion, Icons.school_outlined, activoSiempre: true),
                  const Divider(height: 1, indent: 50),
                  _crearCampoTexto('Contraseña', _ctrlRegistroPassword, Icons.lock_outline_rounded, activoSiempre: true, esPassword: true),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _crearCuentaReal,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _limpiarFormularios();
                setState(() => _modoRegistro = false);
              },
              child: const Text('¿Ya tienes cuenta? Inicia sesión', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _construirVistaPerfil() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        Container(
          padding: const EdgeInsets.only(top: 30, bottom: 20),
          color: Colors.white,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(radius: 55, backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1), child: const Icon(Icons.person_rounded, size: 60, color: Color(0xFF1E88E5))),
                  if (_modoEdicion)
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF1E88E5), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18)),
                ],
              ),
              const SizedBox(height: 16),
              Text('${_ctrlNombre.text} ${_ctrlApellidos.text}'.trim(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text(_ctrlInstitucion.text, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('INFORMACIÓN PERSONAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
              TextButton.icon(
                onPressed: () async {
                  if (_modoEdicion) {
                    await _guardarPerfilEnDB();
                    _mostrarNotificacion('Perfil actualizado', Icons.check_circle_rounded, const Color(0xFF4CAF50));
                  }
                  setState(() => _modoEdicion = !_modoEdicion);
                },
                icon: Icon(_modoEdicion ? Icons.save_rounded : Icons.edit_rounded, size: 16),
                label: Text(_modoEdicion ? 'Guardar' : 'Editar'),
                style: TextButton.styleFrom(foregroundColor: _modoEdicion ? const Color(0xFF4CAF50) : const Color(0xFF1E88E5)),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(
            children: [
              _crearCampoTexto('Nombre(s)', _ctrlNombre, Icons.badge_outlined), const Divider(height: 1, indent: 50),
              _crearCampoTexto('Apellidos', _ctrlApellidos, Icons.family_restroom_outlined), const Divider(height: 1, indent: 50),
              _crearCampoTexto('Correo Electrónico', _ctrlCorreo, Icons.email_outlined, esCorreo: true), const Divider(height: 1, indent: 50),
              _crearCampoTexto('Institución', _ctrlInstitucion, Icons.school_outlined),
            ],
          ),
        ),
        const SizedBox(height: 30),
        
        // --- BOTÓN DE REPORTE ACTUALIZADO ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton.icon(
            onPressed: () => _mostrarDialogoReporte(context),
            icon: const Icon(Icons.support_agent_rounded, size: 20),
            label: const Text('Reportar un problema', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 15),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(
            onPressed: () => _mostrarDialogoCerrarSesion(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE53935), side: const BorderSide(color: Color(0xFFEF9A9A), width: 1.5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
      ],
    );
  }

  Widget _crearCampoTexto(String etiqueta, TextEditingController controlador, IconData icono, {bool esCorreo = false, bool esPassword = false, bool activoSiempre = false}) {
    bool habilitado = activoSiempre || _modoEdicion;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controlador, 
        enabled: habilitado, 
        obscureText: esPassword,
        keyboardType: esCorreo ? TextInputType.emailAddress : TextInputType.text,
        style: TextStyle(color: habilitado ? const Color(0xFF1E293B) : const Color(0xFF64748B), fontWeight: habilitado ? FontWeight.w600 : FontWeight.w500),
        decoration: InputDecoration(
          labelText: etiqueta, 
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)), 
          icon: Icon(icono, color: const Color(0xFF94A3B8), size: 22), 
          border: InputBorder.none, 
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)), 
          isDense: true, 
          contentPadding: const EdgeInsets.symmetric(vertical: 12)
        ),
      ),
    );
  }
}
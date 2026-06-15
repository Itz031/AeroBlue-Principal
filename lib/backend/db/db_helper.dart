import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../servicios/servicio_sesion.dart';

class DBHelper {
  static const String _claveWeb = 'memoria_web_perfil';

  // === MOTOR REAL (SOLO PARA ANDROID/iOS) ===
  static Future<Database?> database() async {
    if (kIsWeb) return null; 

    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'aeroblue.db'), 
      onCreate: (db, version) async {
        // 1. ESTRUCTURA CON CONTRASEÑA Y AUTOINCREMENTO
        await db.execute(
          '''CREATE TABLE usuario(
            id INTEGER PRIMARY KEY AUTOINCREMENT, 
            nombre TEXT, 
            apellidos TEXT, 
            correo TEXT UNIQUE, 
            institucion TEXT, 
            password TEXT
          )'''
        );

        // 2. INYECCIÓN DE USUARIO PARA LA DEMO
        await db.insert('usuario', {
          'nombre': 'Oscar A. P.',
          'apellidos': 'Solano',
          'correo': 'oscar.solano@alumno.ipn.mx',
          'institucion': 'ESCOM - IPN',
          'password': 'password123'
        });
      }, 
      version: 1,
    );
  }

  // === NUEVO: REGISTRAR CUENTA ===
  static Future<int?> crearCuenta(Map<String, dynamic> data) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      // En la web simulamos un ID aleatorio usando la fecha actual
      data['id'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_claveWeb, json.encode(data));
      return data['id'];
    }

    final db = await DBHelper.database();
    try {
      // Al insertar sin mandar el 'id', SQLite usa el Autoincrement
      final id = await db!.insert('usuario', data);
      return id;
    } catch (e) {
      // Si el correo ya existe, SQLite lanzará un error (por el UNIQUE)
      return null; 
    }
  }

  // === VALIDAR LOGIN REAL ===
  static Future<int?> validarCredenciales(String correo, String password) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final stringDatos = prefs.getString(_claveWeb);
      
      if (stringDatos != null) {
        final data = json.decode(stringDatos);
        if (data['correo'] == correo && data['password'] == password) {
          return data['id'];
        }
      } else if (correo == 'oscar.solano@alumno.ipn.mx' && password == 'password123') {
        await prefs.setString(_claveWeb, json.encode({
          'id': 1, 'nombre': 'Oscar A. P.', 'apellidos': 'Solano', 
          'correo': correo, 'institucion': 'ESCOM - IPN', 'password': password
        }));
        return 1;
      }
      return null;
    }

    final db = await DBHelper.database();
    final result = await db!.query(
      'usuario', 
      where: 'correo = ? AND password = ?', 
      whereArgs: [correo, password], 
      limit: 1
    );
    
    return result.isNotEmpty ? result.first['id'] as int : null;
  }

  // === ACTUALIZAR PERFIL ===
  static Future<void> actualizarPerfil(Map<String, dynamic> data) async {
    final idActivo = await ServicioSesion.obtenerIdUsuarioActivo();
    if (idActivo == null) return;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final stringDatos = prefs.getString(_claveWeb);
      if (stringDatos != null) {
        Map<String, dynamic> usuarioActual = json.decode(stringDatos);
        data.forEach((key, value) => usuarioActual[key] = value);
        await prefs.setString(_claveWeb, json.encode(usuarioActual));
      }
      return;
    }

    final db = await DBHelper.database();
    await db!.update('usuario', data, where: 'id = ?', whereArgs: [idActivo]);
  }

  // === OBTENER USUARIO LOGUEADO ===
  static Future<Map<String, dynamic>?> obtenerUsuario() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final stringDatos = prefs.getString(_claveWeb);
      return stringDatos != null ? json.decode(stringDatos) : null;
    }

    final idActivo = await ServicioSesion.obtenerIdUsuarioActivo();
    if (idActivo == null) return null;

    final db = await DBHelper.database();
    final data = await db!.query('usuario', where: 'id = ?', whereArgs: [idActivo], limit: 1);
    return data.isNotEmpty ? data.first : null;
  }
}
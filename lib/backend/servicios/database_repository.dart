import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../modelos/registro_aire.dart';

class AeroBlueRepository {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aeroblue_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE historial_aire (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        aqi INTEGER NOT NULL,
        nivel TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertarRegistro(RegistroAire registro) async {
    final db = await database;
    return await db.insert('historial_aire', registro.toMap());
  }

  Future<List<RegistroAire>> obtenerHistorial() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('historial_aire', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => RegistroAire.fromMap(maps[i]));
  }
}
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;

    String path = join(await getDatabasesPath(), 'lryc.db');
    _db = await openDatabase(
      path,
      version: 2, // Incrementamos la versión para agregar la nueva tabla
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Agregar tabla de resaltados para usuarios existentes
          await db.execute('''
            CREATE TABLE resaltados(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              libro_id INTEGER,
              pagina INTEGER,
              texto_resaltado TEXT,
              posicion_inicio INTEGER,
              posicion_fin INTEGER,
              color TEXT DEFAULT '#FFFF00',
              tipo TEXT DEFAULT 'highlight',
              nota TEXT,
              fecha TEXT,
              FOREIGN KEY (libro_id) REFERENCES libros(id)
            )
          ''');
        }
      },
    );
    return _db!;
  }

  static Future<void> _createTables(Database db) async {
    // Tabla libros
    await db.execute('''
      CREATE TABLE libros(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT,
        autor TEXT,
        ruta_pdf TEXT
      )
    ''');

    // Tabla traducciones
    await db.execute('''
      CREATE TABLE traducciones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libro_id INTEGER,
        pagina INTEGER,
        texto_original TEXT,
        texto_traducido TEXT,
        fecha TEXT,
        FOREIGN KEY (libro_id) REFERENCES libros(id)
      )
    ''');

    // Tabla marcadores
    await db.execute('''
      CREATE TABLE marcadores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libro_id INTEGER,
        pagina INTEGER,
        titulo TEXT,
        nota TEXT,
        FOREIGN KEY (libro_id) REFERENCES libros(id)
      )
    ''');

    // Tabla resaltados - NUEVA
    await db.execute('''
      CREATE TABLE resaltados(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libro_id INTEGER,
        pagina INTEGER,
        texto_resaltado TEXT,
        posicion_inicio INTEGER,
        posicion_fin INTEGER,
        color TEXT DEFAULT '#FFFF00',
        tipo TEXT DEFAULT 'highlight',
        nota TEXT,
        fecha TEXT,
        FOREIGN KEY (libro_id) REFERENCES libros(id)
      )
    ''');
  }

  // =========================
  // CRUD Libros
  // =========================

  static Future<int> insertarLibro(String titulo, String? autor, String ruta) async {
    final db = await getDatabase();
    return await db.insert('libros', {
      'titulo': titulo,
      'autor': autor,
      'ruta_pdf': ruta,
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerLibros() async {
    final db = await getDatabase();
    return await db.query('libros', orderBy: 'titulo ASC');
  }

  static Future<int> borrarLibro(int id) async {
    final db = await getDatabase();
    return await db.delete('libros', where: 'id = ?', whereArgs: [id]);
  }

  // =========================
  // CRUD Traducciones
  // =========================

  static Future<int> insertarTraduccion(
    int libroId,
    int pagina,
    String original,
    String traducido,
    String fecha,
  ) async {
    final db = await getDatabase();
    return await db.insert('traducciones', {
      'libro_id': libroId,
      'pagina': pagina,
      'texto_original': original,
      'texto_traducido': traducido,
      'fecha': fecha,
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerTraducciones(int libroId) async {
    final db = await getDatabase();
    return await db.query(
      'traducciones',
      where: 'libro_id = ?',
      whereArgs: [libroId],
      orderBy: 'pagina ASC',
    );
  }

  static Future<int> borrarTraduccionesLibro(int libroId) async {
    final db = await getDatabase();
    return await db.delete(
      'traducciones',
      where: 'libro_id = ?',
      whereArgs: [libroId],
    );
  }

  // =========================
  // CRUD Marcadores
  // =========================

  static Future<int> insertarMarcador(
    int libroId,
    int pagina, {
    String? titulo,
    String? nota,
  }) async {
    final db = await getDatabase();
    return await db.insert('marcadores', {
      'libro_id': libroId,
      'pagina': pagina,
      'titulo': titulo,
      'nota': nota,
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerMarcadores(int libroId) async {
    final db = await getDatabase();
    return await db.query(
      'marcadores',
      where: 'libro_id = ?',
      whereArgs: [libroId],
      orderBy: 'pagina ASC',
    );
  }

  static Future<int> borrarMarcador(int id) async {
    final db = await getDatabase();
    return await db.delete(
      'marcadores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================
  // CRUD Resaltados - NUEVO
  // =========================

  static Future<int> insertarResaltado(
    int libroId,
    int pagina,
    String textoResaltado,
    int posicionInicio,
    int posicionFin, {
    String color = '#FFFF00',
    String tipo = 'highlight',
    String? nota,
  }) async {
    final db = await getDatabase();
    return await db.insert('resaltados', {
      'libro_id': libroId,
      'pagina': pagina,
      'texto_resaltado': textoResaltado,
      'posicion_inicio': posicionInicio,
      'posicion_fin': posicionFin,
      'color': color,
      'tipo': tipo,
      'nota': nota,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerResaltados(int libroId) async {
    final db = await getDatabase();
    return await db.query(
      'resaltados',
      where: 'libro_id = ?',
      whereArgs: [libroId],
      orderBy: 'pagina ASC, posicion_inicio ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> obtenerResaltadosPagina(
    int libroId,
    int pagina,
  ) async {
    final db = await getDatabase();
    return await db.query(
      'resaltados',
      where: 'libro_id = ? AND pagina = ?',
      whereArgs: [libroId, pagina],
      orderBy: 'posicion_inicio ASC',
    );
  }

  static Future<int> actualizarResaltado(
    int id, {
    String? nota,
    String? color,
    String? tipo,
  }) async {
    final db = await getDatabase();
    Map<String, dynamic> values = {};
    
    if (nota != null) values['nota'] = nota;
    if (color != null) values['color'] = color;
    if (tipo != null) values['tipo'] = tipo;
    
    if (values.isEmpty) return 0;
    
    return await db.update(
      'resaltados',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> borrarResaltado(int id) async {
    final db = await getDatabase();
    return await db.delete(
      'resaltados',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> borrarResaltadosLibro(int libroId) async {
    final db = await getDatabase();
    return await db.delete(
      'resaltados',
      where: 'libro_id = ?',
      whereArgs: [libroId],
    );
  }

  // Buscar resaltados por texto
  static Future<List<Map<String, dynamic>>> buscarResaltados(
    int libroId,
    String textoBusqueda,
  ) async {
    final db = await getDatabase();
    return await db.query(
      'resaltados',
      where: 'libro_id = ? AND (texto_resaltado LIKE ? OR nota LIKE ?)',
      whereArgs: [libroId, '%$textoBusqueda%', '%$textoBusqueda%'],
      orderBy: 'pagina ASC, posicion_inicio ASC',
    );
  }

  // Obtener estadísticas de resaltados
  static Future<Map<String, dynamic>> obtenerEstadisticasResaltados(int libroId) async {
    final db = await getDatabase();
    
    final total = await db.rawQuery(
      'SELECT COUNT(*) as count FROM resaltados WHERE libro_id = ?',
      [libroId],
    );
    
    final porTipo = await db.rawQuery(
      'SELECT tipo, COUNT(*) as count FROM resaltados WHERE libro_id = ? GROUP BY tipo',
      [libroId],
    );
    
    final porColor = await db.rawQuery(
      'SELECT color, COUNT(*) as count FROM resaltados WHERE libro_id = ? GROUP BY color',
      [libroId],
    );
    
    return {
      'total': total.first['count'],
      'por_tipo': porTipo,
      'por_color': porColor,
    };
  }
}
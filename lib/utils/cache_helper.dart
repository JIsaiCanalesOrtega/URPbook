import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class CacheHelper {
  /// Genera hash del contenido original del documento
  static String generarHash(List<String> paginas) {
    final joined = paginas.join('\n');
    return sha256.convert(utf8.encode(joined)).toString();
  }

  /// Ruta al archivo cacheado basado en el hash
  static Future<File> _archivoDeCache(String hash) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$hash.json');
  }

  static Future<void> guardarTraduccion(String hash, List<String> paginas) async {
    final file = await _archivoDeCache(hash);
    await file.writeAsString(json.encode(paginas));
  }

  static Future<List<String>?> cargarTraduccion(String hash) async {
    final file = await _archivoDeCache(hash);
    if (await file.exists()) {
      final content = await file.readAsString();
      final data = json.decode(content);
      return (data as List).map((e) => e.toString()).toList();
    }
    return null;
  }
}

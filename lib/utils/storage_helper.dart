// utils/storage_helper.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static const _keyArchivosRecientes = 'archivos_recientes';
  static const _maxArchivos = 10;

  /// Carga la lista de archivos recientes desde SharedPreferences
  static Future<List<String>> cargarArchivosRecientes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyArchivosRecientes) ?? '[]';
    final decoded = json.decode(jsonString);

    if (decoded is List) {
      return decoded.map<String>((archivo) {
        return archivo is Map ? (archivo['path'] ?? archivo) : archivo.toString();
      }).toList();
    }
    return [];
  }

  /// Guarda la lista de archivos recientes en SharedPreferences
  static Future<void> guardarArchivosRecientes(List<String> archivos) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(archivos);
    await prefs.setString(_keyArchivosRecientes, jsonString);
  }

  /// Agrega un archivo reciente y lo guarda, evitando duplicados
  static Future<List<String>> agregarArchivoReciente(List<String> actuales, String nuevo) async {
    if (!actuales.contains(nuevo)) {
      actuales.insert(0, nuevo);
      if (actuales.length > _maxArchivos) {
        actuales = actuales.sublist(0, _maxArchivos);
      }
      await guardarArchivosRecientes(actuales);
    }
    return actuales;
  }

  /// Elimina un archivo de la lista reciente y guarda
  static Future<List<String>> eliminarArchivoReciente(List<String> actuales, int index) async {
    actuales.removeAt(index);
    await guardarArchivosRecientes(actuales);
    return actuales;
  }
}

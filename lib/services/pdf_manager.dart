// services/pdf_manager.dart

import 'dart:io';
import '../utils/db_helper.dart';
import '../utils/storage_helper.dart';

class PdfManager {
  
  /// Elimina un PDF completamente del sistema
  static Future<bool> eliminarPDF({
    required int libroId,
    required String rutaPdf,
    required String nombreArchivo,
  }) async {
    try {
      // 1. Eliminar todas las traducciones del libro
      await DBHelper.borrarTraduccionesLibro(libroId);
      
      // 2. Eliminar todos los marcadores del libro
      final marcadores = await DBHelper.obtenerMarcadores(libroId);
      for (var marcador in marcadores) {
        await DBHelper.borrarMarcador(marcador['id']);
      }
      
      // 3. Eliminar todos los resaltados del libro
      await DBHelper.borrarResaltadosLibro(libroId);
      
      // 4. Eliminar el registro del libro de la base de datos
      await DBHelper.borrarLibro(libroId);
      
      // 5. Eliminar de archivos recientes
      final archivosRecientes = await StorageHelper.cargarArchivosRecientes();
      archivosRecientes.remove(rutaPdf);
      await StorageHelper.guardarArchivosRecientes(archivosRecientes);
      
      // 6. Eliminar archivo físico (opcional - puede fallar si no existe)
      try {
        final archivo = File(rutaPdf);
        if (await archivo.exists()) {
          await archivo.delete();
        }
      } catch (e) {
        // No es crítico si no se puede eliminar el archivo físico
        print('No se pudo eliminar el archivo físico: $e');
      }
      
      return true;
      
    } catch (e) {
      print('Error al eliminar PDF: $e');
      return false;
    }
  }
  
  /// Elimina solo el registro de archivos recientes
  static Future<bool> eliminarDeRecientes(String rutaPdf) async {
    try {
      final archivosRecientes = await StorageHelper.cargarArchivosRecientes();
      archivosRecientes.remove(rutaPdf);
      await StorageHelper.guardarArchivosRecientes(archivosRecientes);
      return true;
    } catch (e) {
      print('Error al eliminar de recientes: $e');
      return false;
    }
  }
  
  /// Obtiene información detallada de un PDF
  static Future<Map<String, dynamic>?> obtenerInfoPDF(int libroId) async {
    try {
      final libros = await DBHelper.obtenerLibros();
      final libro = libros.firstWhere(
        (l) => l['id'] == libroId,
        orElse: () => <String, dynamic>{},
      );
      
      if (libro.isEmpty) return null;
      
      // Contar elementos relacionados
      final marcadores = await DBHelper.obtenerMarcadores(libroId);
      final resaltados = await DBHelper.obtenerResaltados(libroId);
      final traducciones = await DBHelper.obtenerTraducciones(libroId);
      
      // Verificar si el archivo físico existe
      final archivoExiste = await File(libro['ruta_pdf']).exists();
      
      return {
        'libro': libro,
        'archivo_existe': archivoExiste,
        'total_marcadores': marcadores.length,
        'total_resaltados': resaltados.length,
        'esta_traducido': traducciones.isNotEmpty,
        'total_paginas_traducidas': traducciones.length,
      };
      
    } catch (e) {
      print('Error al obtener info del PDF: $e');
      return null;
    }
  }
}
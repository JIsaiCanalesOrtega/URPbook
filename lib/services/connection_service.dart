// services/connection_service.dart

import 'dart:io';

class ConnectionService {
  /// Verifica si hay conexión a Internet intentando acceder a google.com
  static Future<bool> verificarConexion() async {
    try {
      final resultado = await InternetAddress.lookup('google.com');
      return resultado.isNotEmpty && resultado[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}


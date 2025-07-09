import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../services/connection_service.dart';

/// Servicio para traducir textos usando el endpoint público de Google Translate.
/// Versión optimizada para mayor velocidad y eficiencia.
class TranslateService {
  /// Configuración optimizada
  static const int maxCharsPerBlock = 4500; // Aumentado para menos requests
  static const int maxConcurrentRequests = 5; // Más paralelismo
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 12);
  
  /// Cliente HTTP reutilizable para mejor rendimiento
  static final http.Client _httpClient = http.Client();
  
  /// Cache simple para evitar retraducciones
  final Map<String, String> _cache = {};
  
  /// Constructor
  TranslateService();

  /// Traduce un solo texto usando Google Translate con retry automático.
  /// Si 'origen' es nulo, intenta detectar el idioma automáticamente.
  Future<String> traducir(String texto, String destino, {String origen = "auto"}) async {
    if (texto.trim().isEmpty) return '';
    
    // Verificar cache simple
    final cacheKey = '$origen-$destino-${texto.hashCode}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    Exception? lastException;
    
    // Retry con backoff exponencial
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final uri = Uri.parse(
          'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=$origen&tl=$destino&dt=t&q=${Uri.encodeComponent(texto)}',
        );

        final response = await _httpClient.get(uri).timeout(requestTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data != null && data[0] != null) {
            final resultado = (data[0] as List)
                .where((e) => e != null && e[0] != null)
                .map((e) => e[0].toString())
                .join();
            
            // Guardar en cache
            _cache[cacheKey] = resultado;
            return resultado;
          }
          return '';
        } else if (response.statusCode == 429) {
          // Rate limiting - esperar más tiempo
          await Future.delayed(Duration(seconds: pow(2, attempt + 1).toInt()));
          continue;
        } else {
          throw Exception('Error HTTP ${response.statusCode}');
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Esperar antes del retry (exponential backoff)
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 300 * pow(2, attempt).toInt()));
        }
      }
    }
    
    throw lastException ?? Exception('Error en la traducción después de $maxRetries intentos');
  }

  /// Traduce una lista de textos por lotes con procesamiento paralelo optimizado.
  /// Usa [onProgress] para informar el avance al UI.
  /// Lanza una excepción si no hay conexión.
  Future<List<String>> traducirPaginas(
    List<String> textos,
    String destino, {
    String origen = "auto",
    void Function(int count)? onProgress,
  }) async {
    if (textos.isEmpty) return [];
    
    if (!await ConnectionService.verificarConexion()) {
      throw Exception('No hay conexión a Internet');
    }

    // Crear bloques optimizados
    final bloques = _crearBloquesMejorados(textos);
    final resultado = List<String>.filled(textos.length, '', growable: false);
    
    // Controlar concurrencia manualmente
    final futures = <Future<void>>[];
    final semaforo = <bool>[];
    
    // Inicializar semáforo
    for (int i = 0; i < maxConcurrentRequests; i++) {
      semaforo.add(false);
    }
    
    int procesados = 0;
    
    // Procesar bloques en paralelo
    for (final bloque in bloques) {
      // Esperar por un slot disponible
      while (semaforo.every((ocupado) => ocupado)) {
        await Future.delayed(Duration(milliseconds: 10));
      }
      
      // Encontrar slot libre
      final slotIndex = semaforo.indexWhere((ocupado) => !ocupado);
      semaforo[slotIndex] = true;
      
      final future = _procesarBloque(bloque, destino, origen, resultado).then((_) {
        semaforo[slotIndex] = false;
        procesados += bloque.indices.length;
        onProgress?.call(procesados);
      }).catchError((error) {
        semaforo[slotIndex] = false;
        throw error;
      });
      
      futures.add(future);
    }
    
    // Esperar a que terminen todos
    await Future.wait(futures);
    
    return resultado;
  }
  
  /// Procesa un bloque individual
  Future<void> _procesarBloque(
    _TextBlock bloque,
    String destino,
    String origen,
    List<String> resultado,
  ) async {
    final textoTraducido = await traducir(bloque.texto, destino, origen: origen);
    
    // Dividir usando separadores únicos
    final traducciones = _dividirTraducciones(textoTraducido, bloque.separadores);
    
    // Asignar traducciones a las posiciones correctas
    for (int i = 0; i < bloque.indices.length && i < traducciones.length; i++) {
      resultado[bloque.indices[i]] = traducciones[i];
    }
  }
  
  /// Crea bloques optimizados con separadores únicos
  List<_TextBlock> _crearBloquesMejorados(List<String> textos) {
    final bloques = <_TextBlock>[];
    String buffer = '';
    List<int> indices = [];
    List<String> separadores = [];
    
    for (int i = 0; i < textos.length; i++) {
      final texto = textos[i].trim();
      if (texto.isEmpty) continue;
      
      // Crear separador único
      final separador = '\n||SEP_${i}_${DateTime.now().millisecondsSinceEpoch}||\n';
      
      // Verificar si agregar este texto excede el límite
      final textoConSeparador = buffer.isEmpty ? texto : '$separador$texto';
      
      if (buffer.length + textoConSeparador.length > maxCharsPerBlock && buffer.isNotEmpty) {
        // Crear bloque actual
        bloques.add(_TextBlock(
          texto: buffer,
          indices: List.from(indices),
          separadores: List.from(separadores),
        ));
        
        // Resetear para nuevo bloque
        buffer = texto;
        indices = [i];
        separadores = [];
      } else {
        // Agregar al bloque actual
        if (buffer.isNotEmpty) {
          buffer += separador;
          separadores.add(separador);
        }
        buffer += texto;
        indices.add(i);
      }
    }
    
    // Agregar último bloque si no está vacío
    if (buffer.isNotEmpty) {
      bloques.add(_TextBlock(
        texto: buffer,
        indices: indices,
        separadores: separadores,
      ));
    }
    
    return bloques;
  }
  
  /// Divide las traducciones usando separadores únicos
  List<String> _dividirTraducciones(String textoTraducido, List<String> separadores) {
    if (separadores.isEmpty) return [textoTraducido];
    
    final traducciones = <String>[];
    String remaining = textoTraducido;
    
    for (final separador in separadores) {
      final index = remaining.indexOf(separador);
      if (index != -1) {
        traducciones.add(remaining.substring(0, index).trim());
        remaining = remaining.substring(index + separador.length);
      } else {
        // Si no encuentra el separador, dividir por el separador más simple
        final simpleSep = separador.replaceAll(RegExp(r'[^\n|]'), '');
        final simpleIndex = remaining.indexOf(simpleSep);
        if (simpleIndex != -1) {
          traducciones.add(remaining.substring(0, simpleIndex).trim());
          remaining = remaining.substring(simpleIndex + simpleSep.length);
        }
      }
    }
    
    // Agregar el último segmento
    if (remaining.isNotEmpty) {
      traducciones.add(remaining.trim());
    }
    
    return traducciones;
  }
  
  /// Limpia la cache para liberar memoria
  void limpiarCache() {
    _cache.clear();
  }
  
  /// Cierra el cliente HTTP
  void dispose() {
    _httpClient.close();
    _cache.clear();
  }
}

/// Clase interna para representar un bloque de texto
class _TextBlock {
  final String texto;
  final List<int> indices;
  final List<String> separadores;
  
  _TextBlock({
    required this.texto,
    required this.indices,
    required this.separadores,
  });
}
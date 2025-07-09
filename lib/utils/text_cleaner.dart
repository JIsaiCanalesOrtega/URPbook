// utils/text_cleaner_improved.dart

/// Limpiador de texto PDF mejorado con enfoque conservador
/// Versión corregida que preserva la integridad del texto original

class TextCleaner {
  // Configuración personalizable
  static const int minLineLength = 2;
  static const int maxLineLength = 2000;
  static const double minWordRatio = 0.2; // Ratio más permisivo
  
  /// Punto de entrada principal para limpiar texto
  static String limpiarTexto(String texto) {
    if (texto.isEmpty) return '';
    
    // Pipeline de limpieza más conservador
    texto = _preprocesarTexto(texto);
    texto = _normalizarCaracteresBasicos(texto);
    texto = _eliminarElementosEstructurales(texto);
    texto = _corregirEspaciadoBasico(texto);
    texto = _unirLineasPartidasConservador(texto);
    texto = _eliminarLineasRuidoConservador(texto);
    texto = _limpiezaFinal(texto);
    
    return texto.trim();
  }
  
  /// Preprocesamiento básico más conservador
  static String _preprocesarTexto(String texto) {
    return texto
        // Solo eliminar caracteres de control realmente problemáticos
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        // Normalizar saltos de línea
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        // Solo espacios no-break básicos
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2009', ' ')
        .replaceAll('\u202F', ' ');
  }
  
  /// Normalización básica de caracteres (más conservadora)
  static String _normalizarCaracteresBasicos(String texto) {
    return texto
        // Solo las comillas más problemáticas
        .replaceAll(RegExp(r'[""„«»]'), '"')
        .replaceAll(RegExp(r'[''`]'), "'")
        // Solo guiones largos problemáticos
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        // Puntos suspensivos
        .replaceAll('…', '...')
        // Espacios múltiples
        .replaceAll(RegExp(r'  +'), ' ');
  }
  
  /// Eliminación conservadora de elementos estructurales
  static String _eliminarElementosEstructurales(String texto) {
    return texto
        // Solo números de página muy obvios
        .replaceAll(RegExp(r'^\s*\d+\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[Pp]ágina\s+\d+\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\s+de\s+\d+\s*$', multiLine: true), '')
        
        // Líneas con solo guiones o símbolos
        .replaceAll(RegExp(r'^\s*[-_=]{3,}\s*$', multiLine: true), '')
        
        // URLs completas en líneas separadas
        .replaceAll(RegExp(r'^\s*https?://[^\s]+\s*$', multiLine: true), '')
        
        // Fechas solas muy específicas
        .replaceAll(RegExp(r'^\s*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\s*$', multiLine: true), '');
  }
  
  /// Corrección de espaciado básico SIN correcciones OCR agresivas
  static String _corregirEspaciadoBasico(String texto) {
    return texto
        // Eliminar espacios antes de signos de puntuación
        .replaceAll(RegExp(r' +([,.!?;:])'), r'$1')
        // Asegurar espacio después de puntuación (solo si no hay)
        .replaceAll(RegExp(r'([,.!?;:])([A-Za-zÁÉÍÓÚáéíóúüñÑ])'), r'$1 $2')
        // Espacios alrededor de paréntesis
        .replaceAll(RegExp(r'\( +'), '(')
        .replaceAll(RegExp(r' +\)'), ')')
        // Espacios múltiples
        .replaceAll(RegExp(r' +'), ' ');
  }
  
  /// Unión conservadora de líneas partidas (solo casos muy seguros)
  static String _unirLineasPartidasConservador(String texto) {
    // Solo unir palabras obviamente partidas con guión
    texto = texto.replaceAllMapped(
        RegExp(r'([a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]+)-\s*\n\s*([a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]+)'), 
        (m) => '${m[1]}${m[2]}');
    
    // Solo unir líneas que terminan con conectores muy obvios
    texto = texto.replaceAllMapped(
      RegExp(r'\b(el|la|los|las|un|una|de|del|en|con|y|o|que|se|no|es|más|por|su|le|da|ha|su|al|lo|me|te|le|nos|os|les)\s*\n\s*([a-zA-ZáéíóúüñÁÉÍÓÚÜÑ])', caseSensitive: false),
      (m) => '${m[1]} ${m[2]}',
    );
    
    return texto;
  }
  
  /// Eliminación muy conservadora de líneas ruido
  static String _eliminarLineasRuidoConservador(String texto) {
    List<String> lineas = texto.split('\n');
    List<String> limpias = [];
    
    for (String linea in lineas) {
      String trim = linea.trim();
      
      // Mantener líneas vacías para preservar estructura
      if (trim.isEmpty) {
        limpias.add('');
        continue;
      }
      
      // Filtros muy conservadores
      if (trim.length < minLineLength) continue;
      if (trim.length > maxLineLength) continue;
      
      // Solo eliminar líneas que son obviamente ruido
      if (_esObviamenteRuido(trim)) continue;
      
      limpias.add(linea);
    }
    
    return limpias.join('\n');
  }
  
  /// Determina si una línea es obviamente ruido (muy conservador)
  static bool _esObviamenteRuido(String linea) {
    // Solo patrones muy específicos de ruido
    List<RegExp> patronesRuido = [
      RegExp(r'^\d+$'),                              // Solo un número
      RegExp(r'^[^\w\s]{3,}$'),                     // Solo símbolos (3 o más)
      RegExp(r'^[A-Z\s]{10,}$'),                    // Solo mayúsculas largas
      RegExp(r'^www\.'),                            // URLs incompletas
      RegExp(r'^https?://'),                        // URLs
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'), // Emails
      RegExp(r'^[ivxlcdm]+$', caseSensitive: false), // Solo números romanos
      RegExp(r'^[0-9\s\-\.]+$'),                    // Solo números y separadores
    ];
    
    return patronesRuido.any((patron) => patron.hasMatch(linea));
  }
  
  /// Limpieza final conservadora
  static String _limpiezaFinal(String texto) {
    return texto
        // Eliminar espacios al final de líneas
        .replaceAll(RegExp(r' +\n'), '\n')
        // Reducir múltiples saltos de línea (pero preservar párrafos)
        .replaceAll(RegExp(r'\n{4,}'), '\n\n\n')
        // Eliminar espacios al inicio y final
        .trim();
  }
  
  /// Método adicional para casos muy específicos donde el texto está muy dañado
  static String limpiarTextoAgresivo(String texto) {
    // Aquí puedes poner la lógica más agresiva para casos específicos
    // donde sepas que el texto necesita corrección fuerte
    return texto;
  }
  
  /// Método de conveniencia para mantener compatibilidad
  static String clean(String texto) => limpiarTexto(texto);
}

// Función independiente para mantener compatibilidad
String limpiarTexto(String texto) {
  return TextCleaner.limpiarTexto(texto);
}
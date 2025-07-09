import 'package:flutter/material.dart';

/// Widget visor de PDF basado en texto extraído página por página.
/// Permite avanzar/retroceder, ajustar fuente y muestra el estado.
/// Ahora también soporta resaltados y selección de texto.
class PdfViewer extends StatelessWidget {
  final List<String> paginas;
  final int paginaActual;
  final double fontSize;
  final void Function(int nuevaPagina) onPageChanged;

  // ======= NUEVOS PARÁMETROS =======
  final List<Map<String, dynamic>> resaltados;
  final bool modoResaltado;
  final void Function(String textoSeleccionado, int inicio, int fin)? onTextoSeleccionado;

  const PdfViewer({
    super.key,
    required this.paginas,
    required this.paginaActual,
    required this.fontSize,
    required this.onPageChanged,
    this.resaltados = const [], // <--- por si no pasas nada, vacío
    this.modoResaltado = false,
    this.onTextoSeleccionado,
  });

  // Método auxiliar para convertir valores de la BD a int de forma segura
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  // Método auxiliar para convertir colores de forma segura
  Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return const Color(0xFFFFFF00); // Amarillo por defecto
    
    String colorStr = colorValue.toString();
    if (!colorStr.startsWith('#')) {
      colorStr = '#$colorStr';
    }
    
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFFFFF00); // Amarillo por defecto si falla
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = (paginas.isNotEmpty && paginaActual >= 0 && paginaActual < paginas.length)
        ? paginas[paginaActual]
        : '(Sin contenido en esta página)';

    // Para el ejemplo: Resalta todos los textos destacados (subrayados) en amarillo, solo visual.
    // Puedes mejorar este render para mostrar resaltados "de verdad" por rango.
    TextSpan _buildTextSpan() {
      if (resaltados.isEmpty || texto.isEmpty) {
        return TextSpan(
          text: texto,
          style: TextStyle(fontSize: fontSize, height: 1.5, letterSpacing: 0.3),
        );
      }

      List<InlineSpan> children = [];
      int start = 0;

      // Ordena resaltados por inicio, para no solaparse mal
      final sorted = List<Map<String, dynamic>>.from(resaltados)
        ..sort((a, b) {
          final aInicio = _toInt(a['inicio']);
          final bInicio = _toInt(b['inicio']);
          return aInicio.compareTo(bInicio);
        });

      for (final r in sorted) {
        final int ini = _toInt(r['inicio']);
        final int fin = _toInt(r['fin']);
        
        // Validaciones de seguridad
        if (ini < 0 || fin < 0 || ini > texto.length || fin > texto.length || ini >= fin) {
          continue;
        }

        // Texto normal antes del resaltado
        if (ini > start) {
          children.add(TextSpan(
            text: texto.substring(start, ini),
            style: TextStyle(fontSize: fontSize, height: 1.5, letterSpacing: 0.3),
          ));
        }

        // Texto resaltado
        final backgroundColor = _parseColor(r['color']);
        final tipo = r['tipo']?.toString() ?? 'highlight';
        
        children.add(TextSpan(
          text: texto.substring(ini, fin),
          style: TextStyle(
            backgroundColor: backgroundColor,
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            height: 1.5,
            letterSpacing: 0.3,
            decoration: tipo == 'underline' ? TextDecoration.underline : null,
          ),
        ));
        start = fin;
      }
      
      // Texto que queda después del último resaltado
      if (start < texto.length) {
        children.add(TextSpan(
          text: texto.substring(start),
          style: TextStyle(fontSize: fontSize, height: 1.5, letterSpacing: 0.3),
        ));
      }

      return TextSpan(children: children);
    }

    return Column(
      children: [
        // Contenido de la página (scrollable)
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                // Deslizar a la izquierda = siguiente página
                if (details.primaryVelocity! < 0 && paginaActual < paginas.length - 1) {
                  onPageChanged(paginaActual + 1);
                }
                // Deslizar a la derecha = página anterior
                if (details.primaryVelocity! > 0 && paginaActual > 0) {
                  onPageChanged(paginaActual - 1);
                }
              },
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  _buildTextSpan(),
                  textAlign: TextAlign.justify,
                  onSelectionChanged: (selection, cause) {
                    // Solo si está en modo resaltado y hay callback
                    if (modoResaltado && 
                        onTextoSeleccionado != null && 
                        selection.baseOffset != selection.extentOffset) {
                      
                      final ini = selection.baseOffset;
                      final fin = selection.extentOffset;
                      
                      if (ini >= 0 && fin > ini && fin <= texto.length) {
                        final seleccionado = texto.substring(ini, fin);
                        onTextoSeleccionado!(seleccionado, ini, fin);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        // Barra de navegación de páginas
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Página anterior',
                onPressed: paginaActual > 0
                    ? () => onPageChanged(paginaActual - 1)
                    : null,
              ),
              Text('Página ${paginaActual + 1} de ${paginas.length}'),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Página siguiente',
                onPressed: paginaActual < paginas.length - 1
                    ? () => onPageChanged(paginaActual + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
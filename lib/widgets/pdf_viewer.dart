import 'package:flutter/material.dart';
import 'dart:async';

/// Widget visor de PDF con selección mejorada
/// CORREGIDO: Permite seleccionar múltiples palabras antes de mostrar el diálogo
class PdfViewer extends StatefulWidget {
  final List<String> paginas;
  final int paginaActual;
  final double fontSize;
  final void Function(int nuevaPagina) onPageChanged;
  final List<Map<String, dynamic>> resaltados;
  final bool modoResaltado;
  final void Function(String textoSeleccionado, int inicio, int fin)? onTextoSeleccionado;

  const PdfViewer({
    super.key,
    required this.paginas,
    required this.paginaActual,
    required this.fontSize,
    required this.onPageChanged,
    this.resaltados = const [],
    this.modoResaltado = false,
    this.onTextoSeleccionado,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  Timer? _selectionTimer;
  String? _pendingSelection;

  @override
  void dispose() {
    _selectionTimer?.cancel();
    super.dispose();
  }

  // Método para programar el callback con delay
  void _scheduleSelectionCallback(String selectedText) {
    // Cancelar timer previo si existe
    _selectionTimer?.cancel();
    
    // Guardar selección actual
    _pendingSelection = selectedText;
    
    // Programar callback con delay de 1.5 segundos
    _selectionTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_pendingSelection != null && widget.onTextoSeleccionado != null) {
        final texto = _getCurrentPageText();
        
        // Buscar la posición del texto seleccionado
        final startIndex = texto.indexOf(_pendingSelection!);
        if (startIndex != -1) {
          final endIndex = startIndex + _pendingSelection!.length;
          print('🖱️ Procesando selección: "$_pendingSelection"');
          print('📍 Posiciones: inicio=$startIndex, fin=$endIndex');
          widget.onTextoSeleccionado!(_pendingSelection!, startIndex, endIndex);
        }
        _pendingSelection = null;
      }
    });
  }

  String _getCurrentPageText() {
    return (widget.paginas.isNotEmpty && 
            widget.paginaActual >= 0 && 
            widget.paginaActual < widget.paginas.length)
        ? widget.paginas[widget.paginaActual]
        : '';
  }

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
    final texto = _getCurrentPageText();

    // CORREGIDO: Método para construir el texto con resaltados
    TextSpan _buildTextSpan() {
      if (widget.resaltados.isEmpty || texto.isEmpty) {
        return TextSpan(
          text: texto,
          style: TextStyle(
            fontSize: widget.fontSize, 
            height: 1.5, 
            letterSpacing: 0.3,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );
      }

      print('📝 Construyendo texto con ${widget.resaltados.length} resaltados');
      
      List<InlineSpan> children = [];
      int start = 0;

      // CORREGIDO: Usar los nombres correctos de los campos de la BD
      final sorted = List<Map<String, dynamic>>.from(widget.resaltados)
        ..sort((a, b) {
          final aInicio = _toInt(a['posicion_inicio']); // ✅ Nombre correcto
          final bInicio = _toInt(b['posicion_inicio']); // ✅ Nombre correcto
          return aInicio.compareTo(bInicio);
        });

      for (final r in sorted) {
        final int ini = _toInt(r['posicion_inicio']); // ✅ Nombre correcto
        final int fin = _toInt(r['posicion_fin']);     // ✅ Nombre correcto
        
        print('🎯 Procesando resaltado: inicio=$ini, fin=$fin, texto="${r['texto_resaltado']}"');
        
        // Validaciones de seguridad MEJORADAS
        if (ini < 0 || fin < 0 || ini > texto.length || fin > texto.length || ini >= fin) {
          print('❌ Resaltado inválido: ini=$ini, fin=$fin, textoLength=${texto.length}');
          continue;
        }

        // Verificar que el texto coincida (opcional, para debug)
        final textoResaltadoBD = r['texto_resaltado']?.toString() ?? '';
        final textoEnPosicion = texto.substring(ini, fin);
        if (textoResaltadoBD != textoEnPosicion) {
          print('⚠️ Texto no coincide. BD: "$textoResaltadoBD", Posición: "$textoEnPosicion"');
          // Aún así, continúa con el resaltado por posición
        }

        // Texto normal antes del resaltado
        if (ini > start) {
          children.add(TextSpan(
            text: texto.substring(start, ini),
            style: TextStyle(
              fontSize: widget.fontSize, 
              height: 1.5, 
              letterSpacing: 0.3,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ));
        }

        // MEJORADO: Texto resaltado con mejor styling
        final backgroundColor = _parseColor(r['color']);
        final tipo = r['tipo']?.toString() ?? 'highlight';
        
        // Calcular color de texto que contraste bien
        final brightness = backgroundColor.computeLuminance();
        final textColor = brightness > 0.5 ? Colors.black87 : Colors.white;
        
        children.add(TextSpan(
          text: texto.substring(ini, fin),
          style: TextStyle(
            backgroundColor: backgroundColor.withOpacity(0.7), // Más suave
            color: textColor, // Color que contrasta
            fontWeight: FontWeight.w600, // Menos bold pero destacado
            fontSize: widget.fontSize,
            height: 1.5,
            letterSpacing: 0.3,
            decoration: tipo == 'underline' ? TextDecoration.underline : null,
            decorationColor: backgroundColor,
            decorationThickness: 2.0,
          ),
        ));
        
        start = fin;
        print('✅ Resaltado aplicado correctamente');
      }
      
      // Texto que queda después del último resaltado
      if (start < texto.length) {
        children.add(TextSpan(
          text: texto.substring(start),
          style: TextStyle(
            fontSize: widget.fontSize, 
            height: 1.5, 
            letterSpacing: 0.3,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ));
      }

      print('🎨 TextSpan construido con ${children.length} elementos');
      return TextSpan(children: children);
    }

    return Column(
      children: [
        // Indicador mejorado de modo resaltado
        if (widget.modoResaltado)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo resaltado activo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Selecciona texto y espera un momento para resaltar',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Indicador de selección pendiente
                if (_pendingSelection != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Esperando...',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        // Contenido de la página (scrollable)
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onHorizontalDragEnd: !widget.modoResaltado ? (details) {
                if (details.primaryVelocity == null) return;
                // Deslizar a la izquierda = siguiente página
                if (details.primaryVelocity! < 0 && widget.paginaActual < widget.paginas.length - 1) {
                  widget.onPageChanged(widget.paginaActual + 1);
                }
                // Deslizar a la derecha = página anterior
                if (details.primaryVelocity! > 0 && widget.paginaActual > 0) {
                  widget.onPageChanged(widget.paginaActual - 1);
                }
              } : null,
              child: SelectionArea(
                onSelectionChanged: (selection) {
                  // Solo si está en modo resaltado
                  if (widget.modoResaltado && widget.onTextoSeleccionado != null && selection != null) {
                    final selectedText = selection.plainText.trim();
                    if (selectedText.isNotEmpty) {
                      // CORREGIDO: Agregar delay para permitir extender la selección
                      _scheduleSelectionCallback(selectedText);
                    } else {
                      // Cancelar si la selección se vuelve vacía
                      _selectionTimer?.cancel();
                      setState(() {
                        _pendingSelection = null;
                      });
                    }
                  }
                },
                child: SingleChildScrollView(
                  child: Text.rich(
                    _buildTextSpan(),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Barra de navegación de páginas
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Página anterior',
                    onPressed: widget.paginaActual > 0
                        ? () => widget.onPageChanged(widget.paginaActual - 1)
                        : null,
                  ),
                  // Mostrar información de resaltados en la página actual
                  if (widget.resaltados.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.highlight,
                            size: 16,
                            color: Colors.orange[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.resaltados.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Indicador de página con mejor styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Página ${widget.paginaActual + 1} de ${widget.paginas.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Página siguiente',
                onPressed: widget.paginaActual < widget.paginas.length - 1
                    ? () => widget.onPageChanged(widget.paginaActual + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
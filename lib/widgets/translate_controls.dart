// widgets/translate_controls.dart

import 'package:flutter/material.dart';

class TranslateControls extends StatelessWidget {
  final bool isTranslating;
  final bool mostrarRecientes;
  final bool isLoading;
  final bool documentoTraducido;
  final int paginaActual;
  final int totalPaginas;
  final VoidCallback onTraducir;
  final VoidCallback onCargarPDF;
  final VoidCallback? onAnterior;
  final VoidCallback? onSiguiente;
  final VoidCallback? onResetZoom;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const TranslateControls({
    super.key,
    required this.isTranslating,
    required this.mostrarRecientes,
    required this.isLoading,
    required this.documentoTraducido,
    required this.paginaActual,
    required this.totalPaginas,
    required this.onTraducir,
    required this.onCargarPDF,
    this.onAnterior,
    this.onSiguiente,
    this.onResetZoom,
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    if (mostrarRecientes || isLoading) {
      return FloatingActionButton(
        onPressed: onCargarPDF,
        tooltip: 'Cargar PDF',
        child: const Icon(Icons.upload_file),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isTranslating)
          FloatingActionButton(
            heroTag: "translate",
            onPressed: onTraducir,
            tooltip: 'Traducir Documento',
            backgroundColor: Colors.green,
            child: const Icon(Icons.translate),
          ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: "upload",
          onPressed: isTranslating ? null : onCargarPDF,
          tooltip: 'Cargar PDF',
          child: const Icon(Icons.upload_file),
        ),
        const SizedBox(height: 20),
        if (totalPaginas > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onZoomOut,
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Reducir zoom',
              ),
              IconButton(
                onPressed: onZoomIn,
                icon: const Icon(Icons.zoom_in),
                tooltip: 'Aumentar zoom',
              ),
              IconButton(
                onPressed: onResetZoom,
                icon: const Icon(Icons.refresh),
                tooltip: 'Restablecer zoom',
              ),
            ],
          ),
        if (totalPaginas > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onAnterior,
                tooltip: 'Página anterior',
              ),
              Text('${paginaActual + 1}/$totalPaginas'),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: onSiguiente,
                tooltip: 'Página siguiente',
              ),
            ],
          ),
      ],
    );
  }
}
// This widget provides controls for translating, loading PDFs, and navigating through pages.
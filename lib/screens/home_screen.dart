import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../services/pdf_service.dart';
import '../services/translate_service.dart';
import '../services/pdf_manager.dart';
import '../utils/storage_helper.dart';
import '../widgets/pdf_viewer.dart';
import '../widgets/pdf_delete_dialog.dart';
import '../utils/db_helper.dart';
import '../utils/theme_provider.dart';
import '../utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Estado principal
  List<String> paginas = [];
  List<String> paginasOriginales = [];
  int paginaActual = 0;
  int libroIdActual = -1;
  
  // Estados de carga
  bool isLoading = false;
  bool isTranslating = false;
  bool documentoTraducido = false;
  bool mostrandoTraduccion = false; // Nuevo estado para controlar qué versión mostrar
  
  // Configuración y UI
  double fontSize = 18.0;
  List<String> archivosRecientes = [];
  String? archivoActual;
  
  // Marcadores y resaltados
  List<Map<String, dynamic>> marcadores = [];
  List<Map<String, dynamic>> resaltados = [];
  List<Map<String, dynamic>> resaltadosPaginaActual = [];
  bool mostrarMarcadores = false;
  bool mostrarResaltados = false;
  bool modoResaltado = false;
  String colorResaltadoActual = '#FFFF00';
  String tipoResaltadoActual = 'highlight';
  
  final TranslateService _translator = TranslateService();
  
  static const Map<String, String> coloresResaltado = {
    'Amarillo': '#FFFF00', 'Verde': '#90EE90', 'Azul': '#87CEEB',
    'Rosa': '#FFB6C1', 'Naranja': '#FFA500', 'Violeta': '#DDA0DD',
  };

  @override
  void initState() {
    super.initState();
    _cargarArchivosRecientes();
  }

  // === MÉTODOS DE UTILIDAD ===
  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: esError ? AppTheme.getErrorColor(context) : AppTheme.getSuccessColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _limpiarDatos() {
    setState(() {
      paginas.clear();
      paginasOriginales.clear();
      marcadores.clear();
      resaltados.clear();
      resaltadosPaginaActual.clear();
      paginaActual = 0;
      libroIdActual = -1;
      archivoActual = null;
      documentoTraducido = false;
      mostrandoTraduccion = false;
      mostrarMarcadores = false;
      mostrarResaltados = false;
      modoResaltado = false;
    });
  }

  // Método mejorado para navegar a la página principal
  void _irAInicio() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _cambiarIdioma() {
    if (!documentoTraducido) {
      _mostrarMensaje('Primero debes traducir el documento', esError: true);
      return;
    }
    
    setState(() {
      mostrandoTraduccion = !mostrandoTraduccion;
      // Actualizar las páginas mostradas según el idioma seleccionado
      // Las páginas ya contienen la traducción cuando documentoTraducido = true
    });
    
    _mostrarMensaje(mostrandoTraduccion ? 'Mostrando traducción' : 'Mostrando original');
  }

  bool _paginaTieneMarcador() => marcadores.any((m) => m['pagina'] == paginaActual);
  bool _paginaTieneResaltados() => resaltadosPaginaActual.isNotEmpty;

  // === MÉTODOS DE CARGA ===
  Future<void> _cargarArchivosRecientes() async {
    try {
      final recientes = await StorageHelper.cargarArchivosRecientes();
      setState(() => archivosRecientes = recientes);
    } catch (e) {
      _mostrarMensaje('Error al cargar archivos recientes: $e', esError: true);
    }
  }

  Future<void> _cargarMarcadores() async {
    if (libroIdActual == -1) return;
    try {
      final marcadoresLibro = await DBHelper.obtenerMarcadores(libroIdActual);
      setState(() => marcadores = marcadoresLibro);
    } catch (e) {
      _mostrarMensaje('Error al cargar marcadores: $e', esError: true);
    }
  }

  Future<void> _cargarResaltados() async {
    if (libroIdActual == -1) return;
    try {
      final resaltadosLibro = await DBHelper.obtenerResaltados(libroIdActual);
      final resaltadosPagina = await DBHelper.obtenerResaltadosPagina(libroIdActual, paginaActual);
      setState(() {
        resaltados = resaltadosLibro;
        resaltadosPaginaActual = resaltadosPagina;
      });
    } catch (e) {
      _mostrarMensaje('Error al cargar resaltados: $e', esError: true);
    }
  }

  Future<int> _obtenerOLibroInsertado(String titulo, String ruta, {String? autor}) async {
    if (titulo.trim().isEmpty || ruta.trim().isEmpty) {
      throw ArgumentError('Título y ruta no pueden estar vacíos');
    }
    
    final libros = await DBHelper.obtenerLibros();
    for (var libro in libros) {
      if (libro['ruta_pdf'] == ruta) return libro['id'];
    }
    return await DBHelper.insertarLibro(titulo, autor ?? '', ruta);
  }

  // === MÉTODOS PDF ===
  Future<void> _cargarPDF({String? path}) async {
    setState(() {
      isLoading = true;
      _limpiarDatos();
    });

    try {
      if (path == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result?.files.single.path == null) {
          setState(() => isLoading = false);
          return;
        }
        path = result!.files.single.path!;
        await StorageHelper.agregarArchivoReciente(archivosRecientes, path);
        await _cargarArchivosRecientes();
      }

      // CORREGIDO: Eliminadas las advertencias de null-safety
      final nombreArchivo = path.split('/').last;
      archivoActual = nombreArchivo;
      libroIdActual = await _obtenerOLibroInsertado(nombreArchivo, path);
      
      paginas = await PdfService.leerPaginas(path);
      paginasOriginales = List.from(paginas);
      
      // Cargar traducciones existentes
      final traduccionesGuardadas = await DBHelper.obtenerTraducciones(libroIdActual);
      if (traduccionesGuardadas.isNotEmpty) {
        final paginasTraducidas = traduccionesGuardadas.map((e) => e['texto_traducido'] as String).toList();
        documentoTraducido = true;
        mostrandoTraduccion = true;
        paginas = paginasTraducidas;
      }

      await _cargarMarcadores();
      await _cargarResaltados();
      
      setState(() {
        isLoading = false;
        archivoActual = nombreArchivo;
      });
      
      _mostrarMensaje('PDF cargado: $nombreArchivo');
    } catch (e) {
      setState(() => isLoading = false);
      _mostrarMensaje('Error al cargar PDF: $e', esError: true);
    }
  }

  Future<void> _traducirDocumento() async {
    // Verificar si ya existe una traducción
    if (documentoTraducido) {
      _mostrarMensaje('Este documento ya está traducido', esError: true);
      return;
    }

    setState(() => isTranslating = true);
    try {
      List<String> traducidas = [];
      for (int i = 0; i < paginasOriginales.length; i++) {
        final textoTraducido = await _translator.traducir(paginasOriginales[i], 'es');
        traducidas.add(textoTraducido);
        await DBHelper.insertarTraduccion(
          libroIdActual, i, paginasOriginales[i], textoTraducido,
          DateTime.now().toIso8601String(),
        );
      }
      setState(() {
        paginas = traducidas;
        documentoTraducido = true;
        mostrandoTraduccion = true;
        isTranslating = false;
      });
      _mostrarMensaje('Documento traducido y guardado');
    } catch (e) {
      setState(() => isTranslating = false);
      _mostrarMensaje('Error al traducir: $e', esError: true);
    }
  }

  // === NAVEGACIÓN ===
  void _cambiarPagina(int nuevaPagina) {
    if (nuevaPagina < 0 || nuevaPagina >= paginas.length) {
      _mostrarMensaje('Página inválida', esError: true);
      return;
    }
    setState(() => paginaActual = nuevaPagina);
    _cargarResaltados();
  }

  void _cambiarFontSize(bool aumentar) {
    setState(() {
      fontSize += aumentar ? 2 : -2;
      fontSize = fontSize.clamp(10.0, 40.0);
    });
  }

  // === MARCADORES ===
  Future<void> _agregarMarcador() async {
    if (libroIdActual == -1 || _paginaTieneMarcador()) return;

    final resultado = await _mostrarDialogo(
      titulo: 'Agregar Marcador - Página ${paginaActual + 1}',
      campos: [
        {'label': 'Título del marcador', 'hint': 'Ej: Capítulo importante', 'required': true},
        {'label': 'Nota (opcional)', 'hint': 'Agrega una nota personal...', 'maxLines': 3},
      ],
    );
    
    if (resultado == null) return;

    try {
      await DBHelper.insertarMarcador(
        libroIdActual, paginaActual,
        titulo: resultado[0],
        // CORREGIDO: Lógica simplificada
        nota: resultado[1].isEmpty ? null : resultado[1],
      );
      await _cargarMarcadores();
      _mostrarMensaje('Marcador agregado exitosamente');
    } catch (e) {
      _mostrarMensaje('Error al agregar marcador: $e', esError: true);
    }
  }

  Future<void> _eliminarMarcador(int marcadorId) async {
    try {
      await DBHelper.borrarMarcador(marcadorId);
      await _cargarMarcadores();
      _mostrarMensaje('Marcador eliminado');
    } catch (e) {
      _mostrarMensaje('Error al eliminar marcador: $e', esError: true);
    }
  }

  // === RESALTADOS ===
  Future<void> _crearResaltado(String textoSeleccionado, int inicio, int fin) async {
    if (libroIdActual == -1 || textoSeleccionado.trim().isEmpty) return;
    
    if (inicio < 0 || fin < inicio) {
      _mostrarMensaje('Selección de texto inválida', esError: true);
      return;
    }

    final resultado = await _mostrarDialogoResaltado(textoSeleccionado);
    if (resultado == null) return;

    try {
      await DBHelper.insertarResaltado(
        libroIdActual, paginaActual, textoSeleccionado, inicio, fin,
        color: resultado['color'],
        tipo: resultado['tipo'],
        nota: resultado['nota'].isEmpty ? null : resultado['nota'],
      );
      
      setState(() {
        colorResaltadoActual = resultado['color'];
        tipoResaltadoActual = resultado['tipo'];
      });
      
      await _cargarResaltados();
      _mostrarMensaje('Resaltado creado exitosamente');
    } catch (e) {
      _mostrarMensaje('Error al crear resaltado: $e', esError: true);
    }
  }

  Future<void> _eliminarResaltado(int resaltadoId) async {
    try {
      await DBHelper.borrarResaltado(resaltadoId);
      await _cargarResaltados();
      _mostrarMensaje('Resaltado eliminado');
    } catch (e) {
      _mostrarMensaje('Error al eliminar resaltado: $e', esError: true);
    }
  }

  // === MÉTODOS DE ELIMINACIÓN ===
  
  /// Elimina un PDF solo de la lista de recientes
  Future<void> _eliminarDeRecientes(String rutaPdf, String nombreArchivo) async {
    final confirmar = await PdfDeleteDialog.mostrarDialogoEliminarDeRecientes(
      context: context,
      nombreArchivo: nombreArchivo,
    );
    
    if (confirmar == true) {
      final exito = await PdfManager.eliminarDeRecientes(rutaPdf);
      
      if (exito) {
        await _cargarArchivosRecientes(); // Recargar la lista
        _mostrarMensaje('Eliminado de archivos recientes');
      } else {
        _mostrarMensaje('Error al eliminar de recientes', esError: true);
      }
    }
  }
  
  /// Elimina un PDF completamente del sistema
  Future<void> _eliminarPDFCompleto(String rutaPdf, String nombreArchivo) async {
    // Buscar el libro en la base de datos
    final libros = await DBHelper.obtenerLibros();
    final libro = libros.firstWhere(
      (l) => l['ruta_pdf'] == rutaPdf,
      orElse: () => <String, dynamic>{},
    );
    
    if (libro.isEmpty) {
      // Si no está en BD, solo eliminar de recientes
      await _eliminarDeRecientes(rutaPdf, nombreArchivo);
      return;
    }
    
    final libroId = libro['id'] as int;
    
    final confirmar = await PdfDeleteDialog.mostrarDialogoEliminar(
      context: context,
      nombreArchivo: nombreArchivo,
      libroId: libroId,
    );
    
    if (confirmar == true) {
      // Mostrar diálogo de progreso
      PdfDeleteDialog.mostrarDialogoProgreso(context);
      
      final exito = await PdfManager.eliminarPDF(
        libroId: libroId,
        rutaPdf: rutaPdf,
        nombreArchivo: nombreArchivo,
      );
      
      // Cerrar diálogo de progreso
      Navigator.of(context).pop();
      
      if (exito) {
        await _cargarArchivosRecientes(); // Recargar la lista
        _mostrarMensaje('PDF eliminado completamente');
        
        // Si estamos viendo este PDF, limpiar la vista
        if (archivoActual != null && archivoActual == nombreArchivo) {
          _limpiarDatos();
        }
      } else {
        _mostrarMensaje('Error al eliminar PDF', esError: true);
      }
    }
  }

  // === DIÁLOGOS ===
  Future<List<String>?> _mostrarDialogo({
    required String titulo,
    required List<Map<String, dynamic>> campos,
  }) async {
    final controllers = campos.map((c) => TextEditingController()).toList();

    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: campos.asMap().entries.map((entry) {
            final i = entry.key;
            final campo = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: controllers[i],
                decoration: InputDecoration(
                  labelText: campo['label'],
                  hintText: campo['hint'],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                maxLines: campo['maxLines'] ?? 1,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final valores = controllers.map((c) => c.text.trim()).toList();
              
              // Validar campos requeridos
              for (int i = 0; i < campos.length; i++) {
                if (campos[i]['required'] == true && valores[i].isEmpty) {
                  _mostrarMensaje('${campos[i]['label']} es requerido', esError: true);
                  return;
                }
              }
              
              Navigator.pop(context, valores);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _mostrarDialogoResaltado(String textoSeleccionado) async {
    final notaController = TextEditingController();
    String colorSeleccionado = colorResaltadoActual;
    String tipoSeleccionado = tipoResaltadoActual;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Crear Resaltado', style: TextStyle(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Texto seleccionado:', style: TextStyle(fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(textoSeleccionado, style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: coloresResaltado.entries.map((entry) {
                    final isSelected = entry.value == colorSeleccionado;
                    return FilterChip(
                      label: Text(entry.key),
                      selected: isSelected,
                      backgroundColor: Color(int.parse(entry.value.substring(1), radix: 16) + 0x33000000),
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => colorSeleccionado = entry.value);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Radio<String>(
                      value: 'highlight',
                      groupValue: tipoSeleccionado,
                      onChanged: (value) => setDialogState(() => tipoSeleccionado = value!),
                    ),
                    const Text('Resaltar'),
                    Radio<String>(
                      value: 'underline',
                      groupValue: tipoSeleccionado,
                      onChanged: (value) => setDialogState(() => tipoSeleccionado = value!),
                    ),
                    const Text('Subrayar'),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notaController,
                  decoration: InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Agrega un comentario...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'color': colorSeleccionado,
                'tipo': tipoSeleccionado,
                'nota': notaController.text.trim(),
              }),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetallesItem(Map<String, dynamic> item, {required bool esMarcador}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          esMarcador ? (item['titulo'] ?? 'Marcador') : 'Resaltado',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Página ${item['pagina'] + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!esMarcador) ...[
                const Text('Texto:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(int.parse(item['color'].substring(1), radix: 16) + 0x33000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(item['texto_resaltado']),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      item['tipo'] == 'underline' ? Icons.format_underlined : Icons.highlight,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text('Tipo: ${item['tipo']}'),
                  ],
                ),
              ],
              if (item['nota'] != null && item['nota'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Nota:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(item['nota']),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cambiarPagina(item['pagina']);
              setState(() {
                mostrarMarcadores = false;
                mostrarResaltados = false;
              });
            },
            child: const Text('Ir a página'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (esMarcador) {
                await _eliminarMarcador(item['id']);
              } else {
                await _eliminarResaltado(item['id']);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // === BUILD WIDGETS ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('URPBOOK'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          // Botón de modo oscuro (siempre visible)
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(themeProvider.themeIcon),
                tooltip: themeProvider.themeTooltip,
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
          if (archivoActual != null) ...[
            IconButton(
              icon: Icon(Icons.highlight_alt, color: modoResaltado ? Colors.orange : null),
              tooltip: modoResaltado ? 'Desactivar modo resaltado' : 'Activar modo resaltado',
              onPressed: () => setState(() => modoResaltado = !modoResaltado),
            ),
            if (_paginaTieneResaltados()) const Icon(Icons.format_paint, color: Colors.blue, size: 20),
            IconButton(
              icon: Icon(
                _paginaTieneMarcador() ? Icons.bookmark : Icons.bookmark_border,
                color: _paginaTieneMarcador() ? Colors.orange : null,
              ),
              tooltip: _paginaTieneMarcador() ? 'Página marcada' : 'Agregar marcador',
              onPressed: _paginaTieneMarcador() ? null : _agregarMarcador,
            ),
            IconButton(
              icon: const Icon(Icons.bookmarks),
              tooltip: 'Ver marcadores',
              onPressed: () => setState(() {
                mostrarMarcadores = !mostrarMarcadores;
                mostrarResaltados = false;
              }),
            ),
            IconButton(
              icon: const Icon(Icons.highlight),
              tooltip: 'Ver resaltados',
              onPressed: () => setState(() {
                mostrarResaltados = !mostrarResaltados;
                mostrarMarcadores = false;
              }),
            ),
            // Botón para traducir - Solo disponible si NO está traducido
            if (!documentoTraducido)
              IconButton(
                icon: const Icon(Icons.translate),
                tooltip: isTranslating ? 'Traduciendo...' : 'Traducir documento',
                onPressed: isTranslating ? null : _traducirDocumento,
              ),
            // Botón para cambiar idioma - Solo disponible si YA está traducido
            if (documentoTraducido)
              IconButton(
                icon: Icon(
                  mostrandoTraduccion ? Icons.language : Icons.translate,
                  color: mostrandoTraduccion ? Colors.green : Colors.blue,
                ),
                tooltip: mostrandoTraduccion ? 'Mostrar original' : 'Mostrar traducción',
                onPressed: _cambiarIdioma,
              ),
            // Botón de casa - Navega a la página principal
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Ir a página principal',
              onPressed: archivoActual == null ? null : _irAInicio,
            ),
          ],
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cargando PDF...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : archivoActual == null
              ? _buildRecientes()
              : mostrarMarcadores
                  ? _buildListaItems(marcadores, esMarcadores: true)
                  : mostrarResaltados
                      ? _buildListaItems(resaltados, esMarcadores: false)
                      : _buildPdfViewer(),
      floatingActionButton: archivoActual == null
          ? FloatingActionButton.extended(
              onPressed: () => _cargarPDF(),
              icon: const Icon(Icons.add),
              label: const Text("Agregar PDF"),
            )
          : null,
    );
  }

  Widget _buildRecientes() {
    if (archivosRecientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No hay archivos recientes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el botón "+" para cargar tu primer PDF',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: archivosRecientes.length,
      itemBuilder: (context, i) {
        final nombre = archivosRecientes[i].split('/').last;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              nombre,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Toca para abrir',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) async {
                switch (value) {
                  case 'eliminar_recientes':
                    await _eliminarDeRecientes(archivosRecientes[i], nombre);
                    break;
                  case 'eliminar_completo':
                    await _eliminarPDFCompleto(archivosRecientes[i], nombre);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'eliminar_recientes',
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text('Eliminar de recientes'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'eliminar_completo',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text('Eliminar completamente'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _cargarPDF(path: archivosRecientes[i]),
          ),
        );
      },
    );
  }

  Widget _buildListaItems(List<Map<String, dynamic>> items, {required bool esMarcadores}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esMarcadores ? Icons.bookmarks_outlined : Icons.highlight_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              esMarcadores ? 'No hay marcadores' : 'No hay resaltados',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              esMarcadores 
                ? 'Agrega marcadores mientras lees para\nmarcar páginas importantes'
                : 'Selecciona texto mientras lees para\ncrear resaltados y notas',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: esMarcadores 
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : Color(int.parse(item['color'].substring(1), radix: 16) + 0x33000000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                esMarcadores 
                  ? Icons.bookmark_outlined
                  : (item['tipo'] == 'underline' ? Icons.format_underlined : Icons.highlight_outlined),
                color: esMarcadores 
                  ? Theme.of(context).colorScheme.onTertiaryContainer
                  : Color(int.parse(item['color'].substring(1), radix: 16) + 0xFF000000),
              ),
            ),
            title: Text(
              esMarcadores 
                ? (item['titulo'] ?? 'Sin título')
                : item['texto_resaltado'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Página ${item['pagina'] + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (item['nota'] != null && item['nota'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item['nota'],
                    maxLines: esMarcadores ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => _mostrarDetallesItem(item, esMarcador: esMarcadores),
            ),
            onTap: () => _cambiarPagina(item['pagina']),
          ),
        );
      },
    );
  }

  Widget _buildPdfViewer() {
    // Determinar qué páginas mostrar según el idioma seleccionado
    List<String> paginasAMostrar;
    if (documentoTraducido) {
      paginasAMostrar = mostrandoTraduccion ? paginas : paginasOriginales;
    } else {
      paginasAMostrar = paginas;
    }

    return Column(
      children: [
        if (modoResaltado)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
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
                  Icons.highlight_alt,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Modo resaltado activo - Selecciona texto para resaltar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => modoResaltado = false),
                  child: Text(
                    'Desactivar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // Indicador de idioma actual
        if (documentoTraducido)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: mostrandoTraduccion 
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  mostrandoTraduccion ? Icons.language : Icons.article,
                  size: 16,
                  color: mostrandoTraduccion ? Colors.green[800] : Colors.blue[800],
                ),
                const SizedBox(width: 4),
                Text(
                  mostrandoTraduccion ? 'Mostrando: Traducción' : 'Mostrando: Original',
                  style: TextStyle(
                    fontSize: 12,
                    color: mostrandoTraduccion ? Colors.green[800] : Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: PdfViewer(
            paginas: paginasAMostrar,
            paginaActual: paginaActual,
            fontSize: fontSize,
            onPageChanged: _cambiarPagina,
            resaltados: resaltadosPaginaActual,
            modoResaltado: modoResaltado,
            onTextoSeleccionado: _crearResaltado,
          ),
        ),
        if (isTranslating) 
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.translate,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Traduciendo documento...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Controles de navegación y tamaño
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.remove),
                label: const Text('Menor'),
                onPressed: () => _cambiarFontSize(false),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tamaño: ${fontSize.toInt()}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Mayor'),
                onPressed: () => _cambiarFontSize(true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/pdf_service.dart';
import '../services/translate_service.dart';
import '../utils/storage_helper.dart';
import '../widgets/pdf_viewer.dart';
import '../utils/db_helper.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : null,
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

      archivoActual = path!.split('/').last;
      libroIdActual = await _obtenerOLibroInsertado(archivoActual!, path);
      
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
        archivoActual = path!.split('/').last;
      });
      
      _mostrarMensaje('PDF cargado: $archivoActual');
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
        nota: resultado[1]?.isNotEmpty == true ? resultado[1] : null,
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

  // === DIÁLOGOS ===
  Future<List<String>?> _mostrarDialogo({
    required String titulo,
    required List<Map<String, dynamic>> campos,
  }) async {
    final controllers = campos.map((c) => TextEditingController()).toList();

    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
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
          title: const Text('Crear Resaltado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Texto seleccionado:'),
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(textoSeleccionado, style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 16),
                const Text('Color:'),
                Wrap(
                  spacing: 8,
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
                const Text('Tipo:'),
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
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Agrega un comentario...',
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
        title: Text(esMarcador ? (item['titulo'] ?? 'Marcador') : 'Resaltado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Página: ${item['pagina'] + 1}'),
              const SizedBox(height: 8),
              if (!esMarcador) ...[
                const Text('Texto:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(int.parse(item['color'].substring(1), radix: 16) + 0x33000000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(item['texto_resaltado']),
                ),
                Text('Tipo: ${item['tipo']}'),
              ],
              if (item['nota'] != null && item['nota'].isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Nota:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(item['nota']),
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
      appBar: AppBar(
        title:  Text('URPBOOK'),
        actions: [
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
          ],
          // Botón de casa - Navega a la página principal
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Ir a página principal',
            onPressed: archivoActual == null ? null : _irAInicio,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
      return const Center(
        child: Text('No hay archivos recientes.\nToca el "+" para cargar uno.', textAlign: TextAlign.center),
      );
    }
    return ListView.builder(
      itemCount: archivosRecientes.length,
      itemBuilder: (context, i) {
        final nombre = archivosRecientes[i].split('/').last;
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf),
          title: Text(nombre),
          onTap: () => _cargarPDF(path: archivosRecientes[i]),
        );
      },
    );
  }

  Widget _buildListaItems(List<Map<String, dynamic>> items, {required bool esMarcadores}) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          esMarcadores 
            ? 'No hay marcadores para este libro.\nAgrega marcadores mientras lees.'
            : 'No hay resaltados para este libro.\nSelecciona texto y resáltalo mientras lees.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: esMarcadores 
              ? const Icon(Icons.bookmark, color: Colors.orange)
              : Icon(
                  item['tipo'] == 'underline' ? Icons.format_underlined : Icons.highlight,
                  color: Color(int.parse(item['color'].substring(1), radix: 16) + 0xFF000000),
                ),
            title: Text(
              esMarcadores 
                ? (item['titulo'] ?? 'Sin título')
                : item['texto_resaltado'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Página ${item['pagina'] + 1}'),
                if (item['nota'] != null && item['nota'].isNotEmpty)
                  Text(
                    item['nota'],
                    maxLines: esMarcadores ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
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
            padding: const EdgeInsets.all(8),
            color: Colors.orange[100],
            child: Row(
              children: [
                const Icon(Icons.highlight_alt, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Modo resaltado activo - Selecciona texto para resaltar'),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => modoResaltado = false),
                  child: const Text('Desactivar'),
                ),
              ],
            ),
          ),
        // Indicador de idioma actual
        if (documentoTraducido)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: mostrandoTraduccion ? Colors.green[100] : Colors.blue[100],
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
          const Padding(
            padding: EdgeInsets.all(16.0), 
            child: Column(
              children: [
                LinearProgressIndicator(),
                SizedBox(height: 8),
                Text('Traduciendo documento...'),
              ],
            ),
          ),
        // Controles de navegación y tamaño
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.remove),
              label: const Text('Menor'),
              onPressed: () => _cambiarFontSize(false),
            ),
            Text('Tamaño: ${fontSize.toInt()}'),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Mayor'),
              onPressed: () => _cambiarFontSize(true),
            ),
          ],
        ),
      ],
    );
  }
}
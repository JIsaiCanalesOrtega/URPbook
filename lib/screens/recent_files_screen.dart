// screens/recent_files_screen.dart

import 'package:flutter/material.dart';

class RecentFilesScreen extends StatelessWidget {
  final List<String> archivosRecientes;
  final void Function(String path) onSeleccionarArchivo;
  final void Function(int index) onEliminarArchivo;

  const RecentFilesScreen({
    super.key,
    required this.archivosRecientes,
    required this.onSeleccionarArchivo,
    required this.onEliminarArchivo,
  });

  @override
  Widget build(BuildContext context) {
    if (archivosRecientes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay archivos recientes',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Toca el botón para cargar un PDF',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: archivosRecientes.length,
      itemBuilder: (context, index) {
        final path = archivosRecientes[index];
        final nombre = path.split('/').last;

        return Dismissible(
          key: Key(path),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirmar eliminación'),
                content: Text('¿Eliminar "$nombre" de recientes?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => onEliminarArchivo(index),
          child: ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(nombre),
            subtitle: Text(path, style: const TextStyle(fontSize: 12)),
            onTap: () => onSeleccionarArchivo(path),
          ),
        );
      },
    );
  }
}
// This widget displays a list of recent files with options to select or delete them.
// It uses a Dismissible widget to allow swiping to delete files.
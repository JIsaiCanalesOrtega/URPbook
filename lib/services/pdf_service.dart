import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/text_cleaner.dart';

/// Servicio para manejar la lectura y procesamiento de archivos PDF.
class PdfService {
  /// Lee el PDF desde el [path] y retorna una lista con el texto limpio por página.
  /// Si una página está vacía, devuelve '(Sin texto en esta página)'.
  static Future<List<String>> leerPaginas(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Archivo no encontrado: $path');
      }
      final Uint8List bytes = await file.readAsBytes();

      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      final List<String> paginas = [];
      for (int i = 0; i < document.pages.count; i++) {
        String texto = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        texto = limpiarTexto(texto);
        if (texto.trim().isEmpty) {
          texto = '(Sin texto en esta página)';
        }
        paginas.add(texto);
      }

      document.dispose();
      return paginas;
    } catch (e) {
      // Aquí puedes loguear el error o lanzar uno más amigable
      throw Exception('Error al leer PDF: $e');
    }
  }
}

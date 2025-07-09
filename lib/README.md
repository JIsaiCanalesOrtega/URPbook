# ULB PDF Translator

Aplicación Flutter para cargar, visualizar, limpiar y traducir documentos PDF página por página utilizando la API de LibreTranslate. Permite navegación, zoom, historial de archivos recientes y traducción en lotes.

---

## 🚀 Funcionalidades

- Carga de archivos PDF desde el dispositivo
- Extracción y limpieza de texto automático (corrige OCR, elimina encabezados/pies)
- Traducción usando la API pública de [LibreTranslate](https://libretranslate.de)
- Navegación entre páginas y control de zoom con gestos
- Alternar entre documento original y traducido
- Historial de archivos recientes

---

## 📁 Estructura del proyecto

```
lib/
├── main.dart                        # Punto de entrada
├── screens/
│   ├── home_screen.dart            # Pantalla principal
│   └── recent_files_screen.dart    # Lista de archivos recientes
├── widgets/
│   ├── pdf_viewer.dart             # Componente de lectura con zoom
│   └── translate_controls.dart     # Botones flotantes
├── services/
│   ├── pdf_service.dart            # Carga y extracción del PDF
│   ├── translate_service.dart      # Traducción
│   └── connection_service.dart     # Verificación de conexión
├── utils/
│   ├── text_cleaner.dart           # Limpieza avanzada de texto
│   └── storage_helper.dart         # SharedPreferences para historial
```

---

## ⚙️ Dependencias

Agrega en `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  file_picker: ^6.1.1
  syncfusion_flutter_pdf: ^24.2.6
  shared_preferences: ^2.2.2
  http: ^0.13.6
```

Luego ejecuta:
```bash
flutter pub get
```

---

## 🧠 Cómo funciona

- `home_screen.dart` gestiona el estado general y orquesta los servicios
- `pdf_service.dart` abre el PDF y extrae texto limpio
- `text_cleaner.dart` procesa el texto eliminando errores comunes de OCR
- `translate_service.dart` divide el documento en lotes y traduce usando HTTP
- `storage_helper.dart` guarda historial localmente

---

## ✏️ Personalización

| Quiero cambiar...                            | Archivo a editar                        |
|---------------------------------------------|-----------------------------------------|
| Idioma de traducción por defecto            | `home_screen.dart` (`destino = 'es'`)  |
| Tema o color del app                        | `main.dart`                             |
| Lógica de traducción                        | `translate_service.dart`               |
| Limpieza del texto extraído                 | `text_cleaner.dart`                    |
| Diseño de botones flotantes                 | `translate_controls.dart`              |
| Comportamiento de archivos recientes        | `storage_helper.dart`                  |

---

## 🧪 Ejecución

```bash
flutter clean
flutter pub get
flutter run
```

---

## 📌 Nota
- Esta app usa una API pública gratuita; limita el volumen de traducciones simultáneas
- No incluye autenticación ni almacenamiento en la nube

---

## 📄 Licencia
MIT License

---

Desarrollado como base educativa y funcional para procesar documentos PDF multilingües. ✨
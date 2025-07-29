// utils/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  ThemeProvider() {
    _loadThemeFromPrefs();
  }
  
  // Cargar tema guardado de SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeIndex = prefs.getInt(_themeKey) ?? 0;
      _themeMode = ThemeMode.values[savedThemeIndex];
      notifyListeners();
    } catch (e) {
      // Si hay error, usar tema del sistema
      _themeMode = ThemeMode.system;
    }
  }
  
  // Guardar tema en SharedPreferences
  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _themeMode.index);
    } catch (e) {
      // Error al guardar, pero continúa funcionando
      debugPrint('Error saving theme: $e');
    }
  }
  
  // Alternar entre modo claro y oscuro
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    notifyListeners();
    await _saveThemeToPrefs();
  }
  
  // Establecer tema específico
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveThemeToPrefs();
  }
  
  // Obtener icono apropiado para el botón de tema
  IconData get themeIcon {
    switch (_themeMode) {
      case ThemeMode.light:
        return Icons.dark_mode_outlined;
      case ThemeMode.dark:
        return Icons.light_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
  
  // Obtener tooltip apropiado para el botón de tema
  String get themeTooltip {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Cambiar a modo oscuro';
      case ThemeMode.dark:
        return 'Cambiar a modo claro';
      case ThemeMode.system:
        return 'Cambiar tema';
    }
  }
}
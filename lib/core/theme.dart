import 'package:flutter/material.dart';

/// Tema Material 3 de CeldaPro — verde litio + acento ámbar.
class AppTheme {
  const AppTheme._();

  /// Verde litio (color semilla principal).
  static const seed = Color(0xFF2E7D32);

  /// Ámbar (acento / advertencias).
  static const accent = Color(0xFFFFB300);

  /// Colores por veredicto de clasificación.
  static const verdictA = Color(0xFF2E7D32); // verde
  static const verdictB = Color(0xFF1565C0); // azul
  static const verdictC = Color(0xFFF9A825); // ámbar
  static const verdictReject = Color(0xFFC62828); // rojo

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      // Solo alto mínimo: el ancho lo decide el contexto. (Size.fromHeight
      // pondría ancho infinito y rompería botones dentro de ListTile.)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  /// Color del veredicto para pintar chips/badges.
  static Color verdictColor(String verdict) {
    switch (verdict) {
      case 'A':
        return verdictA;
      case 'B':
        return verdictB;
      case 'C':
        return verdictC;
      default:
        return verdictReject;
    }
  }
}

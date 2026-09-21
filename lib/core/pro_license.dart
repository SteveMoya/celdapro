/// Licencia de la versión Pro de CeldaPro.
///
/// La app es 100% local: no hay servidor que valide nada. La licencia es un
/// código con una firma (FNV-1a) que se comprueba **en el propio teléfono**,
/// sin conexión. Genera códigos válidos con `tools/generar_licencia.py`.
///
/// Aviso honesto: al no haber servidor, esto es una **puerta de entrada**, no
/// un candado. Alguien con conocimientos podría modificar la app para activarla
/// sin código. Para el uso previsto (entregar la versión Pro a un taller
/// concreto) es suficiente; si algún día se necesita algo inviolable, hay que
/// validar contra un servidor.
class ProLicense {
  ProLicense._();

  /// Formato: `CPRO-XXXX-XXXX-FFFF` (grupos en mayúsculas, firma hexadecimal).
  static final _patron = RegExp(
    r'^CPRO-([0-9A-Z]{4})-([0-9A-Z]{4})-([0-9A-F]{4})$',
  );

  /// ¿Este texto es un código Pro válido?
  static bool esCodigoValido(String? codigo) {
    final m = _patron.firstMatch(normalizar(codigo));
    if (m == null) return false;
    return firma('CPRO-${m[1]}-${m[2]}') == m[3];
  }

  /// Deja el código en la forma canónica.
  ///
  /// Acepta lo que la gente escribe de verdad: minúsculas, espacios en vez de
  /// guiones y guiones largos (al copiar de un mensaje suelen aparecer).
  static String normalizar(String? codigo) => (codigo ?? '')
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\u2013\u2014]+'), '-');

  /// Firma de 4 dígitos hexadecimales sobre el cuerpo del código.
  ///
  /// Es FNV-1a de 32 bits truncado; el mismo algoritmo está en
  /// `tools/generar_licencia.py`, así que los códigos generados allí valen aquí.
  static String firma(String cuerpo) {
    var h = 0x811c9dc5;
    for (final unidad in cuerpo.codeUnits) {
      h ^= unidad;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).toUpperCase().padLeft(8, '0').substring(0, 4);
  }

  /// Texto de ayuda con el formato esperado.
  static const ejemplo = 'CPRO-XXXX-XXXX-XXXX';
}

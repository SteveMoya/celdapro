/// Interpretación del texto que devuelve el OCR de una etiqueta.
///
/// El OCR no es perfecto: confunde letras con dígitos (`O` por `0`, `I` por `1`,
/// `S` por `5`…) y a veces se come el guion que separa el prefijo del número.
/// Esta lógica, que es pura y se prueba sola, convierte ese texto en candidatos
/// **ordenados** —primero la lectura corregida, después lo leído tal cual— y,
/// cuando nada coincide exacto, propone los códigos del inventario más parecidos.
///
/// El orden importa: quien consume esto prueba los candidatos de arriba abajo y
/// se queda con el primero que exista en la base, así que la lectura corregida
/// gana a la cruda pero la cruda sigue sirviendo para códigos personalizados.
library;

/// Letras que el OCR suele devolver donde había un dígito.
///
/// Se aplica **después** de pasar a mayúsculas, así que cubre también las
/// minúsculas (`o` → `O` → `0`).
const _letraADigito = <String, String>{
  'O': '0',
  'Q': '0',
  'D': '0',
  'I': '1',
  'L': '1',
  '|': '1',
  '!': '1',
  'Z': '2',
  'A': '4',
  'S': '5',
  'G': '6',
  'T': '7',
  'B': '8',
};

/// Un prefijo alfabético y su parte numérica, con o sin separador en medio.
/// Solo letras y dígitos: cualquier otra cosa corta la coincidencia.
///
/// Exige un límite antes de la letra (`inicio`, espacio o separador) para no
/// confundir la `G` final de `SAMSUNG` con un prefijo de código.
final _reCodigo = RegExp(r'(?:^|[^0-9A-Z])([A-Z])[\s-]?([0-9A-Z!|]{3,8})');

/// Números sueltos, por si el OCR se come el prefijo entero.
final _reDigitos = RegExp(r'[0-9]{3,8}');

/// Trozos de texto separados por todo lo que no sea letra, dígito o guion.
final _reTokens = RegExp(r'[^0-9A-Z-]+');

/// Deja el texto del OCR listo para analizar: sin acentos, en mayúsculas y con
/// todos los separadores que el OCR confunde (`—`, `_`, `:`, `.`, `/`)
/// unificados en un guion.
String normalizarTextoOcr(String texto) {
  final sinAcentos = texto
      .replaceAll(RegExp('[áàäâãÁÀÄÂÃ]'), 'a')
      .replaceAll(RegExp('[éèëêÉÈËÊ]'), 'e')
      .replaceAll(RegExp('[íìïîÍÌÏÎ]'), 'i')
      .replaceAll(RegExp('[óòöôõÓÒÖÔÕ]'), 'o')
      .replaceAll(RegExp('[úùüûÚÙÜÛ]'), 'u')
      .replaceAll(RegExp('[ñÑ]'), 'n');
  return sinAcentos
      .toUpperCase()
      .replaceAll(RegExp(r'[—–−_·•:/.\\,]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Cambia por dígitos las letras que el OCR confunde, y deja el resto igual.
String aDigitos(String s) {
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    buffer.write(_letraADigito[ch] ?? ch);
  }
  return buffer.toString();
}

/// ¿La cadena, una vez corregidas las confusiones, es solo dígitos?
bool _sonDigitos(String s) {
  final corregido = aDigitos(s);
  if (corregido.isEmpty) return false;
  for (final ch in corregido.split('')) {
    if (!'0123456789'.contains(ch)) return false;
  }
  return true;
}

/// Candidatos a código de celda, del más probable al menos.
///
/// Para `'C-0OO1'` devuelve `['C-0001', 'C0001']`: primero la lectura corregida
/// y luego la unión sin guion, que es como suele leerla el OCR cuando pierde el
/// separador. Para `'Lote 7 / Samsung'` no devuelve nada, porque ninguno de sus
/// trozos parece un código.
List<String> codigosCandidatos(String textoOcr) {
  final norm = normalizarTextoOcr(textoOcr);
  final salida = <String>[];

  void add(String? candidato) {
    if (candidato == null) return;
    final t = candidato.trim();
    // Menos de 3 caracteres no es un código: es ruido del OCR.
    if (t.length < 3 || salida.contains(t)) return;
    salida.add(t);
  }

  for (final m in _reCodigo.allMatches(norm)) {
    final letra = m.group(1)!;
    final cola = m.group(2)!;
    if (!_sonDigitos(cola)) {
      // No es un número: puede ser una palabra (SAMSUNG) y no un código.
      continue;
    }
    final digitos = aDigitos(cola);
    add('$letra-$digitos');
    add('$letra$digitos');
  }

  // Códigos propios del taller, que no siguen el patrón de la app
  // ("SAMSUNG-A12", "LOTE3-B"). Se reconocen porque mezclan letras y números.
  //
  // Se piden 4 caracteres y 2 dígitos para no confundir nombres de modelo de
  // celda (25R, 30Q, HG2) con códigos: son estructuralmente parecidos, así que
  // el corte va por largo y cantidad de dígitos. Aun así es un candidato de
  // baja prioridad: si la etiqueta lleva el código de verdad, ese gana antes.
  for (final token in norm.split(_reTokens)) {
    if (token.length < 4 || token.length > 24) continue;
    final digitos = RegExp('[0-9]').allMatches(token).length;
    final tieneLetra = RegExp('[A-Z]').hasMatch(token);
    if (tieneLetra && digitos >= 2) add(token);
  }

  // Último recurso: números sueltos. Solo se usarán si nada de lo anterior
  // existe en la base.
  for (final m in _reDigitos.allMatches(norm)) {
    add(m.group(0));
  }

  return salida;
}

/// Distancia de edición (Levenshtein) entre dos cadenas.
///
/// Cuenta cuántos cambios de un carácter hacen falta para pasar de una a otra.
/// Se usa para proponer códigos parecidos cuando el OCR lee mal.
int distancia(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var anterior = List<int>.generate(b.length + 1, (i) => i);
  final actual = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    actual[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final coste = a[i - 1] == b[j - 1] ? 0 : 1;
      final borrado = anterior[j] + 1;
      final insercion = actual[j - 1] + 1;
      final sustitucion = anterior[j - 1] + coste;
      actual[j] = borrado < insercion
          ? (borrado < sustitucion ? borrado : sustitucion)
          : (insercion < sustitucion ? insercion : sustitucion);
    }
    for (var j = 0; j <= b.length; j++) {
      anterior[j] = actual[j];
    }
  }
  return anterior[b.length];
}

/// Códigos del inventario que más se parecen a lo leído.
///
/// Es la red de seguridad para cuando el OCR lee tan mal que ninguna corrección
/// da con el código exacto: en vez de dejar al operador sin nada, la pantalla
/// puede ofrecerle «¿querías decir…?».
///
/// La tolerancia crece con el largo del código (un código de 6 caracteres admite
/// hasta 2 fallos; uno de 3, ninguno), para no proponer cosas que no se parecen.
List<String> sugerencias(
  String textoOcr,
  Iterable<String> codigosExistentes, {
  int maximo = 3,
}) {
  final candidatos = codigosCandidatos(textoOcr);
  if (candidatos.isEmpty) return const [];

  final puntuados = <MapEntry<int, String>>[];
  for (final existente in codigosExistentes) {
    var mejor = 1 << 30;
    for (final candidato in candidatos) {
      final d = distancia(
        candidato.toUpperCase(),
        existente.toUpperCase(),
      );
      if (d < mejor) mejor = d;
    }
    final tolerancia = (existente.length * 0.34).floor();
    if (mejor > 0 && mejor <= tolerancia) {
      puntuados.add(MapEntry(mejor, existente));
    }
  }

  puntuados.sort((x, y) {
    final porDistancia = x.key.compareTo(y.key);
    if (porDistancia != 0) return porDistancia;
    // Desempate alfabético: con la misma distancia el resultado tiene que ser
    // siempre el mismo, no depender del orden en que llegaron.
    return x.value.compareTo(y.value);
  });
  return puntuados.take(maximo).map((e) => e.value).toList();
}

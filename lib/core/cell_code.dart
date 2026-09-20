/// Contenido codificado en la etiqueta de una celda.
///
/// Dos formatos, con propósitos distintos:
///
/// - **Código de barras 1D (Code 128)**: lleva solo el código interno
///   (`C-0001`). Es corto a propósito: cuantos más caracteres, más estrechas
///   son las barras y peor se lee con la cámara. Sirve para identificar.
/// - **Código QR (2D)**: lleva la ficha completa de la celda. El QR aguanta
///   muchísimos más caracteres sin perder legibilidad, así que aquí sí cabe
///   toda la información.
///
/// La etiqueta impresa lleva los dos, más el código en texto legible.
library;

import '../data/models/celda.dart';
import '../data/models/lote.dart';

/// Marca de inicio del contenido QR. Permite reconocer una etiqueta de
/// CeldaPro frente a cualquier otro código.
const cellPayloadPrefix = 'CELDAPRO';

/// Versión del formato, para poder cambiarlo sin romper etiquetas ya impresas.
const cellPayloadVersion = '1';

/// Ficha de una celda codificada en la etiqueta.
class CellPayload {
  const CellPayload({
    required this.codigo,
    this.marca,
    this.modelo,
    this.referencia,
    this.quimica,
    this.capacidadMah,
    this.voltaje,
    this.irMohm,
    this.lote,
    this.estado,
    this.veredicto,
    this.sohPct,
  });

  final String codigo;
  final String? marca;
  final String? modelo;
  final String? referencia;
  final String? quimica;
  final double? capacidadMah;
  final double? voltaje;
  final double? irMohm;
  final String? lote;
  final String? estado;
  final String? veredicto;
  final double? sohPct;

  /// Texto que se codifica en el QR.
  String encode() {
    final campos = <String>[
      cellPayloadPrefix,
      cellPayloadVersion,
      _limpiar(codigo),
      _limpiar(marca),
      _limpiar(modelo),
      _limpiar(referencia),
      _limpiar(quimica),
      _num(capacidadMah),
      _num(voltaje),
      _num(irMohm),
      _limpiar(lote),
      _limpiar(estado),
      _limpiar(veredicto),
      sohPct == null ? '' : sohPct!.toStringAsFixed(1),
    ];
    return campos.join('|');
  }

  /// Interpreta el contenido de un QR. Devuelve null si no es de CeldaPro.
  static CellPayload? decode(String texto) {
    final partes = texto.trim().split('|');
    if (partes.length < 3 || partes.first != cellPayloadPrefix) return null;
    if (partes[1] != cellPayloadVersion) return null;
    String? v(int i) {
      if (i >= partes.length) return null;
      final s = partes[i].trim();
      return s.isEmpty ? null : s;
    }

    return CellPayload(
      codigo: v(2) ?? '',
      marca: v(3),
      modelo: v(4),
      referencia: v(5),
      quimica: v(6),
      capacidadMah: _aNumero(v(7)),
      voltaje: _aNumero(v(8)),
      irMohm: _aNumero(v(9)),
      lote: v(10),
      estado: v(11),
      veredicto: v(12),
      sohPct: _aNumero(v(13)),
    );
  }

  /// ¿El texto leído es una etiqueta de CeldaPro?
  static bool esPayload(String texto) =>
      texto.trim().split('|').first == cellPayloadPrefix;

  @override
  String toString() => 'CellPayload($codigo)';
}

/// Construye el contenido de la etiqueta a partir de una celda real.
CellPayload payloadDeCelda(Celda celda, {Lote? lote}) => CellPayload(
      codigo: celda.codigoInterno,
      marca: celda.marca,
      modelo: celda.modelo,
      referencia: celda.catalogRef,
      quimica: celda.quimica.label,
      capacidadMah: celda.capacidadNominalMah,
      voltaje: celda.voltajeNominal,
      irMohm: celda.irNominalMohm,
      lote: lote?.codigo,
      estado: celda.estado.label,
      veredicto: celda.veredicto?.code,
      sohPct: celda.sohPct,
    );

/// Lo que se codifica en el código de barras 1D: solo el identificador.
///
/// Deliberadamente corto: un Code 128 con 60 caracteres ocupa tanto ancho que
/// la cámara no lo resuelve en una etiqueta de celda.
String barcodeDeCelda(Celda celda) => celda.codigoInterno;

String _limpiar(String? s) =>
    s == null ? '' : s.replaceAll('|', '/').replaceAll('\n', ' ').trim();

String _num(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
}

double? _aNumero(String? s) {
  if (s == null) return null;
  return double.tryParse(s.replaceAll(',', '.'));
}

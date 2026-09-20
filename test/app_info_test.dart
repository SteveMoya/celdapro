import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/app_info.dart';

/// La versión llegó a estar desincronizada: el APK reportaba 0.1.0 mientras las
/// releases publicadas iban por la 0.2.0. Este test lo impide.
void main() {
  test('la versión de la app coincide con pubspec.yaml', () {
    final pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue,
        reason: 'ejecuta el test desde la raíz del proyecto');

    final linea = pubspec
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
    expect(linea, isNotEmpty, reason: 'pubspec.yaml no declara version:');

    final declarada = linea.split(':').last.trim(); // "0.3.0+1"
    expect(declarada, appVersionFull,
        reason: 'pubspec.yaml dice "$declarada" pero app_info.dart dice '
            '"$appVersionFull": hay que igualarlos');

    final partes = declarada.split('+');
    expect(partes.first, appVersion);
    expect(int.parse(partes.last), appBuild);
  });

  test('el nombre de la app es el que se muestra y el que firma Android', () {
    expect(appName, 'CeldaPro');
    expect(appVersionFull, '$appVersion+$appBuild');
  });
}

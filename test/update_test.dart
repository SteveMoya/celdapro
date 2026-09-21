import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/features/updates/update_dialog.dart';
import 'package:celdapro/services/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Respuesta de la API de GitHub con la forma real que devuelve
/// `/repos/SteveMoya/celdapro/releases?per_page=1`.
String _respuestaGithub({
  String tag = 'v0.6.0',
  String? body = '## Novedades\n- Test masivo por lote',
  bool prerelease = false,
  List<Map<String, Object?>>? assets,
}) =>
    jsonEncode([
      {
        'tag_name': tag,
        'body': body,
        'prerelease': prerelease,
        'published_at': '2026-09-21T00:05:00Z',
        'assets': assets ??
            [
              {
                'name': 'celdapro-$tag-arm64.apk',
                'size': 29200000,
                'browser_download_url':
                    'https://github.com/SteveMoya/celdapro/releases/download/$tag/celdapro-$tag-arm64.apk',
              },
              {
                'name': 'celdapro-$tag-arm32.apk',
                'size': 25600000,
                'browser_download_url':
                    'https://github.com/SteveMoya/celdapro/releases/download/$tag/celdapro-$tag-arm32.apk',
              },
            ],
      },
    ]);

UpdateInfo _info({
  String tag = 'v0.6.0',
  String version = '0.6.0',
  int size = 27 * 1024 * 1024,
  String notes = '## Novedades\n- Test masivo por lote',
  bool prerelease = false,
}) =>
    UpdateInfo(
      tag: tag,
      version: version,
      apkUrl: 'https://example.com/celdapro-$tag.apk',
      apkSizeBytes: size,
      notes: notes,
      releasedAt: DateTime(2026, 9, 21),
      prerelease: prerelease,
    );

void main() {
  group('compararVersiones', () {
    test('reconoce una versión más nueva', () {
      expect(compararVersiones('0.6.0', '0.5.0'), greaterThan(0));
      expect(compararVersiones('0.5.1', '0.5.0'), greaterThan(0));
      expect(compararVersiones('1.0.0', '0.9.9'), greaterThan(0));
    });

    test('reconoce una versión más vieja', () {
      expect(compararVersiones('0.4.0', '0.5.0'), lessThan(0));
    });

    test('reconoce versiones iguales', () {
      expect(compararVersiones('0.5.0', '0.5.0'), 0);
      expect(compararVersiones('v0.5.0', '0.5.0'), 0);
      // El número de build no cuenta: no obliga a actualizar.
      expect(compararVersiones('0.5.0+3', '0.5.0+1'), 0);
    });

    test('ignora el prefijo v y el build de la instalada', () {
      expect(compararVersiones('v0.6.0', '0.5.0+7'), greaterThan(0));
      expect(compararVersiones('0.5.0', 'v0.5.0+7'), 0);
    });

    test('una versión con menos partes no revienta', () {
      expect(compararVersiones('1', '0.9.0'), greaterThan(0));
      expect(compararVersiones('0.5', '0.5.0'), 0);
    });
  });

  group('Revisión de actualizaciones contra la API', () {
    /// Cliente HTTP falso: devuelve lo que se le indique sin salir a la red.
    http.Client clienteQueDevuelve(String cuerpo, {int codigo = 200}) =>
        MockClient((_) async => http.Response(cuerpo, codigo));

    test('detecta la versión nueva y elige el APK más liviano', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve(_respuestaGithub()),
        versionInstalada: '0.5.0',
      );

      expect(info, isNotNull);
      expect(info!.tag, 'v0.6.0');
      expect(info.version, '0.6.0');
      // En los tests no hay canal nativo (no es Android), así que cae al APK
      // más pequeño, que es la apuesta segura.
      expect(info.apkSizeBytes, 25600000);
      expect(info.apkUrl, endsWith('celdapro-v0.6.0-arm32.apk'));
      expect(info.notes, contains('Test masivo por lote'));
      expect(info.releasedAt, DateTime.utc(2026, 9, 21, 0, 5));
    });

    test('con la misma versión instalada no hay actualización', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve(_respuestaGithub()),
        versionInstalada: '0.6.0',
      );

      expect(info, isNull);
    });

    test('una instalada más nueva no se degrada', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve(_respuestaGithub()),
        versionInstalada: '0.7.0',
      );

      expect(info, isNull);
    });

    test('sin APK publicado no ofrece actualizar', () async {
      final sinApk = _respuestaGithub(assets: [
        {'name': 'notas.txt', 'size': 10, 'browser_download_url': 'u'},
      ]);
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve(sinApk),
        versionInstalada: '0.5.0',
      );

      expect(info, isNull);
    });

    test('un error de la API no rompe la app', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve('{"mensaje":"límite de peticiones"}',
            codigo: 403),
        versionInstalada: '0.5.0',
      );

      expect(info, isNull);
    });

    test('una respuesta ilegible tampoco rompe la app', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve('esto no es JSON'),
        versionInstalada: '0.5.0',
      );

      expect(info, isNull);
    });

    test('sin releases publicadas no hay nada que ofrecer', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve('[]'),
        versionInstalada: '0.5.0',
      );

      expect(info, isNull);
    });

    test('las betas se anuncian como beta', () async {
      final info = await UpdateService.instance.verificar(
        cliente: clienteQueDevuelve(_respuestaGithub(prerelease: true)),
        versionInstalada: '0.5.0',
      );

      expect(info!.prerelease, isTrue);
      expect(info.versionEtiqueta, '0.6.0 (beta)');
    });
  });

  group('Elección del APK según la arquitectura', () {
    final arm64 = <String, dynamic>{
      'name': 'celdapro-v0.6.0-arm64.apk',
      'size': 29200000,
      'browser_download_url': 'arm64',
    };
    final arm32 = <String, dynamic>{
      'name': 'celdapro-v0.6.0-arm32.apk',
      'size': 25600000,
      'browser_download_url': 'arm32',
    };

    test('un teléfono de 64 bits recibe el APK arm64', () {
      final e = UpdateService.elegirApk([arm64, arm32], 'arm64-v8a');
      expect(e!['browser_download_url'], 'arm64');
    });

    test('un teléfono de 32 bits recibe el APK arm32', () {
      final e = UpdateService.elegirApk([arm64, arm32], 'armeabi-v7a');
      expect(e!['browser_download_url'], 'arm32');
    });

    test('el orden en que lleguen no importa', () {
      final e = UpdateService.elegirApk([arm32, arm64], 'arm64-v8a');
      expect(e!['browser_download_url'], 'arm64');
    });

    test('sin arquitectura conocida cae al APK más pequeño', () {
      final e = UpdateService.elegirApk([arm64, arm32], null);
      expect(e!['browser_download_url'], 'arm32');
    });

    test('una arquitectura rara no deja sin actualización', () {
      final e = UpdateService.elegirApk([arm64, arm32], 'x86_64');
      expect(e, isNotNull);
    });

    test('sin APK no hay nada que elegir', () {
      expect(UpdateService.elegirApk([], 'arm64-v8a'), isNull);
    });
  });

  group('UpdateInfo', () {
    test('marca las betas en la etiqueta', () {
      expect(_info().versionEtiqueta, '0.6.0');
      expect(_info(prerelease: true).versionEtiqueta, '0.6.0 (beta)');
    });
  });

  group('Diálogo de actualización', () {
    Future<void> pump(WidgetTester tester, UpdateInfo info) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: UpdateDialog(info: info)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la versión, el tamaño y las novedades',
        (tester) async {
      await pump(tester, _info());

      expect(find.text('Versión 0.6.0 disponible'), findsOneWidget);
      expect(find.text('27.0 MB para descargar'), findsOneWidget);
      expect(find.text('Novedades'), findsOneWidget);
      expect(find.textContaining('Test masivo por lote'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsOneWidget);
      expect(find.text('Más tarde'), findsOneWidget);
    });

    testWidgets('una beta se anuncia como beta', (tester) async {
      await pump(tester, _info(prerelease: true));

      expect(find.text('Versión 0.6.0 (beta) disponible'), findsOneWidget);
    });

    testWidgets('sin notas no muestra la sección de novedades',
        (tester) async {
      await pump(tester, _info(notes: '   '));

      expect(find.text('Novedades'), findsNothing);
      expect(find.text('Actualizar ahora'), findsOneWidget);
    });

    testWidgets('sin tamaño no muestra un cero raro', (tester) async {
      await pump(tester, _info(size: 0));

      expect(find.text('0.0 MB para descargar'), findsOneWidget);
    });
  });
}

/// Identidad y versión de la aplicación.
///
/// La versión se declara aquí **y** en `pubspec.yaml`. Hay un test que compara
/// ambas para que no vuelvan a separarse (el APK llegó a reportar 0.1.0
/// mientras las releases iban por la 0.2.0).
library;

const String appName = 'CeldaPro';

/// Versión visible (debe coincidir con `version:` en pubspec.yaml).
const String appVersion = '0.7.0';

/// Número de compilación (debe coincidir con el `+N` de pubspec.yaml).
const int appBuild = 1;

/// Firma completa, como la reporta Android: `0.3.0+1`.
String get appVersionFull => '$appVersion+$appBuild';

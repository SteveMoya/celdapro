package me.stevemoya.celdapro

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val canal = "celdapro/instalador"
    private val REQUEST_INSTALAR = 0x0A5E

    /// Result del método "instalar" que se completa cuando el PackageInstaller
    /// termina (al volver de su pantalla con onActivityResult), para que la app
    /// pueda mostrar el resultado de la instalación.
    private var resultadoInstalacionPendiente: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal).setMethodCallHandler { call, result ->
            when (call.method) {
                "puedeInstalar" -> result.success(puedeInstalarAppsDesconocidas())
                "abiPrincipal" -> result.success(abiPrincipal())
                "abrirAjustesInstalacion" -> {
                    abrirAjustesInstalacion()
                    result.success(null)
                }
                "instalar" -> {
                    val ruta = call.argument<String>("ruta")
                    if (ruta == null) {
                        result.error("SIN_RUTA", "La ruta del APK es nula", null)
                    } else if (!puedeInstalarAppsDesconocidas()) {
                        result.success("permiso")
                    } else {
                        val archivo = File(ruta)
                        if (!archivo.exists()) {
                            result.success("error:noExiste")
                        } else {
                            // Guardamos el result para completarlo al volver del
                            // instalador (onActivityResult) y así reportar si se
                            // instaló, se canceló o falló.
                            resultadoInstalacionPendiente = result
                            try {
                                lanzarInstalador(archivo)
                            } catch (e: Exception) {
                                resultadoInstalacionPendiente = null
                                result.success("error:lanzamiento:${e.message ?: e.javaClass.simpleName}")
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_INSTALAR && resultadoInstalacionPendiente != null) {
            // El PackageInstaller lanzado por ACTION_VIEW es conocido por
            // devolver códigos de resultado no estándar en muchos
            // fabricantes incluso cuando la instalación fue exitosa —
            // tratarlo como error dejaba "error desconocido" en
            // instalaciones que sí funcionaron. Un fallo real (APK
            // corrupto, firma distinta) lo muestra el propio instalador y
            // vuelve como RESULT_CANCELED, así que es el único código que
            // se trata como "no se instaló".
            val res = if (resultCode == RESULT_CANCELED) "cancelado" else "instalado"
            resultadoInstalacionPendiente?.success(res)
            resultadoInstalacionPendiente = null
        }
    }

    private fun lanzarInstalador(archivo: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", archivo)
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, "application/vnd.android.package-archive")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // Sin FLAG_ACTIVITY_NEW_TASK: queremos que el resultado de la instalación
        // vuelva a esta activity (startActivityForResult).
        startActivityForResult(intent, REQUEST_INSTALAR)
    }

    /// Arquitectura principal del teléfono (p. ej. "arm64-v8a"), para que la
    /// app descargue el APK que le corresponde y no uno que el sistema
    /// rechace al instalar.
    private fun abiPrincipal(): String? = try {
        Build.SUPPORTED_ABIS.firstOrNull()
    } catch (e: Exception) {
        null
    }

    /// Android 8+ exige que la app tenga permitido instalar desde este origen
    /// ("Instalar apps desconocidas") para poder lanzar el PackageInstaller.
    private fun puedeInstalarAppsDesconocidas(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return try {
            packageManager.canRequestPackageInstalls()
        } catch (e: Exception) {
            true
        }
    }

    private fun abrirAjustesInstalacion() {
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"))
                )
            } catch (_: Exception) {
                // sin ajustes accesibles
            }
        }
    }
}

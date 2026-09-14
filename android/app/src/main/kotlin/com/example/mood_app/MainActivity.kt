package com.example.mood_app

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

    private val channelName = "moodapp/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstall" -> result.success(canRequestInstalls())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "launchInstaller" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "Falta la ruta del APK", null)
                        } else {
                            try {
                                launchInstaller(File(path))
                                result.success("ok")
                            } catch (e: Exception) {
                                result.error("install_error", e.message ?: "Fallo al instalar", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Android 8+: hay que darle una vez a CamiMood el permiso de instalar
    /// aplicaciones desconocidas. En versiones anteriores el toggle es global.
    private fun canRequestInstalls(): Boolean {
        if (Build.VERSION.SDK_INT < 26) return true
        return packageManager.canRequestPackageInstalls()
    }

    /// Abre la pantalla donde el usuario habilita "Permitir instalar
    /// aplicaciones desconocidas" para CamiMood.
    private fun openInstallSettings() {
        val intent = if (Build.VERSION.SDK_INT >= 26) {
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
        } else {
            Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    /// Abre el instalador nativo del sistema (ACTION_VIEW + FileProvider):
    /// Android muestra su diálogo de confirmación y se encarga de verificar
    /// e instalar. Es el flujo estándar de sideload que sí resuelve en
    /// equipos con Play Protect (el session silencioso quedaba colgado
    /// esperando al verificador).
    private fun launchInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
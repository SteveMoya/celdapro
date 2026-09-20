import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: las credenciales viven en android/key.properties, que NO se
// sube al repositorio (está en .gitignore). Si el archivo no existe —por
// ejemplo al compilar en local sin el keystore— se cae a la firma de depuración
// para que `flutter build apk` siga funcionando.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val tieneFirma = keystorePropertiesFile.exists()
if (tieneFirma) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "me.stevemoya.celdapro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "me.stevemoya.celdapro"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (tieneFirma) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (tieneFirma) {
                signingConfigs.getByName("release")
            } else {
                // Sin keystore: se firma con la clave de depuración para poder
                // probar la app. NO sirve para publicar en Google Play.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

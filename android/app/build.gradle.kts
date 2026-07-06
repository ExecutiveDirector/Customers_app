import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties, which you create
// locally (see KEYSTORE_AND_DISTRIBUTION.md) and never commit. Falls back
// to debug signing if that file isn't there yet, so this doesn't break
// `flutter run --release` before you've generated a keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.aquagas"
    compileSdk = 35 // Explicitly set
    ndkVersion = "27.0.12077973" // Force correct NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: before your first real beta/production release, change this
        // to your real, final Application ID and update `namespace` above to
        // match. It must exactly match the package name registered in your
        // Firebase project's google-services.json.
        applicationId = "com.example.Aquagas.Customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 34 // Explicitly set
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                // TODO: create android/key.properties (see
                // KEYSTORE_AND_DISTRIBUTION.md) — signing with the debug
                // keys until then, so `flutter run --release` still works.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
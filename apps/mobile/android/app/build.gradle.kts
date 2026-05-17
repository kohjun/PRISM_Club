import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// -----------------------------------------------------------------------------
// Release signing — reads key.properties next to this file when present.
//
// The properties file is intentionally NOT in the repo (it's gitignored
// alongside *.jks / *.keystore). Operators copy `key.properties.example` to
// `key.properties`, fill in real values, and store the keystore + passwords
// in the team password vault. See docs/ANDROID_RELEASE_DRY_RUN.md §3 for
// the exact shape, and docs/PLAY_INTERNAL_TESTING.md for the upload flow.
//
// When key.properties is absent:
//   • debug builds work unchanged.
//   • release builds STILL succeed, but fall back to the debug keystore
//     and print a clear, actionable Gradle warning. The resulting AAB is
//     rejected by Play Console at upload time. Operators should treat the
//     warning as a hard signal that something is missing — do not upload.
// -----------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists().also { exists ->
    if (exists) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "club.prism.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "club.prism.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                if (!storeFilePath.isNullOrBlank()) {
                    storeFile = file(storeFilePath)
                }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Loud, single-line warning at configure time so the
                // operator sees it in the build log. The fallback keeps
                // dry-run builds working but the resulting AAB is NOT
                // Play-uploadable. See ANDROID_RELEASE_DRY_RUN.md.
                logger.warn(
                    "[prism-club] android/key.properties not found — release " +
                        "build will be DEBUG-SIGNED and rejected by Play Console. " +
                        "Copy android/key.properties.example to android/key.properties " +
                        "and fill in the keystore values before uploading."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

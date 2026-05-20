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
    // SDK versions are pinned EXPLICITLY rather than inherited from
    // `flutter.compileSdkVersion / .minSdkVersion / .targetSdkVersion`
    // so release-build behavior is reproducible regardless of which
    // Flutter SDK version compiled the AAB. Without explicit pins,
    // a later Flutter upgrade silently shifts targetSdk and Play
    // Console may reject (or accept differently) the same source
    // tree across release machines.
    //
    //   compileSdk = 36  Android 16. Required by current plugin set
    //                    (flutter_plugin_android_lifecycle,
    //                    shared_preferences_android, url_launcher_android
    //                    all compile against API 36); building against
    //                    35 fails checkDebugAarMetadata.
    //   targetSdk  = 35  Android 15. Play Console floor for new app
    //                    submissions and updates since 2025-08-31
    //                    (https://support.google.com/googleplay/
    //                    android-developer/answer/11926878). Pinned
    //                    one below compileSdk so we don't opt into
    //                    Android 16 runtime behavior we haven't tested.
    //   minSdk     = flutter.minSdkVersion (resolves to 24 on Flutter
    //                    3.41.x — see FlutterExtension.kt in the
    //                    Flutter SDK). Above flutter_secure_storage's
    //                    floor (23) and above file_picker's floor
    //                    (19), so safe today. Left as the Flutter
    //                    reference because the Flutter Gradle tooling
    //                    silently reverts manual minSdk literals
    //                    during `flutter build` ("Upgrading
    //                    build.gradle.kts"); pinning it via literal
    //                    causes drift on every build. Track the
    //                    Flutter SDK upgrade for the next floor bump.
    //
    // Bump targetSdk when Play raises the floor. Bump compileSdk in
    // lockstep with the plugin set's requirement.
    compileSdk = 36
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
        // compileSdk + targetSdk are pinned above in the android{}
        // block. minSdk tracks Flutter's reference per the comment
        // there — do not change to a literal; the Flutter Gradle
        // tooling auto-reverts.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
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

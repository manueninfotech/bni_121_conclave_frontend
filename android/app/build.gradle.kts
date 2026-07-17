import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing credentials.
 *
 * android/key.properties is gitignored and points at a keystore OUTSIDE the
 * repo, so the key cannot be committed even by accident. Absent — a fresh clone,
 * or CI — release signing is skipped rather than failing the whole build, so
 * debug work still runs.
 */
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.manuen.conclave_1_2_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // mobile_scanner (ML Kit) and firebase-admin's transitive deps use APIs
        // above our minSdk; desugaring backports them instead of forcing minSdk up
        // and cutting off older phones — which at a BNI chapter is a real slice of
        // the room.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.manuen.conclave_1_2_1"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
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
            // Falls back to debug signing only when key.properties is absent, so
            // a clone still builds. A real release fails loudly instead — see the
            // check task below.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8: strips unused code and obfuscates. Roughly halves the APK, and
            // the app ships an offline SQLite mirror of the event plus Firebase
            // credentials — no reason to hand out readable class names.
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }

        debug {
            // Keep debug builds fast and readable.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

/**
 * Refuses to produce an unsigned "release".
 *
 * Without this, a missing key.properties silently signs with the DEBUG key. The
 * APK installs, runs, looks perfect — and Play rejects it, or worse, it gets
 * distributed and can never be updated by the real key. Fail at build time.
 */
tasks.register("verifyReleaseSigning") {
    doLast {
        if (!hasReleaseSigning) {
            throw GradleException(
                "No android/key.properties — a release build would be signed with the " +
                    "DEBUG key. See DEPLOYMENT.md."
            )
        }
    }
}

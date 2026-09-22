import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing.
//
// Create android/key.properties with:
//   storePassword=...
//   keyPassword=...
//   keyAlias=...
//   storeFile=<path to the .jks>       (absolute, or relative to android/)
//
// If the file is missing, the build falls back to the debug key so that
// `flutter build apk` never fails on a fresh clone.
// ---------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
var hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    val storePath = (keystoreProperties["storeFile"] ?: "").toString()
    val storeFile = if (File(storePath).isAbsolute) {
        File(storePath)
    } else {
        File(rootProject.projectDir, storePath)
    }
    hasKeystore = storeFile.exists()
    println("[signing] keystore = ${storeFile.absolutePath} (found=$hasKeystore)")
    if (!hasKeystore) {
        println("[signing] WARNING: keystore missing -> the release build will use the debug key.")
    }
} else {
    println("[signing] android/key.properties missing -> using the debug key for release builds.")
}

/** Resolve the keystore path: absolute as-is, otherwise relative to android/. */
fun resolveKeystore(raw: String): File {
    val f = File(raw)
    return if (f.isAbsolute) f else File(rootProject.projectDir, raw)
}

android {
    namespace = "com.qbrahym.vshapeapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.qbrahym.vsystem"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = resolveKeystore(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasKeystore) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            // R8 / resource shrinking are intentionally disabled: it keeps the
            // build light (works on small machines and free CI) and this app is
            // tiny anyway.
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
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

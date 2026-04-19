import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val dartDefines = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded)) }.getOrNull()
    }
    ?.associate { decoded ->
        val parts = decoded.split("=", limit = 2)
        parts[0] to parts.getOrElse(1) { "" }
    }
    ?: emptyMap()
val appEnvironment = dartDefines["APP_ENV"] ?: "development"
val requiresReleaseSigning = appEnvironment == "production"
val hardenReleaseBuild = appEnvironment == "production"

fun firstNonBlank(vararg values: String?): String? =
    values.firstOrNull { !it.isNullOrBlank() }?.trim()

fun isPlaceholderCredential(value: String?): Boolean {
    val normalized = value?.trim()?.lowercase() ?: return true
    if (normalized.isEmpty()) return true
    return normalized == "replace-me" ||
        normalized == "change-me" ||
        normalized == "replace_with_value" ||
        normalized.startsWith("your-") ||
        normalized.contains("placeholder")
}

if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val releaseStoreFile =
    firstNonBlank(
        providers.gradleProperty("FANZONE_UPLOAD_STORE_FILE").orNull,
        System.getenv("FANZONE_UPLOAD_STORE_FILE"),
        keystoreProperties.getProperty("storeFile"),
    )
val releaseStorePassword =
    firstNonBlank(
        providers.gradleProperty("FANZONE_UPLOAD_STORE_PASSWORD").orNull,
        System.getenv("FANZONE_UPLOAD_STORE_PASSWORD"),
        keystoreProperties.getProperty("storePassword"),
    )
val releaseKeyAlias =
    firstNonBlank(
        providers.gradleProperty("FANZONE_UPLOAD_KEY_ALIAS").orNull,
        System.getenv("FANZONE_UPLOAD_KEY_ALIAS"),
        keystoreProperties.getProperty("keyAlias"),
    )
val releaseKeyPassword =
    firstNonBlank(
        providers.gradleProperty("FANZONE_UPLOAD_KEY_PASSWORD").orNull,
        System.getenv("FANZONE_UPLOAD_KEY_PASSWORD"),
        keystoreProperties.getProperty("keyPassword"),
    )
val hasReleaseSigningConfig =
    listOf(
        releaseStoreFile,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).all { !it.isNullOrBlank() }
val hasValidReleaseKeystoreConfig =
    hasReleaseSigningConfig &&
        listOf(
            releaseStorePassword,
            releaseKeyAlias,
            releaseKeyPassword,
        ).none(::isPlaceholderCredential)

android {
    namespace = "com.fanzone.fanzone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.fanzone.football"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            debugSymbolLevel = "FULL"
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = hardenReleaseBuild
            isShrinkResources = hardenReleaseBuild
            if (hardenReleaseBuild) {
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro",
                )
            }
            if (hasValidReleaseKeystoreConfig) {
                signingConfig = signingConfigs.getByName("release")
            } else if (requiresReleaseSigning) {
                throw GradleException(
                    "Production Android builds require a valid upload keystore. " +
                        "Provide android/key.properties with real credentials " +
                        "or export FANZONE_UPLOAD_STORE_FILE, FANZONE_UPLOAD_STORE_PASSWORD, " +
                        "FANZONE_UPLOAD_KEY_ALIAS, and FANZONE_UPLOAD_KEY_PASSWORD.",
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

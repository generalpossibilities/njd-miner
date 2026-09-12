import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. `android/key.properties` is written by CI from repo secrets
// (see .github/workflows/build.yml) or created locally with tool/sync notes.
// When it is absent — a plain local build — we fall back to debug signing so
// `flutter run --release` still works.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseSigning = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.njd.njd_miner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_foreground_task / flutter_local_notifications need core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Distinct from main's com.njd.njd_miner so both builds can sit on the
        // same phone at once. Android keys an install on applicationId, so this
        // also gives the single-wallet build its own storage — its wallet and
        // mining keys are separate from the multi-wallet build's, not shared.
        //
        // `namespace` above is deliberately unchanged: that is the code package
        // MainActivity actually lives in, and moving it would break the manifest's
        // ".MainActivity" reference.
        applicationId = "com.njd.njd_miner.single"
        // flutter_inappwebview requires 21+; foreground service types push us to 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                keystoreProperties.getProperty("storeType")?.let { storeType = it }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties → debug keys. APKs from different machines
                // will NOT update over each other; provide signing to fix that.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}

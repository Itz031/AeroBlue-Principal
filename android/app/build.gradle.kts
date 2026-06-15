plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.aero_blue"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.aero_blue"
        minSdk = 26 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // --- BLOQUE DE FUERZA BRUTA ---
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.tools" && requested.name == "desugar_jdk_libs") {
                useVersion("2.1.4")
            }
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    // Aquí ya cambiamos a la 2.1.4 que es la que te pide el error
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
}
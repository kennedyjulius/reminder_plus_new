import java.io.FileInputStream
import java.util.Properties

val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    println("Loaded keystoreProperties: alias=${keystoreProperties.getProperty("keyAlias")} storeFile=${keystoreProperties.getProperty("storeFile")}")
} else {
    println("key.properties not found at ${keystorePropertiesFile.absolutePath}")
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.reminder.reminderplus"
    compileSdk = flutter.compileSdkVersion
    // Use the highest NDK version required by your dependencies (speech_to_text requires 28.2.13676358)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.reminder.reminderplus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["appAuthRedirectScheme"] = "com.reminder.reminderplus"
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword") ?: "Remind3rPlus!2026"
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: "upload"
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: "Remind3rPlus!2026"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Force consistent work-runtime versions to resolve conflicts
    implementation("androidx.work:work-runtime:2.8.1")
    implementation("androidx.work:work-runtime-ktx:2.8.1")
}

flutter {
    source = "../.."
}

// Apply Google Services plugin at the bottom
apply(plugin = "com.google.gms.google-services")

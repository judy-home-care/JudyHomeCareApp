plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add Google Services plugin for Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.judy_home_healthcare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    
    compileOptions {
        isCoreLibraryDesugaringEnabled = true  // ✅ ADDED
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    defaultConfig {
        applicationId = "com.example.judy_home_healthcare"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM (Bill of Materials)
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    
    // Firebase Cloud Messaging
    implementation("com.google.firebase:firebase-messaging-ktx")
    
    // Firebase Analytics (optional but recommended)
    implementation("com.google.firebase:firebase-analytics-ktx")
    
    // MultiDex support
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Core library desugaring ✅ ADDED
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
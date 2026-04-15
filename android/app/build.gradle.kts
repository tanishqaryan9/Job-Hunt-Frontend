plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must be applied after Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
    // Google services — applied HERE on the app module (not with `apply false`)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.jobhunt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.jobhunt"
        minSdk = flutter.minSdkVersion                          // Firebase Messaging requires >= 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM — controls all Firebase library versions consistently
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))

    // FCM — push notifications
    implementation("com.google.firebase:firebase-messaging-ktx")

    // Firebase Analytics (required by FCM for delivery reporting)
    implementation("com.google.firebase:firebase-analytics-ktx")
}

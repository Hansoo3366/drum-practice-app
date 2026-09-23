plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hansookim.pageadiddle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.hansookim.pageadiddle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Dropbox OAuth uses db-<APP_KEY>://oauth (must match App Console).
        manifestPlaceholders["appAuthRedirectScheme"] = "db-usuggo1fabglt8p"
    }

    flavorDimensions += "product"
    productFlavors {
        create("drum") {
            dimension = "product"
            applicationId = "com.hansookim.pageadiddle"
            resValue("string", "app_name", "Page-a-Diddle")
        }
        create("piano") {
            dimension = "product"
            applicationId = "com.hansookim.pianoscore"
            resValue("string", "app_name", "Piano Score")
        }
    }

    buildTypes {
        release {
            // Replace with a release keystore before Play Store upload.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

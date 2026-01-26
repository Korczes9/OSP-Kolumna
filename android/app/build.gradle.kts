// Plik Gradle na poziomie aplikacji (moduł)
// Module-level (app-level) build.gradle.kts

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
}

android {
    namespace = "pl.ospkolumna.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "pl.ospkolumna.app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    // Firebase BOM (Bill of Materials) - zarządza wersjami wszystkich SDK Firebase
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))

    // Firebase Authentication
    implementation("com.google.firebase:firebase-auth")

    // Cloud Firestore Database
    implementation("com.google.firebase:firebase-firestore")

    // Firebase Realtime Database
    implementation("com.google.firebase:firebase-database")

    // Firebase Cloud Messaging (Push notyfikacje)
    implementation("com.google.firebase:firebase-messaging")

    // Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")

    // Firebase Storage
    implementation("com.google.firebase:firebase-storage")

    // Android Core Libraries
    implementation("androidx.core:core:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")

    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.1")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

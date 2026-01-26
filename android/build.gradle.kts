// Plik Gradle na poziomie projektu
// Project-level build.gradle.kts

plugins {
    // Wtyczka dla Android Gradle
    id("com.android.application") version "8.1.0" apply false
    id("com.android.library") version "8.1.0" apply false
    
    // Wtyczka Kotlin
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false
    
    // Wtyczka Google Services dla Firebase
    id("com.google.gms.google-services") version "4.4.4" apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.4")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}

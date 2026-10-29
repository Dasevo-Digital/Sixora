plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = providers.environmentVariable("SIXORA_ANDROID_KEYSTORE").orNull
val releaseKeyAlias = providers.environmentVariable("SIXORA_ANDROID_KEY_ALIAS").orNull
val releaseStorePassword = providers.environmentVariable("SIXORA_ANDROID_STORE_PASSWORD").orNull
val releaseKeyPassword = providers.environmentVariable("SIXORA_ANDROID_KEY_PASSWORD").orNull
val releaseSigningValues = listOf(
    releaseKeystorePath,
    releaseKeyAlias,
    releaseStorePassword,
    releaseKeyPassword,
)
val releaseSigningConfigured = releaseSigningValues.all { !it.isNullOrBlank() }
if (!releaseSigningConfigured && releaseSigningValues.any { !it.isNullOrBlank() }) {
    throw GradleException("Die Android-Release-Signierung ist unvollständig konfiguriert.")
}

android {
    namespace = "de.status403.sixora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.status403.sixora"
        // Biometric prompt and Keystore-backed secure storage.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("sixoraRelease") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    // prod = the real app; dev = own application id and data, for tests on
    // devices that also run the real app (flutter run --flavor dev).
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Sixora")
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Sixora Dev")
            // Development releases are separate from the installed product.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("sixoraRelease")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val buildsProductRelease = allTasks.any {
        it.name.contains("ProdRelease", ignoreCase = true)
    }
    if (buildsProductRelease && !releaseSigningConfigured) {
        throw GradleException(
            "Produkt-Release abgebrochen: SIXORA_ANDROID_KEYSTORE, " +
                "SIXORA_ANDROID_KEY_ALIAS, SIXORA_ANDROID_STORE_PASSWORD und " +
                "SIXORA_ANDROID_KEY_PASSWORD müssen gesetzt sein.",
        )
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

dependencies {
    // AppCompat launch theme, required by the biometric prompt on Android 8.
    implementation("androidx.appcompat:appcompat:1.7.1")
    testImplementation("junit:junit:4.13.2")
}

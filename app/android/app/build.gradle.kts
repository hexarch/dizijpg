import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

// Bu derleme Play'e gidecek bir AAB mı, elle kurulacak bir APK mı?
// `flutter build appbundle` → `:app:bundleRelease`, `flutter build apk` →
// `:app:assembleRelease` görevini çalıştırır; ayrım görev adından yapılıyor.
// Neden gerekli: ABI kısıtı yalnız APK'da kazanç veriyor (aşağıdaki
// `buildTypes.release` yorumu), AAB'de ise ChromeOS/emülatör desteğini
// gereksizce kaybettiriyor.
val aabDerlemesiMi: Boolean = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true)
}

android {
    namespace = "com.dizijpg.dizijpg"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications için gerekli
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dizijpg.dizijpg"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isNotEmpty())
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")

            // md.51 — APK boyutu. Tek parça (universal) APK içine üç ABI'nin
            // yerel kütüphaneleri birlikte giriyordu; x86_64 çıkarıldığında
            // ölçülen boyut 119,6 MB → 77,3 MB oldu.
            //
            // KISIT YALNIZ APK'YA UYGULANIR, AAB'YE UYGULANMAZ:
            // Play, bundle'ı zaten cihazın ABI'sine göre böldüğü için kullanıcı
            // hiçbir zaman üç ABI'yi birden indirmiyor — yani AAB'den x86_64'ü
            // atmanın indirme boyutuna FAYDASI YOK, buna karşılık x86_64
            // ChromeOS cihazlar ve emülatörler Play sürümünü kuramaz hale gelir.
            // Kazanç sadece elle dağıtılan tek parça APK'da gerçek.
            //
            // `debug` de etkilenmez (blok `release` içinde): x86_64 emülatörde
            // geliştirme/hata ayıklama bozulmaz.
            //
            // `armeabi-v7a` LİSTEDEN ÇIKARILMAZ: çıkarılırsa 32 bit ARM
            // cihazlar uygulamayı kuramaz olur (devir notundaki yasak).
            if (!aabDerlemesiMi) {
                ndk {
                    abiFilters += listOf("armeabi-v7a", "arm64-v8a")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

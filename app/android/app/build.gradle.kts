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

// Gerçek yayın anahtarı elimizde mi? `key.properties` ve `.jks` GİZLİ, depoda
// yok (app/android/.gitignore) — yani taze bir kopyada bu bayrak false olur.
val imzaAnahtariVar: Boolean = keystoreProperties.isNotEmpty()

// Bu çağrı DAĞITILACAK imzalı bir paket mi üretiyor?
// `flutter build apk --release` → `:app:assembleRelease`,
// `flutter build appbundle --release` → `:app:bundleRelease`.
// `surumApkMi` bunun yerine geçmez: o yalnız APK'yı tanır, AAB'yi kaçırır ve
// Play'e giden asıl paket AAB'dir.
val surumPaketiMi: Boolean = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true) &&
        (it.contains("assemble", ignoreCase = true) ||
            it.contains("bundle", ignoreCase = true))
}

// Bilerek imzasız sürüm derlemesi için açık onay: `-PimzaYok=true`.
// Neden bir kaçış kapısı var: anahtarı olmayan biri (CI, yeni geliştirici)
// boyut/derleme ölçmek için sürüm paketi üretmek isteyebilir. Kapı AÇIK DEĞİL,
// elle açılıyor — yanlışlıkla debug anahtarına düşmek ile bilerek düşmek
// arasındaki fark budur.
val imzaYokOnayi: Boolean =
    (project.findProperty("imzaYok") as String?)?.toBoolean() == true

// Bu derleme Play'e gidecek bir AAB mı, elle kurulacak bir APK mı?
// `flutter build appbundle` → `:app:bundleRelease`, `flutter build apk` →
// `:app:assembleRelease` görevini çalıştırır; ayrım görev adından yapılıyor.
// Neden gerekli: ABI kısıtı yalnız APK'da kazanç veriyor (aşağıdaki
// `buildTypes.release` yorumu), AAB'de ise ChromeOS/emülatör desteğini
// gereksizce kaybettiriyor.
val aabDerlemesiMi: Boolean = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true)
}

// SÜRÜM APK'sı mı derleniyor? (`flutter build apk --release`)
//
// `aabDerlemesiMi`nin DEĞİLİ YETMEZ: o bayrak `assembleDebug` için de false
// döner, yani onu kullanan bir kısıt HATA AYIKLAMA derlemesini de vururdu —
// x86_64 emülatörde geliştirme bozulurdu. Bu bayrak "assemble" VE "release"
// ister; ikisi birden yalnız elle dağıtılan sürüm APK'sında doğrudur.
val surumApkMi: Boolean = gradle.startParameter.taskNames.any {
    it.contains("assemble", ignoreCase = true) &&
        it.contains("release", ignoreCase = true)
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
            // İMZA: SESSİZ DÜŞÜŞ YASAK (19 Ağu 2026).
            //
            // Eskiden `key.properties` yoksa burada HİÇBİR ŞEY SÖYLENMEDEN
            // hata ayıklama anahtarına düşülüyordu. Debug anahtarıyla imzalı
            // bir paket derleme çıktısında sürüm paketinden ayırt edilemez;
            // Play'e yüklenirse yükleme anahtarı uyuşmazlığıyla reddedilir,
            // elden dağıtılırsa gerçek anahtarla imzalı sürümün ÜZERİNE
            // kurulamaz (kullanıcı uygulamayı silmek zorunda kalır, verisi
            // gider). Bu yüzden UYARI DEĞİL, DURDURMA seçildi: uyarı Gradle
            // çıktısında kaybolur, hata kaybolmaz.
            //
            // HATA AYIKLAMA DERLEMESİ KIRILMAZ: kapı yalnız `assembleRelease`
            // / `bundleRelease` çağrılarında kapanıyor. `assembleDebug`,
            // `flutter run` ve Android Studio eşitlemesi anahtarsız çalışır.
            if (!imzaAnahtariVar && surumPaketiMi && !imzaYokOnayi) {
                error(
                    "İMZA ANAHTARI YOK: app/android/key.properties bulunamadı. " +
                        "Bu paket hata ayıklama anahtarıyla imzalanırdı — Play " +
                        "reddeder, elden kurulumda da sürümün üzerine gelmez. " +
                        "Anahtarı yerine koyun ya da bilerek imzasız derliyorsanız " +
                        "-PimzaYok=true verin.",
                )
            }
            if (!imzaAnahtariVar && surumPaketiMi) {
                logger.warn(
                    "UYARI: sürüm paketi HATA AYIKLAMA anahtarıyla imzalanıyor " +
                        "(-PimzaYok=true). Bu paket dağıtılamaz.",
                )
            }
            signingConfig = if (imzaAnahtariVar)
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
            //
            // 19 AĞU 2026 — BU BLOK ARTIK TEK BAŞINA YETMİYOR (ölçüldü).
            // `flutter build apk --release` ile derlenen APK 122,1 MB çıktı ve
            // İÇİNDE ÜÇ ABI DE VARDI: `lib/x86_64/libapp.so`,
            // `libflutter.so`, `libjingle_peerconnection_so.so`. Yani yukarıdaki
            // `abiFilters` çağrısının GÖZLENEBİLİR HİÇBİR ETKİSİ KALMAMIŞ —
            // Flutter Gradle eklentisi `-Ptarget-platform`dan türettiği ABI
            // kümesini bizim bloğumuzdan SONRA yazıyor ve üzerine biniyor.
            // Blok yine de duruyor: eklenti davranışı değişirse tekrar tutar,
            // dururken de zarar vermiyor. Gerçek kısıt aşağıdaki `packaging`.
            if (!aabDerlemesiMi) {
                ndk {
                    abiFilters += listOf("armeabi-v7a", "arm64-v8a")
                }
            }
        }
    }

    // ABI KISITININ GERÇEKTEN UYGULANDIĞI YER (19 Ağu 2026).
    //
    // `buildTypes.release.ndk.abiFilters` etkisiz kaldığı için (yukarıdaki
    // not) x86_64 kütüphaneleri APK'ya giriyordu. `--target-platform
    // android-arm,android-arm64` bayrağı Flutter'ın KENDİ kütüphanelerini
    // (`libapp.so`, `libflutter.so`) dışarıda bırakıyor ama EKLENTİLERİN
    // getirdiklerini bırakmıyor: flutter_webrtc'nin hazır derlenmiş
    // `libjingle_peerconnection_so.so`su tek başına 15,3 MB. Paketleme
    // süzgeci ikisini de kesiyor, üstelik bayrağa bağlı kalmadan.
    //
    // YALNIZ SÜRÜM APK'sında: AAB'de x86_64 KALMALI (Play zaten cihaza göre
    // bölüyor; atmanın indirme boyutuna faydası yok, buna karşılık ChromeOS
    // ve emülatör kullanıcıları uygulamayı kuramaz olur). Hata ayıklama
    // derlemesi de etkilenmez — x86_64 emülatörde geliştirme sürüyor.
    if (surumApkMi) {
        packaging {
            jniLibs {
                excludes += "lib/x86_64/**"
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

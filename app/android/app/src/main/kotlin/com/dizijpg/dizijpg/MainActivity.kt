package com.dizijpg.dizijpg

import android.app.Activity
import android.content.ClipboardManager
import android.net.Uri
import android.os.Build
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * EKRAN GÖRÜNTÜSÜ TESPİTİ (15 Eyl 2026 isteği: sohbette "ekran görüntüsü
 * alındı" yazısı).
 *
 * Android 14 (API 34) ile gelen `Activity.registerScreenCaptureCallback`
 * kullanılır: sistem, ekran görüntüsü alındığında ÖN PLANDAKİ etkinliğe
 * haber verir. `DETECT_SCREEN_CAPTURE` izni manifest'te (normal izin —
 * kullanıcıya diyalog çıkmaz).
 *
 * API 34 ALTINDA TESPİT YOKTUR ve taklidi de yapılmaz: eski uygulamalar
 * bunun için MediaStore'u `FileObserver` ile dinliyordu, ki bu hem depolama
 * izni ister hem de başka uygulamanın kaydettiği her görseli "ekran
 * görüntüsü" sayar. Yanlış alarm, hiç uyarmamaktan kötüdür.
 *
 * Kanal Dart tarafında `ekran_goruntusu.dart`; olay gövdesiz (null) gider,
 * anlamı "şimdi bir ekran görüntüsü alındı".
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val KANAL = "dizijpg/ekran_goruntusu"
        const val PANO_KANAL = "dizijpg/pano"

        /** Panodan alınacak tek dosya tavanı — sunucudaki `/medya` sınırıyla aynı. */
        const val PANO_AZAMI_BAYT = 100L * 1024 * 1024
    }

    private var akis: EventChannel.EventSink? = null

    // Tip `Any?`: `Activity.ScreenCaptureCallback` API 34 sınıfıdır ve alan
    // tipi olarak yazılırsa eski sürümlerde sınıf çözümlemesi patlayabilir.
    private var geriCagri: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, KANAL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    akis = sink
                }

                override fun onCancel(args: Any?) {
                    akis = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PANO_KANAL)
            .setMethodCallHandler { cagri, sonuc ->
                when (cagri.method) {
                    "varMi" -> sonuc.success(panodaMedyaVar())
                    "oku" -> sonuc.success(panoyuOku())
                    else -> sonuc.notImplemented()
                }
            }
    }

    /**
     * Panoda görsel/video var mı — YALNIZ `primaryClipDescription` okunur.
     *
     * `getPrimaryClip()` ÇAĞRILMAZ: Android 12+ panoyu OKUYAN uygulama için
     * ekranda "… panodan yapıştırdı" bildirimi gösteriyor. Düğmeyi çizmek
     * için içeriğe ihtiyacımız yok; türü bilmek yetiyor. İçerik ancak
     * kullanıcı düğmeye BASINCA ([panoyuOku]) okunur.
     */
    private fun panodaMedyaVar(): Boolean {
        val pano = getSystemService(ClipboardManager::class.java) ?: return false
        val tanim = pano.primaryClipDescription ?: return false
        for (i in 0 until tanim.mimeTypeCount) {
            if (medyaTuru(tanim.getMimeType(i))) return true
        }
        return false
    }

    /**
     * Panodaki görsel/video dosyalarını ÖNBELLEK DİZİNİNE kopyalar ve
     * `{yol, ad, tur}` listesini döner.
     *
     * NEDEN DOSYA, NEDEN BAYT DEĞİL: platform kanalı baytı ana iş
     * parçacığında kopyalar; 20 MB'lık bir ekran görüntüsü kareyi düşürür.
     * Dart tarafı yolu `XFile` ile tembel okur — sistem seçicisinden gelen
     * dosyayla aynı nesne, aynı yükleme hattı.
     *
     * `content://` URI'si okunamazsa (izin süresi dolmuş, kaynak uygulama
     * silinmiş) o öğe SESSİZCE atlanır; kalanlar yine gelir.
     */
    private fun panoyuOku(): List<Map<String, String>> {
        val pano = getSystemService(ClipboardManager::class.java) ?: return emptyList()
        val kirpma = pano.primaryClip ?: return emptyList()
        val cikti = mutableListOf<Map<String, String>>()
        for (i in 0 until kirpma.itemCount) {
            val uri: Uri = kirpma.getItemAt(i).uri ?: continue
            val tur = contentResolver.getType(uri) ?: continue
            if (!medyaTuru(tur)) continue
            val dosya = kopyala(uri, tur) ?: continue
            cikti.add(mapOf("yol" to dosya.absolutePath, "ad" to dosya.name, "tur" to tur))
        }
        return cikti
    }

    private fun medyaTuru(tur: String?): Boolean =
        tur != null && (tur.startsWith("image/") || tur.startsWith("video/"))

    private fun kopyala(uri: Uri, tur: String): File? = try {
        val uzanti = MimeTypeMap.getSingleton().getExtensionFromMimeType(tur) ?: "bin"
        // `createTempFile` benzersizliği İŞLETİM SİSTEMİNE bırakır: aynı
        // milisaniyede iki öğe yapıştırılırsa elle üretilen ad çakışır ve
        // ikinci dosya birincinin üstüne yazardı. Dosyalar önbellek
        // dizinindedir; sistem yer daralınca kendisi siler.
        val hedef = File.createTempFile("pano-", ".$uzanti", cacheDir)
        contentResolver.openInputStream(uri)?.use { girdi ->
            hedef.outputStream().use { cikti ->
                // Tavanı AŞAN dosya hiç yazılmaz: yükleme hattı zaten
                // reddederdi, ama önce diske 300 MB yazmanın anlamı yok.
                var toplam = 0L
                val tampon = ByteArray(64 * 1024)
                while (true) {
                    val okunan = girdi.read(tampon)
                    if (okunan <= 0) break
                    toplam += okunan
                    if (toplam > PANO_AZAMI_BAYT) {
                        hedef.delete()
                        return null
                    }
                    cikti.write(tampon, 0, okunan)
                }
            }
        } ?: return null
        hedef
    } catch (_: Exception) {
        null
    }

    // Kayıt onStart/onStop çiftinde: arka plandaki ekran görüntüsü bizi
    // ilgilendirmez ve sistem zaten yalnız görünür etkinliğe haber verir.
    override fun onStart() {
        super.onStart()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val cb = Activity.ScreenCaptureCallback { akis?.success(null) }
            geriCagri = cb
            registerScreenCaptureCallback(mainExecutor, cb)
        }
    }

    override fun onStop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            (geriCagri as? Activity.ScreenCaptureCallback)?.let {
                unregisterScreenCaptureCallback(it)
            }
            geriCagri = null
        }
        super.onStop()
    }
}

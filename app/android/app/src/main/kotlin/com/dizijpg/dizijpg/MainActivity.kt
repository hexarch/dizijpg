package com.dizijpg.dizijpg

import android.app.Activity
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

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

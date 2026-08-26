/// OTURUM DÜŞTÜ KATMANI — sunucu token'ı reddettiğinde (401) devreye girer.
///
/// ---------------------------------------------------------------------------
/// HANGİ HATAYI ÇÖZÜYOR (26 Ağu 2026, kullanıcı bildirdi)
/// ---------------------------------------------------------------------------
/// Kullanıcı: *"dün tüm oturumları kapattık ama oturumdan atmak yerine
/// bağlantı koptu hatası veriyor, neden otomatik çıkış yapmadı, web ve
/// Android'de aynı mı?"*
///
/// Evet, aynıydı — `api.dart` iki platformda ORTAK. Sunucu tarafı doğru
/// çalışıyordu: "tüm oturumları kapat" `kullanicilar.sifre_surumu`nu artırır,
/// eski token'lar `girisZorunlu` içinde 401 + "Oturum sonlandı" alır. Ama
/// istemcide 401 HİÇ ÖZEL İŞLENMİYORDU (`kod == 401` araması tüm uygulamada
/// boştu): `Api._isle` genel bir `ApiHata` fırlatıyor, ekranlar da bunu
/// "yüklenemedi / bağlantı hatası" olarak gösteriyordu. Token ve yerel
/// `kullanici` kaydı yerinde kaldığı için uygulama hâlâ "girişli" görünüyor,
/// fakat her istek düşüyordu.
///
/// ---------------------------------------------------------------------------
/// TASARIM KARARLARI
/// ---------------------------------------------------------------------------
///  * SESSİZ ÇIKIŞ YOK: kullanıcı bir anda giriş ekranında bulunursa "uygulama
///    beni attı, neden?" diye düşünür. Önce NE OLDUĞUNU söyleyen bir diyalog
///    çıkar, sonra çıkış yapılır. (Sessizce çalışmayan bir uygulama en kötü
///    deneyimdir — `Api.yasak` notundaki aynı gerekçe.)
///  * KAPATILAMAZ DİYALOG (`barrierDismissible: false`): oturum zaten ölü;
///    arkadaki ekranda gezinmek her dokunuşta yeni bir hata üretirdi.
///  * TEK SEFER: bayrak diyalog açılır açılmaz indirilir. Ekranda paralel
///    çalışan beş istek varsa beşi de 401 alır; koruma olmasaydı üst üste
///    beş diyalog açılırdı.
///  * ÇIKIŞ `Oturum.cikis()` İLE: yalnız token silmek yetmez — kitaplık
///    önbelleği, içerik deposu ve Google oturumu da kapanmalı (aynı
///    metodun içinde yapılıyor), yoksa sonraki kullanıcı öncekinin
///    kitaplığını görür.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';

/// [Api.oturumDustu] bayrağını dinleyip kullanıcıyı bilgilendiren ve
/// oturumu kapatan sarmalayıcı. Kabuğun en dışında bir kez kurulur.
class OturumDustuKatmani extends StatefulWidget {
  final Widget child;
  const OturumDustuKatmani({super.key, required this.child});

  @override
  State<OturumDustuKatmani> createState() => _OturumDustuKatmaniState();
}

class _OturumDustuKatmaniState extends State<OturumDustuKatmani> {
  bool _gorunur = false;
  bool _cikisYapiliyor = false;

  @override
  void initState() {
    super.initState();
    Api.oturumDustu.addListener(_degisti);
  }

  @override
  void dispose() {
    Api.oturumDustu.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() {
    if (!Api.oturumDustu.value || _gorunur || !mounted) return;
    // Bayrağı HEMEN indir: yolda olan diğer istekler de 401 alacak ve
    // dinleyiciyi yeniden tetikleyecek; `_gorunur` ikinci bir kalkan.
    Api.oturumDustuTemizle();
    // 401 NEREDEN GELİYOR: neredeyse her zaman bir ağ isteğinin `await`
    // dönüşünden, yani build/layout DIŞINDAN. O durumda doğrudan setState
    // doğru ve anında çalışır.
    //
    // `addPostFrameCallback` TEK BAŞINA YETMEZ (26 Ağu 2026 testinde
    // yakalandı): bayrak bir setState'ten değil düz bir atamadan geldiği
    // için yeni bir kare PLANLANMAZ ve kayıtlı geri çağrı hiç çalışmaz —
    // katman sessizce açılmıyordu. Bu yüzden yalnız GERÇEKTEN build
    // aşamasındaysak kareyi bekliyoruz.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _gorunur = true);
      });
    } else {
      setState(() => _gorunur = true);
    }
  }

  void _cik() {
    if (_cikisYapiliyor) return;
    _cikisYapiliyor = true;
    // ÇIKIŞ BEKLENMEZ (26 Ağu 2026 widget testinde yakalandı):
    // `Oturum.cikis()` birkaç alt adım yapıyor ve bunlardan biri —
    // Google oturumunu kapatma — ağ yokken ya da eklentisiz bir ortamda
    // HİÇ TAMAMLANMAYABİLİYOR. `await` etseydik katman sonsuz bir dönen
    // göstergeyle açık kalır, kullanıcı hiçbir şey yapamazdı.
    //
    // Beklemenin bir kazancı da yok: yerel oturum ZATEN geçersiz, sunucu
    // token'ı çoktan reddetti. Temizlik arka planda sürerken kullanıcıyı
    // giriş ekranına almak hem doğru hem hızlı.
    unawaited(context.read<Oturum>().cikis().catchError((_) {}));
    setState(() {
      _gorunur = false;
      _cikisYapiliyor = false;
    });
    // `go` (push değil): geri tuşuyla ölü oturuma dönülmesin.
    GoRouter.of(context).go('/giris');
  }

  @override
  Widget build(BuildContext context) {
    if (!_gorunur) return widget.child;
    // `showDialog` DEĞİL, GÖVDEYE GÖMÜLÜ KATMAN (26 Ağu 2026):
    // showDialog kök Navigator'a bir rota iter; kabuk GoRouter'ın iç içe
    // Navigator'ları altında yaşadığı için rota kimi zaman hiç görünmüyordu
    // (widget testinde yakalandı: diyalog sayısı 0). Gövdeye gömülü katman
    // hangi Navigator'da olduğumuzdan BAĞIMSIZ çizilir ve test edilebilir.
    return Stack(
      children: [
        widget.child,
        // Arkadaki ekrana dokunmayı engelle: oturum zaten ölü, her dokunuş
        // yeni bir 401 üretirdi.
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: DiziRenkler.koyuGri,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout,
                        color: DiziRenkler.sariMetin,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Oturumun sonlandı'.c,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu hesabın oturumları kapatıldı ya da şifresi değişti. '
                                'Devam etmek için tekrar giriş yap.'
                            .c,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DiziRenkler.metin70),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _cikisYapiliyor ? null : _cik,
                          child: _cikisYapiliyor
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text('Giriş Yap'.c),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

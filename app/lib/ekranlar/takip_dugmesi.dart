import 'package:flutter/material.dart';

import '../api.dart';
import '../ceviri.dart';
import '../tema.dart';
import 'giris_istem.dart';

/// KULLANICI LİSTELERİNDEKİ TAKİP / TAKİBİ BIRAK DÜĞMESİ (tek tanım noktası).
///
/// Kullanıcı isteği (8 Ağu 2026): *"Profilimden takipçilerime baktığımda solda
/// profil resmi yanında isim görüyorum ya, sağda da takip etmiyorsam 'takip
/// et' butonu, takip ediyorsam 'takibi bırak' butonu olmalı. ... Bir gönderiyi
/// beğenenlere baktığımda falan da aynı şekilde olacak."*
///
/// Bu düğme beş listede birden çizilir (kendi takipçilerim / takip
/// ettiklerim, başkasının takipçileri / takip ettikleri, gönderiyi
/// beğenenler) ve kullanıcı aramasında da aynısı görünür. Daha önce yalnız
/// `begenenler.dart` içinde satır içi yazılmıştı; ikinci ekran gelince
/// kopyalanacaktı — `gonderiPaylas`/`begenenleriAc` derslerinin aynısı.
/// Bu yüzden ORTAK PARÇA: davranış (iyimser güncelleme, geri alma, spinner,
/// giriş istemi) tek yerde durur.
///
/// TASARIM KARARLARI
/// * **Kendi satırında düğme YOK** ([benMi]) — sunucu `POST /takip/:ad`
///   isteğine zaten 400 döner; düğmeyi hiç göstermemek dürüst olan.
/// * **Takip ETMİYORSAM birincil** (marka sarısı dolgu + siyah metin,
///   temanın `filledButtonTheme`i), **ediyorsam ikincil** (dolgusuz,
///   kenarlıklı). Böylece "yeni bağ kur" eylemi öne çıkar, "bağı kopar"
///   eylemi geri planda kalır — yanlışlıkla basılması zorlaşır.
/// * **Onay modalı YOK.** Takibi bırakmak yıkıcı değil, geri alması tek
///   dokunuş; modal akışı yavaşlatırdı. Yerine düğmenin çevresine boşluk
///   bırakılır (satırda addan 12px uzakta) ve düğme ikincil görünür.
/// * **Üç hâl:** dokunuşta düğme KİLİTLENİR + spinner → başarıda etiket
///   yeni duruma geçer → hatada ESKİ hâle döner + SnackBar.
/// * **Dokunma hedefi ≥44dp:** görsel yükseklik 36, ama
///   `MaterialTapTargetSize.padded` dokunma kutusunu 48'e büyütür
///   (`pro-rules.md`: "expand hit area when icon is smaller").
/// * **Uzun çeviri taşmaz:** en uzunlar Tamilce "பின்தொடர்வதை நிறுத்து" ve
///   Lehçe "Przestań obserwować". Etiket kısaltılıp (ellipsis) okunmaz hâle
///   getirilmez; düğme [_azamiGenislik]e kadar büyür, dar ekranda etiket
///   `FittedBox(scaleDown)` ile küçülür. Ellipsis bir düğme etiketinde
///   ("Przestań obser…") ne yapacağını gizler, ölçek küçültmek gizlemez.
class TakipDugmesi extends StatefulWidget {
  /// Takip edilecek/bırakılacak kişinin kullanıcı adı (`POST /takip/:ad`).
  final String kullaniciAdi;

  /// Başlangıç durumu. Sunucudan `takip_ediyorum` geliyorsa o; gelmiyorsa
  /// çağıran taraf tek seferlik toplu sorguyla ([takipKumesiGetir]) çözer.
  final bool takipEdiyorum;

  /// Bu satır giriş yapan kullanıcının kendisi mi? True ise hiçbir şey çizilmez.
  final bool benMi;

  /// Yeni durum (true = takipteyim). Çağıran taraf paylaşılan haritayı
  /// tazelemek için kullanır; iyimser değişimde ve geri almada da çağrılır.
  final ValueChanged<bool>? onDegisti;

  const TakipDugmesi({
    super.key,
    required this.kullaniciAdi,
    required this.takipEdiyorum,
    this.benMi = false,
    this.onDegisti,
  });

  /// Satır sonundaki düğmenin alabileceği en fazla genişlik. 360dp'lik
  /// telefonda avatar + ad + boşluklardan sonra kalan paya sığar.
  static const double _azamiGenislik = 156;

  @override
  State<TakipDugmesi> createState() => _TakipDugmesiState();
}

class _TakipDugmesiState extends State<TakipDugmesi> {
  late bool _takipte = widget.takipEdiyorum;
  bool _isleniyor = false;

  @override
  void didUpdateWidget(TakipDugmesi eski) {
    super.didUpdateWidget(eski);
    // Liste tazelendiğinde dışarıdan gelen durum kazanır — ama süren bir
    // istek varken değil (yoksa iyimser güncelleme geri sekerdi).
    if (!_isleniyor && widget.takipEdiyorum != eski.takipEdiyorum) {
      _takipte = widget.takipEdiyorum;
    }
  }

  Future<void> _bas() async {
    if (_isleniyor) return;
    if (!girisGerekli(context)) return; // oturumsuz → nazik giriş istemi
    final eski = _takipte;
    setState(() {
      _isleniyor = true;
      _takipte = !eski; // İYİMSER: etiket anında değişir
    });
    widget.onDegisti?.call(_takipte);
    try {
      final d = await Api.takipToggle(widget.kullaniciAdi);
      final sunucu = d['takip'] == true;
      widget.onDegisti?.call(sunucu);
      if (!mounted) return;
      setState(() {
        _takipte = sunucu;
        _isleniyor = false;
      });
    } catch (e) {
      // GERİ ALMA + sesli hata (skill madde 3: sessiz başarısızlık yasak).
      widget.onDegisti?.call(eski);
      if (!mounted) return;
      setState(() {
        _takipte = eski;
        _isleniyor = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.benMi) return const SizedBox.shrink();
    final etiket = _takipte ? 'Takibi Bırak'.c : 'Takip Et'.c;
    // Spinner etiketin ÜSTÜNDE çizilir (etiket görünmez ama yerini korur):
    // düğme genişliği işlem sırasında zıplamaz.
    final govde = _isleniyor
        ? Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0, child: Text(etiket)),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _takipte ? DiziRenkler.sariMetin : Colors.black,
                ),
              ),
            ],
          )
        : FittedBox(fit: BoxFit.scaleDown, child: Text(etiket));

    // HIT-TEST TUZAĞI: kullanıcı listelerinde SATIRIN KENDİSİ de tıklanabilir
    // (profile gider). Düğme işlem sürerken KİLİTLİ olduğundan InkWell'i
    // tanıyıcısız kalır ve sabırsız ikinci dokunuş satıra SIZAR — kullanıcı
    // takip etmeye çalışırken profile fırlatılırdı. Buradaki boş
    // GestureDetector o dokunuşu yutar; düğme etkinken kendi InkWell'i daha
    // derinde olduğu için arenayı o kazanır, davranış değişmez.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: TakipDugmesi._azamiGenislik,
        ),
        // Tooltip hem masaüstünde üzerine gelince hem ekran okuyucuda "kim"
        // olduğunu söyler: bir listede 30 tane "Takip Et" düğmesi ayırt
        // edilemezdi. (Semantics+ExcludeSemantics ile sarmalamak düğmenin
        // erişilebilirlik EYLEMİNİ de silerdi — tooltip silmez.)
        child: Tooltip(
          message: '$etiket · @${widget.kullaniciAdi}',
          child: _takipte
              ? OutlinedButton(
                  onPressed: _isleniyor ? null : _bas,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: DiziRenkler.metin,
                    disabledForegroundColor: DiziRenkler.metin54,
                    side: BorderSide(color: DiziRenkler.metin24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: govde,
                )
              : FilledButton(
                  onPressed: _isleniyor ? null : _bas,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    // Kilitliyken de sarı kalır (soluk): düğme "bozuldu"
                    // gibi görünmesin, yalnız beklendiği anlaşılsın.
                    disabledBackgroundColor: DiziRenkler.sari.withValues(
                      alpha: 0.55,
                    ),
                    disabledForegroundColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: govde,
                ),
        ),
      ),
    );
  }
}

/// GİRİŞ YAPANIN TAKİP ETTİKLERİ — tek istekte, satır başına sorgu YOK.
///
/// `/takipciler/:ad`, `/takipedilenler/:ad` ve `/kullanici-ara` uçları satır
/// başına `takip_ediyorum` DÖNDÜRMÜYOR (yalnız `kullanici_adi`, `avatar`,
/// `bio`). Düğmenin başlangıç durumu bilinmeden çizilemez: uç bir TOGGLE
/// olduğu için yanlış başlangıç "takip et" sanılan dokunuşu TAKİBİ BIRAK'a
/// çevirirdi. Çözüm, listeyle PARALEL tek bir ek istek: kendi takip
/// ettiklerimin kullanıcı adı kümesi. 500 satırlık bir liste 500 istek değil
/// 1 istek eder.
///
/// SINIR: uç `LIMIT 500` uyguluyor. 500'den fazla kişi takip eden bir hesapta
/// kümenin dışında kalan satırlar "Takip Et" görünür. Kalıcı çözüm sunucunun
/// bu üç uca `takip_ediyorum` (+ `ben_mi`) eklemesidir; o gün burası silinir.
///
/// `null` döner = durum BİLİNMİYOR (ağ hatası). Çağıran taraf o hâlde düğmeyi
/// HİÇ çizmemeli — yanlış yönde toggle atmaktansa düğmesiz liste yeğdir.
Future<Set<String>?> takipKumesiGetir(String? benimKullaniciAdim) async {
  if (benimKullaniciAdim == null || benimKullaniciAdim.isEmpty) {
    // Oturumsuz ziyaretçi kimseyi takip etmiyor: durum BİLİNİYOR (boş küme),
    // düğme çizilir ve dokunuş giriş istemini açar.
    return Api.girisli ? null : <String>{};
  }
  try {
    // Md. 21: uç artık {kullanicilar, gizli} döner. Bu çağrı KENDİ listemiz
    // için — sahibine gizlilik uygulanmaz, liste hep dolu gelir.
    final l =
        (await Api.takipEdilenler(benimKullaniciAdim))['kullanicilar']
            as List<dynamic>? ??
        const [];
    return {
      for (final u in l)
        if ((u as Map<String, dynamic>)['kullanici_adi'] is String)
          u['kullanici_adi'] as String,
    };
  } catch (_) {
    return null;
  }
}

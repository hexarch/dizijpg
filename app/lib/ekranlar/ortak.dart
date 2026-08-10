import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// PosterIzgarasi kendi SliverGridLayout'unu üretiyor: SliverConstraints,
// SliverGridLayout ve SliverGridRegularTileLayout material'dan gelmiyor.
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../altyazi.dart';
import '../api.dart';
import '../icerik_deposu.dart';
import '../kitaplik_durumu.dart';
import '../ceviri.dart';
import '../tema.dart';
import '../veri_tasarrufu.dart';
import 'medya_goster.dart';

/// Yorum/akış postlarındaki fotoğraf-video galerisi.
/// Tek medya: TAM GENİŞLİK, yükseklik medyanın KENDİ oranından — her post
/// kendi boyutunda (aşırı uzunlar üst sınırda ortadan kırpılır). Çoklu (2-4):
/// 2 sütun kare ızgara. Videoda büyük kapak + dokununca TAM EKRAN oynatıcı.
/// otomatikOynat=true (akış) ile kapak yerine yerinde oynatıcı: ekran ortasına
/// gelen video sessiz başlar, uzaklaşınca durur — AkisVideo aynı anda tek
/// video oynatır, bu yüzden birden çok oynatıcı çakışıp çift ses vermez.
class MedyaGaleri extends StatelessWidget {
  final List<String> yollar; // /medya/... yolları
  /// Verilirse medyaya dokununca bu çağrılır (indeks); yoksa tam ekran
  /// görüntüleyici (medyaGoster) açılır. Akış bunu Reels açmak için kullanır.
  final void Function(int index)? onAc;

  /// Çift dokunuş = beğeni; akış kartından geçilir.
  final VoidCallback? onCiftDokunus;

  /// Akışta: videolar kapak yerine yerinde (sessiz) oynar.
  final bool otomatikOynat;

  const MedyaGaleri({
    super.key,
    required this.yollar,
    this.onAc,
    this.onCiftDokunus,
    this.otomatikOynat = false,
  });

  static bool _video(String m) => m.endsWith('.mp4') || m.endsWith('.webm');

  @override
  Widget build(BuildContext context) {
    if (yollar.isEmpty) return const SizedBox.shrink();
    final urller = [for (final m in yollar) dosyaUrl(m)!];
    // Akış: TAM GENİŞLİK kaydırmalı görüntüleyici (ilk medya önce, yana
    // kaydırınca sonraki) — ızgara/kırpma yok, yükseklik postun kendi oranı.
    if (otomatikOynat) {
      return AkisMedya(
        urller: urller,
        onAc: onAc,
        onCiftDokunus: onCiftDokunus,
      );
    }
    Widget hucre(int i) {
      final video = _video(yollar[i]);
      return InkWell(
        onTap: () => onAc != null
            ? onAc!(i)
            : medyaGoster(context, urller, baslangic: i),
        child: video
            ? (otomatikOynat
                  ? AkisVideo(url: urller[i])
                  // Video kapağı: koyu zemin + beyaz oynat (tema-bağımsız,
                  // videolar koyu görünür — açık temada da görünür kalır)
                  : Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ))
            : CachedNetworkImage(
                imageUrl: urller[i],
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: DiziRenkler.kart),
                errorWidget: (_, _, _) => Container(
                  color: DiziRenkler.kart,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: DiziRenkler.metin38,
                  ),
                ),
              ),
      );
    }

    if (yollar.length == 1) {
      // Tek medya: genişlik tam dolar, yükseklik medyanın KENDİ oranından
      // gelir — her post kendi boyutunda.
      final video = _video(yollar[0]);
      Widget icerik;
      if (video) {
        // AkisVideo oranını oynatıcıdan verir; kapak modunda oran bilinmez → 16:9
        icerik = otomatikOynat
            ? AkisVideo(url: urller[0])
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
      } else {
        // Görsel doğal oranında tam genişlik; aşırı uzun görseller akışı
        // yutmasın diye yükseklik genişliğin 1.5 katıyla sınırlı (taşan
        // kısım ortalanıp kırpılır).
        icerik = LayoutBuilder(
          builder: (context, kisit) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: kisit.maxWidth * 1.5),
            child: CachedNetworkImage(
              imageUrl: urller[0],
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, _) =>
                  Container(height: 220, color: DiziRenkler.kart),
              errorWidget: (_, _, _) => Container(
                height: 220,
                color: DiziRenkler.kart,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: DiziRenkler.metin38,
                ),
              ),
            ),
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onAc != null
              ? onAc!(0)
              : medyaGoster(context, urller, baslangic: 0),
          child: icerik,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
        children: [for (var i = 0; i < yollar.length; i++) hucre(i)],
      ),
    );
  }
}

/// Akıştaki postun medya görüntüleyicisi: TAM GENİŞLİK, yükseklik postun
/// ilk medyasının kendi oranından. Birden çok medya varsa yana kaydırılır
/// (ilk medya her zaman başta), altta nokta göstergesi + sayaç görünür.
class AkisMedya extends StatefulWidget {
  final List<String> urller;
  final void Function(int index)? onAc;

  /// Çift dokunuş = beğeni (Instagram davranışı). Verilmezse çift dokunuş
  /// tek dokunuş gibi davranır ve gönderi açılırdı — kullanıcı bildirdi.
  final VoidCallback? onCiftDokunus;

  /// Oran BİLİNİYORSA (ör. bölüm kareleri hep 16:9) verilir: ölçüm beklenmez,
  /// kutu ilk karede doğru yüksekliğe kurulur — yükleme sonrası zıplama olmaz.
  final double? oran;

  /// Tüm kareler kutuyu KAPLASIN mı (BoxFit.cover). Akışta kutu ilk medyanın
  /// oranındadır, sonrakiler kırpılmasın diye sığdırılır (contain). Detay
  /// sayfasının başlığında ise kutu sabit yüksekliktedir ve tüm kapaklar aynı
  /// (16:9) orandadır: contain olsaydı ilk kapak kutuyu doldurur, kaydırınca
  /// gelenler yanlarda siyah bantla belirir — aynı boyda görseller arasında
  /// tutarsız görünürdü.
  final bool tumunuKapla;

  /// Sayaç rozetinin üstten ek boşluğu. Rozet normalde kutunun sağ üstünde
  /// durur; detay sayfasında görselin üstüne üst çubuk biner, rozet oraya
  /// denk gelip "Giriş Yap" düğmesiyle çakışırdı.
  final double sayacUstBosluk;

  /// Görselin ÜSTÜNE ama nokta/sayaç göstergelerinin ALTINA çizilen katman
  /// (detay sayfasının alta doğru koyulaşan karartması). Stack'in en üstüne
  /// konsaydı karartmanın opak alt ucu noktaları yutardı.
  final Widget? gorselUstu;

  const AkisMedya({
    super.key,
    required this.urller,
    this.onAc,
    this.onCiftDokunus,
    this.oran,
    this.tumunuKapla = false,
    this.sayacUstBosluk = 0,
    this.gorselUstu,
  });

  @override
  State<AkisMedya> createState() => _AkisMedyaState();
}

class _AkisMedyaState extends State<AkisMedya> {
  static bool _video(String u) => u.endsWith('.mp4') || u.endsWith('.webm');

  /// Sayaç (1/3) ne kadar görünür kalır. Kullanıcı isteği: "ilk gördüğünde
  /// 3 saniye sonra kaybolacak".
  static const sayacSuresi = Duration(seconds: 3);

  double? _oran; // ilk medyanın oranı (bilinene dek 4:5)
  int _sayfa = 0;
  ImageStream? _akis;
  ImageStreamListener? _dinleyici;

  /// Sayacı her "göster" isteğinde artar; TweenAnimationBuilder'ın anahtarı
  /// olduğu için geri sayım baştan başlar. 0 = henüz görülmedi.
  int _sayacTetik = 0;
  bool _hicGoruldu = false;

  @override
  void initState() {
    super.initState();
    _oran = widget.oran;
    // İlk medya görselse doğal oranını ölç (video kendi oranını bildirir)
    if (_oran == null && !_video(widget.urller.first)) {
      final saglayici = CachedNetworkImageProvider(widget.urller.first);
      _akis = saglayici.resolve(const ImageConfiguration());
      _dinleyici = ImageStreamListener((bilgi, _) {
        if (!mounted || _oran != null) return;
        final o = bilgi.image.width / bilgi.image.height;
        setState(() => _oran = o.clamp(0.5, 16 / 9).toDouble());
      }, onError: (_, _) {});
      _akis!.addListener(_dinleyici!);
    }
  }

  /// Sayacı göster ve 3 sn sonra söndür. Sayfa değişince yeniden çağrılır:
  /// kullanıcı kaydırdığında "kaçıncı fotoğraftayım" bilgisi tekrar belirir.
  void _sayaciGoster() {
    if (widget.urller.length < 2 || !mounted) return; // tek medyada sayaç yok
    setState(() => _sayacTetik++);
  }

  /// Geri sayım kart KURULUNCA değil GERÇEKTEN GÖRÜLÜNCE başlar: liste
  /// ilerideki kartları ~5 ekran önceden kurar (cacheExtent), sayaç orada
  /// başlasaydı kullanıcı kaydırıp geldiğinde çoktan sönmüş olurdu.
  void _gorunurluk(VisibilityInfo bilgi) {
    if (_hicGoruldu || bilgi.visibleFraction < 0.5 || !mounted) return;
    _hicGoruldu = true;
    _sayaciGoster();
  }

  @override
  void dispose() {
    if (_akis != null && _dinleyici != null) {
      _akis!.removeListener(_dinleyici!);
    }
    super.dispose();
  }

  /// Sayaç rozeti (1/3). Sönme bir ZAMANLAYICIYLA değil animasyonla yapılır:
  /// bekleyen Timer, kartı 3 sn beklemeden biten her widget testinde
  /// "A Timer is still pending" hatası verirdi.
  Widget _sayacRozeti() {
    // Medya her temada koyu zemin üstünde durur → siyah/beyaz burada kasıtlı
    // (tema rengi değil) ve iki temada da okunur.
    final rozet = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_sayfa + 1}/${widget.urller.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    // Henüz görülmedi: geri sayım başlamaz, rozet tam görünür bekler.
    if (_sayacTetik == 0) return rozet;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_sayacTetik),
      tween: Tween(begin: 1, end: 0),
      duration: sayacSuresi + _sonmeSuresi,
      // İlk 3 sn tam görünür, son 250 ms'de söner.
      curve: Interval(
        sayacSuresi.inMilliseconds /
            (sayacSuresi + _sonmeSuresi).inMilliseconds,
        1,
      ),
      builder: (_, deger, cocuk) => Opacity(opacity: deger, child: cocuk),
      child: rozet,
    );
  }

  static const _sonmeSuresi = Duration(milliseconds: 250);

  void _oranBildir(double o) {
    if (!mounted || _oran != null) return;
    setState(() => _oran = o.clamp(0.5, 16 / 9).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final coklu = widget.urller.length > 1;
    return VisibilityDetector(
      key: ValueKey('sayac-${widget.urller.first}'),
      onVisibilityChanged: _gorunurluk,
      child: AspectRatio(
        aspectRatio: _oran ?? 4 / 5,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: widget.urller.length,
              // Komşu sayfa önden kurulur: yana kaydırınca hazır gelir.
              // Veri tasarrufu açıkken (varsayılan: mobil veride) kapalı —
              // ayarın sözü "yalnız bakılan kare yüklenir"; bakılmayan komşu
              // kapağı peşin indirmek onu bozardı.
              allowImplicitScrolling: VeriTasarrufu.onYuklemeSerbest,
              onPageChanged: (i) {
                setState(() => _sayfa = i);
                _sayaciGoster(); // yeni kare → sayaç yeniden belirir, yine söner
              },
              itemBuilder: (context, i) {
                final url = widget.urller[i];
                return GestureDetector(
                  onTap: () => widget.onAc != null
                      ? widget.onAc!(i)
                      : medyaGoster(context, widget.urller, baslangic: i),
                  onDoubleTap: widget.onCiftDokunus,
                  child: _video(url)
                      ? AkisVideo(
                          url: url,
                          kendiOrani: false,
                          onOran: i == 0 ? _oranBildir : null,
                        )
                      : Container(
                          color: Colors.black,
                          child: CachedNetworkImage(
                            imageUrl: url,
                            // İlk medya oranı kutuyu belirlediği için o tam
                            // oturur; diğerleri kırpılmadan sığdırılır.
                            fit: widget.tumunuKapla || i == 0
                                ? BoxFit.cover
                                : BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (_, _) =>
                                Container(color: DiziRenkler.kart),
                            errorWidget: (_, _, _) => Container(
                              color: DiziRenkler.kart,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: DiziRenkler.metin38,
                              ),
                            ),
                          ),
                        ),
                );
              },
            ),
            if (widget.gorselUstu != null)
              Positioned.fill(child: IgnorePointer(child: widget.gorselUstu!)),
            if (coklu) ...[
              // Sayaç (1/3): medyanın SAĞ ÜSTÜNDE; ilk görüldüğünde belirir,
              // 3 sn sonra söner (kaydırınca yeniden belirir).
              Positioned(
                top: 10 + widget.sayacUstBosluk,
                right: 10,
                child: IgnorePointer(child: _sayacRozeti()),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.urller.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _sayfa ? Colors.white : Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Akışta yerinde oynayan video. Kart ekranda belirir belirmez (daha merkeze
/// gelmeden) yüklenmeye başlar — eşzamanlı hazırlanan video sayısı sınırlıdır.
/// Ekran ortasına EN YAKIN görünür video sessiz oynar, merkezden uzaklaşınca
/// (veya başka kart merkeze gelince) durur; statik aday kaydıyla aynı anda
/// yalnız BİR video oynar. Ses kapalı başlar (web otomatik oynatma kuralı);
/// sağ alttaki hoparlör rozeti oturum boyu ortak ses tercihini açar.
class AkisVideo extends StatefulWidget {
  final String url;

  /// Kendi en-boy oranına göre yer kaplasın mı (AkisMedya kutuyu kendisi
  /// belirlediği için false verir).
  final bool kendiOrani;

  /// Oran öğrenilince bildirilir (post yüksekliğini belirlemek için).
  final ValueChanged<double>? onOran;

  const AkisVideo({
    super.key,
    required this.url,
    this.kendiOrani = true,
    this.onOran,
  });

  @override
  State<AkisVideo> createState() => _AkisVideoState();
}

class _AkisVideoState extends State<AkisVideo> {
  /// Görünür adaylar → ekran merkezine dikey uzaklık (px). En yakını oynar.
  static final Map<_AkisVideoState, double> _adaylar = {};
  static _AkisVideoState? _aktif;
  static bool _sesli = false; // oturum boyu ortak ses tercihi

  /// Aynı anda hazırlanan (buffer'lanan) video sayısı. Liste ilerideki
  /// kartları önden kurar; sınır olmasa onlarca çözücü/indirme açılır ve
  /// hem bellek şişer hem oynayan video için bant genişliği kalmazdı.
  static int _hazirSayi = 0;
  static const int _hazirUst = 6;

  VideoPlayerController? _d;
  Future<void>? _kurulum;
  bool _hata = false;
  bool _sayildi = false; // bu kart hazır sayacına dahil edildi mi

  @override
  void initState() {
    super.initState();
    // ÖNDEN YÜKLEME: kart listede kurulur kurulmaz (henüz ekranda bile
    // olmayabilir) video hazırlanmaya başlar; kaydırınca beklenmez.
    if (_hazirSayi < _hazirUst) _kurulum ??= _kur();
  }

  void _gorunurluk(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction < 0.55) {
      _adaylar.remove(this);
    } else {
      final kutu = context.findRenderObject();
      var uzaklik = 0.0;
      if (kutu is RenderBox && kutu.attached) {
        final merkez = kutu.localToGlobal(kutu.size.center(Offset.zero)).dy;
        uzaklik = (merkez - MediaQuery.of(context).size.height / 2).abs();
      }
      _adaylar[this] = uzaklik;
    }
    _secimiUygula();
  }

  /// Merkeze en yakın adayı oynat; öncekini (aday kalmadıysa aktifi) durdur.
  static void _secimiUygula() {
    _AkisVideoState? enYakin;
    var enKucuk = double.infinity;
    _adaylar.forEach((aday, uzaklik) {
      if (uzaklik < enKucuk) {
        enKucuk = uzaklik;
        enYakin = aday;
      }
    });
    if (enYakin == _aktif) return;
    _aktif?._d?.pause();
    _aktif = enYakin;
    _aktif?._oynat();
  }

  Future<void> _oynat() async {
    _kurulum ??= _kur();
    await _kurulum;
    final d = _d;
    // Kurulum sürerken kart merkezden çıktıysa başlatma
    if (!mounted || d == null || _aktif != this) return;
    await d.setVolume(_sesli ? 1 : 0);
    await d.play();
  }

  Future<void> _kur() async {
    _hazirSayi++;
    _sayildi = true;
    try {
      final d = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await d.initialize();
      if (!mounted) {
        d.dispose();
        return;
      }
      d.setLooping(true);
      setState(() => _d = d);
      // Postun yüksekliği videonun kendi oranından belirlensin
      if (d.value.aspectRatio > 0) widget.onOran?.call(d.value.aspectRatio);
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
  }

  void _sesDegistir() {
    _sesli = !_sesli;
    _d?.setVolume(_sesli ? 1 : 0);
  }

  @override
  void dispose() {
    _adaylar.remove(this);
    if (_aktif == this) _aktif = null;
    if (_sayildi) _hazirSayi--; // yer aç: sıradaki kart önden kurulabilsin
    _d?.dispose();
    // Liste karttan kurtulduysa sıradaki görünür video devralsın
    _secimiUygula();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    Widget govde;
    if (_hata) {
      govde = const Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 44,
          color: Colors.white38,
        ),
      );
    } else if (d == null) {
      // Henüz kurulmadı: siyah duraklatılmış kapak
      govde = const Center(
        child: Icon(Icons.play_circle_outline, size: 52, color: Colors.white),
      );
    } else {
      govde = ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: d,
        builder: (_, v, _) => Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
                child: VideoPlayer(d),
              ),
            ),
            if (!v.isPlaying)
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 52,
                  color: Colors.white70,
                ),
              ),
            if (v.isPlaying)
              Positioned(
                right: 2,
                bottom: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _sesDegistir,
                  // 44px dokunma hedefi: saydam kenar + küçük görünür rozet
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        v.volume > 0 ? Icons.volume_up : Icons.volume_off,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    // Altyazı: videonun KENDİ kutusunun sol altında (kart sıralaması değişse
    // de yeri değişmez; 2026-08-03'te gönderi metni araya girdi).
    // Kendi katmanında durur ve yalnız cümle değişince çizilir —
    // oynatma konumu saniyede onlarca kez değişse de kart yeniden çizilmez.
    // Sağ alttaki ses rozetinin altına girmesin diye genişlik sınırlı (0.72).
    // IgnorePointer içinde: çift dokunuş (beğeni) ve tek dokunuş engellenmez.
    final Widget icerik = Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black, child: govde),
        AltyaziKatmani(denetleyici: d, url: widget.url, genislikOrani: 0.72),
      ],
    );
    final kutu = VisibilityDetector(
      key: ValueKey('akis-video-${widget.url}'),
      onVisibilityChanged: _gorunurluk,
      child: icerik,
    );
    if (!widget.kendiOrani) return kutu; // kutuyu AkisMedya belirledi
    // Kutunun oranı videonun KENDİ oranı: genişlik tam dolar, yükseklik
    // posta göre değişir. Oran bilinene dek 16:9.
    final oran = (d != null && d.value.isInitialized && d.value.aspectRatio > 0)
        ? d.value.aspectRatio.clamp(0.5, 21 / 9).toDouble()
        : 16 / 9;
    return AspectRatio(aspectRatio: oran, child: kutu);
  }
}

/// Gönderi metni + "Çevir" düğmesi. Çeviri sunucuda HAZIRSA (ceviri_var)
/// ve gönderinin dili kullanıcının dilinden farklıysa düğme görünür; basınca
/// tek istekle çeviri gelir ve oturum boyunca yeniden istenmez.
/// Metni her ekran kendi biçiminde çizsin diye gövde `yapici` ile verilir.
class CeviriliMetin extends StatefulWidget {
  final int yorumId;

  /// Gösterilecek metin. Sunucu, okuyanın dilinde hazır çeviri varsa BURAYA
  /// çeviriyi koyar (kullanıcı düğmeye basmadan kendi dilinde okur).
  final String metin;
  final String? kaynakDil;

  /// Sunucu çeviriyi zaten uyguladıysa true; o zaman düğme "Orijinali göster"
  /// olur ve [orijinalMetin] ile geri dönülür.
  final bool cevrildi;
  final String? orijinalMetin;

  /// Çeviri hazır AMA sunucu uygulamadıysa (eski uçlar) "Çevir" düğmesi çıkar.
  final bool ceviriVar;
  final Widget Function(String metin) yapici;
  final Color? dugmeRengi;

  const CeviriliMetin({
    super.key,
    required this.yorumId,
    required this.metin,
    required this.kaynakDil,
    required this.ceviriVar,
    required this.yapici,
    this.cevrildi = false,
    this.orijinalMetin,
    this.dugmeRengi,
  });

  @override
  State<CeviriliMetin> createState() => _CeviriliMetinState();
}

class _CeviriliMetinState extends State<CeviriliMetin> {
  String? _ceviri;
  bool _cevrili = false;
  bool _yukleniyor = false;
  // Sunucunun uyguladığı çeviride: orijinale dönüldü mü?
  bool _orijinalde = false;

  Future<void> _degistir() async {
    if (_ceviri != null) {
      setState(() => _cevrili = !_cevrili);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final d = await Api.get(
        '/ceviri/${widget.yorumId}?dil=${Ceviri.dil.value}',
      );
      if (!mounted) return;
      final m = d['metin'] as String?;
      setState(() {
        _yukleniyor = false;
        if (m != null && m.isNotEmpty) {
          _ceviri = m;
          _cevrili = true;
        }
      });
      // Sessiz başarısızlık yok: çeviri gelmediyse kullanıcı bilsin.
      if ((m == null || m.isEmpty) && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Çeviri şu an yapılamadı'.c)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Çeviri şu an yapılamadı'.c)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sunucu çeviriyi zaten uyguladıysa: metin kullanıcının dilinde gelir,
    // düğme yalnızca orijinale dönmek için durur.
    final sunucuCevirdi = widget.cevrildi && widget.orijinalMetin != null;
    // Dil bilinmiyorsa ya da zaten kullanıcının dilindeyse düğme yok
    final farkliDil =
        widget.kaynakDil != null && widget.kaynakDil != Ceviri.dil.value;
    final gosterilsin =
        sunucuCevirdi || (farkliDil && (widget.ceviriVar || _ceviri != null));
    final govde = sunucuCevirdi
        ? (_orijinalde ? widget.orijinalMetin! : widget.metin)
        : (_cevrili ? (_ceviri ?? widget.metin) : widget.metin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.yapici(govde),
        if (gosterilsin)
          InkWell(
            onTap: sunucuCevirdi
                ? () => setState(() => _orijinalde = !_orijinalde)
                : (_yukleniyor ? null : _degistir),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_yukleniyor)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DiziRenkler.sari,
                      ),
                    )
                  else
                    Icon(
                      Icons.translate,
                      size: 14,
                      color: widget.dugmeRengi ?? DiziRenkler.sariMetin,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    sunucuCevirdi
                        ? (_orijinalde
                              ? 'Çeviriyi göster'.c
                              : 'Orijinali göster'.c)
                        : (_cevrili ? 'Orijinali göster'.c : 'Çevir'.c),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.dugmeRengi ?? DiziRenkler.sariMetin,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Poster kartı: dokununca detaya gider.

/// "Bunu izledin" rozeti: poster kartlarının sağ üstünde.
///
/// ÇİFT RENK: arkada biraz büyük SİYAH ikon, önde BEYAZ ikon. Poster açık da
/// olsa koyu da olsa okunur — tek renk ikon bazı posterlerde kayboluyordu.
class IzlendiRozeti extends StatelessWidget {
  final double boyut;
  const IzlendiRozeti({super.key, this.boyut = 17});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.remove_red_eye, size: boyut + 3, color: Colors.black87),
          Icon(Icons.remove_red_eye, size: boyut, color: Colors.white),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// POSTER ÖLÇÜLERİ (tek kaynak)
///
/// Şikâyet (6 Ağu 2026): "masaüstü görünüşte film dizi kapak görselleri çok
/// kötü duruyor". ÖLÇÜM: ızgaraların hepsinde `crossAxisCount` 3'e SABİTLENMİŞ
/// (kitaplık, izlediklerim, arama, kişi, karşılama). 1512 dp'lik bir pencerede
/// bu, kart başına ~486 dp genişlik demek; `devicePixelRatio` 2 ile 972
/// fiziksel piksel gerekirken TMDB'den 342 px çekiliyordu → 2,84x büyütme.
/// Üstelik `childAspectRatio: 0.5` sabiti kart genişledikçe hücrenin ALTINDA
/// 80 dp'ye varan boşluk bırakıyordu (poster 2:3 + başlık, hücrenin yarısı).
///
/// Çözüm iki parça: (1) sütun sayısı genişlikten türetilir, (2) hücre yüksekliği
/// posterin GERÇEK 2:3 oranından hesaplanır. TMDB boyutu ise [posterBoyutu] ile
/// ölçülen kart genişliğinden seçilir.
/// ---------------------------------------------------------------------------

/// Masaüstünde bir poster kartının hedeflenen genişliği (dp).
///
/// 168 dp → 252 dp poster yüksekliği; 2x ekranda 336 fiziksel piksel, yani
/// TMDB `w342` TAM oturur (büyütme yok). Daha geniş kart w500'e çıkar ve bant
/// genişliğini ~2 katına taşır, daha darı masaüstünde minik görünür.
const double posterKartHedefGenisligi = 168;

/// Poster kartında başlık bloğunun ayırdığı yükseklik (dp).
///
/// `SizedBox(height: 6)` + 12 pt, EN FAZLA 2 satır başlık. Poppins'te satır
/// yüksekliği ~18 dp → 6 + 36 = 42; test ortamında yedek yazı tipiyle ~34.
/// 46 seçildi: ikisini de taşırmadan, hücrede 4 dp'den fazla ölü boşluk
/// bırakmadan karşılar. (Eskiden `childAspectRatio` sabitiyle bu pay kart
/// genişliğine ORANTILI büyüyordu; masaüstünde 80 dp boşluk oradan geliyordu.)
const double posterBaslikYuksekligi = 46;

/// Yatay poster şeridinde TELEFON kart genişliği (dp) — [PosterKarti]'nın
/// varsayılanı ve şeridin bugünkü ölçüsü. Değiştirme: mobil düzen buna bağlı.
const double seritKartGenisligi = 118;

/// Şerit yüksekliğinde posterin altına bırakılan pay (dp).
/// 118 * 1.5 + 59 = 236 → BUGÜNKÜ şerit yüksekliğinin birebir aynısı.
const double seritBaslikPayi = 59;

/// Yatay şeritteki kart genişliği. Masaüstünde büyür — 1512 dp'lik pencerede
/// 118 dp'lik telefon kartından 12 tane yan yana dizilince posterler pul gibi
/// kalıyordu. İSKELET DE bunu kullanmalı, yoksa içerik gelince düzen zıplar.
double seritKartiGenisligi(BuildContext context) =>
    masaustuMu(context) ? posterKartHedefGenisligi : seritKartGenisligi;

/// Poster ızgarasında sütun sayısı.
///
/// [kullanilabilirGenislik] ızgaranın YATAY DOLGU ÇIKARILMIŞ genişliği.
///
/// TELEFON DEĞİŞMEZ: [masaustuEsigi] mantığıyla aynı sonuç için alt sınır 3 —
/// 360-430 dp telefonlarda hesap 2 çıkar ve 3'e sabitlenir, yani bugünkü
/// düzenin AYNISI. Geniş ekranda kart genişliği hedefe en yakın kalacak sütun
/// sayısı seçilir (aşağı yuvarlama devasa kartlar bırakıyordu → `round`).
int posterSutunlari(double kullanilabilirGenislik, {double bosluk = 10}) {
  if (!kullanilabilirGenislik.isFinite || kullanilabilirGenislik <= 0) return 3;
  final adet =
      (kullanilabilirGenislik + bosluk) / (posterKartHedefGenisligi + bosluk);
  return adet.round().clamp(3, 12);
}

/// Poster ızgarası: sütun sayısını GERÇEK ızgara genişliğinden türetir, hücre
/// yüksekliğini posterin 2:3 oranı + [posterBaslikYuksekligi] kadar verir.
///
/// `SliverGridDelegateWithFixedCrossAxisCount` yerine bu kullanılıyor çünkü
/// oradaki `crossAxisCount` ve `childAspectRatio` SABİT: ekran genişliğini
/// ancak `MediaQuery` ile tahmin edebilir, ızgaranın kendi dolgusunu bilemez.
/// `getLayout` ise `constraints.crossAxisExtent` ile ÖLÇÜLMÜŞ genişliği alır.
class PosterIzgarasi extends SliverGridDelegate {
  /// Sütunlar arası boşluk.
  final double bosluk;

  /// Satırlar arası boşluk.
  final double satirBoslugu;

  /// Kartın posterin altında başlığa ayırdığı yükseklik. Başlıksız ızgaralarda
  /// (karşılama ekranı gibi) 0 verilir → hücre birebir 2:3 olur.
  final double baslikYuksekligi;

  const PosterIzgarasi({
    this.bosluk = 10,
    this.satirBoslugu = 14,
    this.baslikYuksekligi = posterBaslikYuksekligi,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final genislik = constraints.crossAxisExtent;
    final sutun = posterSutunlari(genislik, bosluk: bosluk);
    final kart = (genislik - bosluk * (sutun - 1)) / sutun;
    // Poster 2:3 → yükseklik = genişlik * 1.5. Kırpma/gerilme YOK.
    final yukseklik = kart * 1.5 + baslikYuksekligi;
    return SliverGridRegularTileLayout(
      crossAxisCount: sutun,
      mainAxisStride: yukseklik + satirBoslugu,
      crossAxisStride: kart + bosluk,
      childMainAxisExtent: yukseklik,
      childCrossAxisExtent: kart,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(PosterIzgarasi eski) =>
      eski.bosluk != bosluk ||
      eski.satirBoslugu != satirBoslugu ||
      eski.baslikYuksekligi != baslikYuksekligi;
}

class PosterKarti extends StatelessWidget {
  final Map<String, dynamic> icerik;
  final String? turZorla; // multi aramada media_type gelir; trendlerde belli
  final double genislik;

  const PosterKarti({
    super.key,
    required this.icerik,
    this.turZorla,
    this.genislik = 118,
  });

  @override
  Widget build(BuildContext context) {
    final tur = turZorla ?? icerik['media_type'] as String? ?? 'tv';
    final ad = icerik['name'] ?? icerik['title'] ?? '?';
    final puan = (icerik['vote_average'] as num?)?.toDouble() ?? 0;
    final tmdbId = (icerik['id'] as num?)?.toInt();

    // TMDB boyutu ÖLÇÜLEN kart genişliğinden seçilir; [genislik] ızgaralarda
    // `double.infinity` geldiği için tek başına yeterli değil — hücrenin
    // gerçek genişliğini yalnız LayoutBuilder bilir.
    //
    // DİKKAT: taban w342'nin ALTINA inilmez ([posterBoyutu]); burada w185
    // denenmiş ve GERİ ALINMIŞTI — 3x ekranda 118 dp kart 354 fiziksel piksel
    // demek, w185 büyütülüp gözle görülür bulanıklaşıyor.
    return SizedBox(
      width: genislik,
      child: LayoutBuilder(
        builder: (context, kisit) => _kart(
          context,
          kisit.maxWidth.isFinite && kisit.maxWidth > 0
              ? kisit.maxWidth
              : genislik,
          tur,
          ad,
          puan,
          tmdbId,
        ),
      ),
    );
  }

  Widget _kart(
    BuildContext context,
    double kartGenisligi,
    String tur,
    Object ad,
    double puan,
    int? tmdbId,
  ) {
    final pikselOrani = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final posterYolu = posterUrl(
      icerik['poster_path'] as String?,
      boyut: posterBoyutu(kartGenisligi, pikselOrani),
    );
    // NOT: `memCacheWidth` (karta göre kod çözme) denendi ve ŞİMDİLİK
    // ELENDİ — Flutter web'de ResizeImage yolunu gerçek tarayıcıda
    // doğrulayamadım (yerel ölçüm düzeneğinde poster katmanı hiç boyanmıyor,
    // bu değişiklikten BAĞIMSIZ olarak). Doğru boyutu ZATEN sunucudan
    // istediğimiz için görsel kazanç yok; yalnız bellek optimizasyonu olurdu.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/icerik/$tur/${icerik['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: posterYolu == null
                      ? Container(
                          color: DiziRenkler.kart,
                          child: Icon(
                            Icons.movie,
                            color: DiziRenkler.metin24,
                            size: 40,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterYolu,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: DiziRenkler.kart),
                          errorWidget: (_, __, ___) => Container(
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.broken_image,
                              color: DiziRenkler.metin24,
                            ),
                          ),
                        ),
                ),
              ),
              // Sağ üst: bu içeriği izlediysen göz rozeti. Kitaplık
              // değişince (izlemeye başla/bırak) anında güncellenir.
              if (tmdbId != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: ValueListenableBuilder<int>(
                    valueListenable: KitaplikDurumu.surum,
                    builder: (context, _, _) =>
                        KitaplikDurumu.izlendiMi(tur, tmdbId)
                        ? const IzlendiRozeti()
                        : const SizedBox.shrink(),
                  ),
                ),
              if (puan > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: DiziRenkler.sari,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          puan.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ad as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Yatay şeritlerin (poster/oyuncu) ortak başlık satırı.
///
/// Başlık ASLA kırpılmaz — 45 dilin bazılarında raf adları çok uzun
/// ("Ταινίες με τις περισσότερες προβολές", "Pinakamataas ang rating na
/// pelikula"). Bunu üç önlemle garantiliyoruz:
///  1. Başlık [Expanded] — kalan TÜM genişliği alır. (Eskiden `Flexible` +
///     `Spacer()` vardı; ikisi de esnek olduğu için boş alan yarı yarıya
///     bölünüyordu ve "Haftanın Dizileri" gibi KISA başlıklar bile üç noktaya
///     düşüyordu. Asıl hata buydu.)
///  2. `maxLines` yok — sığmayan başlık alt satıra sarar, kesilmez.
///  3. Dar ekranda (<400 dp) "Tümünü gör" metni gizlenir, yalnız ok kalır;
///     başlığa ~90 dp daha yer açılır. Dokunma hedefi satırın tamamıdır
///     (>=44 dp), yani ok küçülse de dokunulabilirlik değişmez.
class SeritBasligi extends StatelessWidget {
  /// Başlığın solundaki işaret (sarı çubuk, ikon vb.) — isteğe bağlı.
  final Widget? oncu;
  final String baslik;

  /// Başlıktan sonra gelen soluk küçük metin, ör. oyuncu sayısı "(24)".
  final String? ek;

  /// Verilirse satır tıklanabilir olur ve "Tümünü gör" + ok gösterilir.
  final VoidCallback? onTap;

  const SeritBasligi({
    super.key,
    required this.baslik,
    this.oncu,
    this.ek,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dar = MediaQuery.sizeOf(context).width < 400;
    final satir = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          if (oncu != null) ...[oncu!, const SizedBox(width: 8)],
          Expanded(
            // Text.rich (RichText DEĞİL) — DefaultTextStyle'ı devralır, ama
            // koyu/açık tema karışmasın diye taban rengi yine de açıkça verilir.
            child: Text.rich(
              TextSpan(
                text: baslik,
                children: ek == null
                    ? null
                    : [
                        TextSpan(
                          text: '  $ek',
                          style: TextStyle(
                            color: DiziRenkler.metin54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
              ),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DiziRenkler.metin,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            if (!dar)
              Text(
                'Tümünü gör'.c,
                style: TextStyle(
                  color: DiziRenkler.sariMetin,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Icon(Icons.chevron_right, size: 20, color: DiziRenkler.sariMetin),
          ],
        ],
      ),
    );
    if (onTap == null) return satir;
    // Semantik etiket: dar ekranda metin gizlendiği için ok tek başına kalıyor;
    // ekran okuyucu yine "<başlık>, Tümünü gör" duyar.
    return Semantics(
      button: true,
      label: '$baslik, ${'Tümünü gör'.c}',
      child: InkWell(onTap: onTap, child: satir),
    );
  }
}

/// Yatay poster şeridi (başlık + liste).
class PosterSeridi extends StatelessWidget {
  final String baslik;
  final List<dynamic> icerikler;
  final String? turZorla;

  /// Verilirse başlık tıklanabilir olur ("Tümünü gör" + ok) — şerit yalnız
  /// ilk sayfayı gösterir, tam liste ayrı ekranda sayfalanarak açılır.
  final VoidCallback? onBaslikTap;

  const PosterSeridi({
    super.key,
    required this.baslik,
    required this.icerikler,
    this.turZorla,
    this.onBaslikTap,
  });

  @override
  Widget build(BuildContext context) {
    if (icerikler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeritBasligi(
          baslik: baslik,
          onTap: onBaslikTap,
          oncu: Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: DiziRenkler.sari,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Builder(
          builder: (context) {
            // Telefonda ölçüler BİREBİR aynı kalır (118 / 236).
            final kart = seritKartiGenisligi(context);
            return SizedBox(
              height: kart * 1.5 + seritBaslikPayi,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: icerikler.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => PosterKarti(
                  icerik: icerikler[i] as Map<String, dynamic>,
                  turZorla: turZorla,
                  genislik: kart,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Kitaplık/ızgara içeriği: detayını sunucu önbelleğinden çekip poster gösterir.
class MiniIcerik extends StatefulWidget {
  final int tmdbId;
  final String tur;
  final double genislik;

  /// Dizi ilerleme rozeti için izlenen bölüm sayısı (isteğe bağlı).
  final int? izlenenSayi;

  const MiniIcerik({
    super.key,
    required this.tmdbId,
    required this.tur,
    this.genislik = 105,
    this.izlenenSayi,
  });

  @override
  State<MiniIcerik> createState() => _MiniIcerikState();
}

class _MiniIcerikState extends State<MiniIcerik> {
  Map<String, dynamic>? _icerik;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    // Tek tek /tmdb/{tur}/{id} çağırmak yerine toplu depo: aynı karedeki
    // tüm karolar TEK istekte alınır (61 KB/karo yerine ~150 bayt).
    IcerikDeposu.getir(widget.tur, widget.tmdbId).then((d) {
      if (!mounted) return;
      // Bulunamadıysa sonsuz iskelet yerine kırık görsel göster
      setState(() => d == null ? _hata = true : _icerik = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hata) {
      // genislik double.infinity olabilir → sabit yükseklik yerine oran kullan
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            color: DiziRenkler.kart,
            child: Icon(
              Icons.broken_image_outlined,
              color: DiziRenkler.metin38,
            ),
          ),
        ),
      );
    }
    if (_icerik == null) {
      return IskeletKutu(genislik: widget.genislik);
    }
    final kart = PosterKarti(
      icerik: _icerik!,
      turZorla: widget.tur,
      genislik: widget.genislik,
    );
    // Dizi ilerlemesi: posterin üstünde dolum barı.
    // Sarı = izlenen oran; tamamı izlendiyse turuncu.
    final toplam = (_icerik!['number_of_episodes'] as num?)?.toInt() ?? 0;
    final izlenen = widget.izlenenSayi ?? 0;
    if (widget.tur != 'tv' || toplam <= 0 || izlenen <= 0) return kart;
    final oranDolu = (izlenen / toplam).clamp(0.03, 1.0).toDouble();
    final tamamlandi = izlenen >= toplam;
    return Stack(
      children: [
        kart,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 5,
              color: Colors.black45,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: oranDolu,
                heightFactor: 1,
                child: Container(
                  color: tamamlandi ? Colors.deepOrange : DiziRenkler.sari,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Yüklenirken nabız gibi atan iskelet kutu.
class IskeletKutu extends StatefulWidget {
  final double genislik;
  final double? yukseklik;

  const IskeletKutu({super.key, this.genislik = 105, this.yukseklik});

  @override
  State<IskeletKutu> createState() => _IskeletKutuState();
}

class _IskeletKutuState extends State<IskeletKutu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_kontrol),
      child: Container(
        width: widget.genislik,
        height: widget.yukseklik,
        decoration: BoxDecoration(
          color: DiziRenkler.kart,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Kart-listesi iskeleti: yuvarlak avatar + iki metin çubuğu.
/// Bildirimler/sohbetler gibi liste ekranlarında bekleme yerine kullanılır.
class IskeletSatir extends StatelessWidget {
  const IskeletSatir({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const IskeletKutu(genislik: 44, yukseklik: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  IskeletKutu(genislik: 160, yukseklik: 12),
                  SizedBox(height: 8),
                  IskeletKutu(genislik: 90, yukseklik: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Verilen sayıda iskelet satırından oluşan liste (padding'li).
class IskeletListe extends StatelessWidget {
  final int adet;
  const IskeletListe({super.key, this.adet = 7});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: adet,
      itemBuilder: (_, __) => const IskeletSatir(),
    );
  }
}

/// Hata + tekrar dene görünümü
class HataGorunumu extends StatelessWidget {
  final String mesaj;
  final VoidCallback tekrar;
  const HataGorunumu({super.key, required this.mesaj, required this.tekrar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: DiziRenkler.metin38),
            const SizedBox(height: 12),
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: tekrar, child: Text('Tekrar Dene'.c)),
          ],
        ),
      ),
    );
  }
}

/// Boş durum görünümü: ikon + başlık + ipucu (+ isteğe bağlı aksiyon).
/// Sade "X yok" metinleri yerine kullanılır — daha profesyonel his.
class BosDurum extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String? ipucu;
  final Widget? aksiyon;
  const BosDurum({
    super.key,
    required this.ikon,
    required this.baslik,
    this.ipucu,
    this.aksiyon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 48, color: DiziRenkler.metin38),
            const SizedBox(height: 12),
            Text(
              baslik,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (ipucu != null) ...[
              const SizedBox(height: 6),
              Text(
                ipucu!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: DiziRenkler.metin54,
                  height: 1.4,
                ),
              ),
            ],
            if (aksiyon != null) ...[const SizedBox(height: 16), aksiyon!],
          ],
        ),
      ),
    );
  }
}

/// Tutarlı bölüm başlığı: sarı ikon + kalın başlık. Tüm ekranlarda aynı.
class BolumBasligi extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final Widget? sonEk; // sağdaki buton (ör. "Tümünü gör", +)
  const BolumBasligi({
    super.key,
    required this.ikon,
    required this.baslik,
    this.sonEk,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ikon, size: 20, color: DiziRenkler.sari),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            baslik,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (sonEk != null) sonEk!,
      ],
    );
  }
}

/// Gezinmeden ÖNCE açık imperatif katmanları (Reels, alt sayfalar, tam ekran
/// medya görüntüleyici) kapatır.
///
/// NEDEN: Reels `Navigator.of(context, rootNavigator: true).push(...)` ile
/// go_router'ın SAYFA yığınının ÜSTÜNE itiliyor. O katman açıkken yapılan
/// `context.push('/kullanici/x')` hedefi kabuğun İÇİNDEKİ gezgine iter; yeni
/// sayfa Reels'in ALTINDA açılır ve GÖRÜNMEZ. Kullanıcı "hiçbir şey olmadı"
/// sanır, Reels'i kapatınca kendini profilde bulur (3 Ağu 2026 bildirimi:
/// "beğeni listesinden kullanıcıya tıklıyorum profiline gitmiyor ama reelsten
/// çıkınca kendimi kullanıcı profilinde buluyorum").
///
/// Aynı tuzak alt sayfalar için de geçerli: sheet, sayfanın gezgininde
/// yaşadığı için altına itilen sayfayı örter. O yüzden hem EN YAKIN gezgin
/// hem de KÖK gezgin temizlenir.
///
/// Yalnız imperatif rotalar atılır: `settings is Page` olanlar (go_router
/// sayfaları) ve ilk rota korunur — testlerdeki `MaterialApp(home: ...)`
/// düzeni de sağ kalır.
void katmanlariKapat(BuildContext context) {
  bool sayfaMi(Route<dynamic> r) => r.settings is Page || r.isFirst;
  Navigator.of(context).popUntil(sayfaMi);
  Navigator.of(context, rootNavigator: true).popUntil(sayfaMi);
}

/// Katman-güvenli rota gezinmesi: Reels/alt sayfa açıkken hedef sayfa onların
/// ALTINDA kalmasın diye önce katmanlar kapatılır, sonra push edilir.
/// Reels'ten içerik/bölüm/kişi rozetine dokunmak buradan geçer.
void rotayaGitGuvenli(BuildContext context, String hedef) {
  final yonlendirici = GoRouter.of(context);
  katmanlariKapat(context);
  yonlendirici.push(hedef);
}

/// Şu an EN ÜSTTEKİ sayfa kabuğun (StatefulShellRoute) İÇİNDE mi?
///
/// NEDEN ELLE YOL LİSTESİ DEĞİL: eskiden burada '/icerik/', '/kisi/', ...
/// diye kabuk DIŞI yolların sabit listesi vardı ve iki ayrı dosyada
/// KOPYALANMIŞTI. Yeni bir kök rota eklenince listeye yazmayı unutmak sessizce
/// SİYAH EKRAN üretiyordu (6 Ağu 2026: mobil tam ekran arama `/tam-arama`
/// listede yoktu — arama sonucundaki kullanıcıya dokununca kabuk ikinci kez
/// kurulup sayfa anahtarları çakışıyordu).
///
/// Yönlendiricinin KENDİ eşleşme ağacı sorulursa liste bakımı biter: go_router
/// kabuk içi sayfaları [ShellRouteMatch] altında toplar, kabuğun üstüne itilen
/// kök rotalar ise düz [RouteMatch] olarak listenin SONUNA eklenir.
bool kabukIcindeMi(GoRouter yonlendirici) {
  final eslesmeler = yonlendirici.routerDelegate.currentConfiguration.matches;
  return eslesmeler.isNotEmpty && eslesmeler.last is ShellRouteMatch;
}

/// Kabuğun ÜSTÜNE itilmiş kök sayfaları (detay, kişi, tam ekran arama...)
/// kapatıp kabuğun DURDUĞU sekmeye döner; kabuk hiç kurulmamışsa (derin
/// bağlantıyla doğrudan gelinmişse) false döner.
///
/// NEDEN doğrudan hedefe `go` DEĞİL: hedefe go, kabuğu hedef sayfayla
/// KURDUĞU için geriye poplanacak sayfa bırakmaz — Android geri tuşu o
/// sayfadan uygulamayı KAPATIRDI. Önce kabuğun kendi konumuna dönüp SONRA
/// push edince yığın iki katlı olur: geri tuşu sayfayı kapatır, kullanıcı
/// geldiği sekmede kalır.
bool kabugaDon(GoRouter yonlendirici) {
  final eslesmeler = yonlendirici.routerDelegate.currentConfiguration.matches;
  for (final eslesme in eslesmeler) {
    if (eslesme is! ShellRouteMatch) continue;
    RouteMatchBase yaprak = eslesme;
    while (yaprak is ShellRouteMatch) {
      yaprak = yaprak.matches.last;
    }
    yonlendirici.go(yaprak.matchedLocation);
    return true;
  }
  return false;
}

/// Kullanıcı profiline güvenli gidiş. /kullanici/:ad kabuk İÇİNDE yaşar;
/// kabuğun üstündeki sayfalardan (detay/bölüm/kişi/özet/tam ekran arama...)
/// push'lanırsa kabuk ikinci kez kurulur, sayfa anahtarları ve branch
/// GlobalKey'leri çakışır → boş/siyah ekran.
/// O yüzden kabuk dışındaysak önce kabuğa dönülür ([kabugaDon]), sonra push
/// edilir; kabuk hiç kurulmamışsa (derin bağlantı) go ile kurulur.
///
/// Reels gibi tam ekran katmanlar da kapatılır — bkz. [katmanlariKapat].
void kullaniciyaGit(BuildContext context, String ad) {
  final yonlendirici = GoRouter.of(context);
  final hedef = '/kullanici/$ad';
  katmanlariKapat(context);
  if (kabukIcindeMi(yonlendirici) || kabugaDon(yonlendirici)) {
    yonlendirici.push(hedef);
  } else {
    yonlendirici.go(hedef);
  }
}

/// dizi.jpg AI hesabının kullanıcı adı. Bu adı taşıyan avatarlar her yerde
/// sarı çerçeve + çerçevenin altına oturan "AI" rozetiyle çizilir.
const String aiKullaniciAdi = 'dizi.jpg.ai';

/// Kullanıcının yüklediği görseli (avatar/kapak) ağdan çizer.
/// **WEB'de `Image.network`, mobilde `CachedNetworkImage`.**
///
/// NEDEN AYRIM — 9 Ağu 2026, "GIF hâlâ oynamıyor" hatasının GERÇEK kökü:
/// `CachedNetworkImage` web'de varsayılan olarak
/// `ImageRenderMethodForWeb.HtmlImage` kullanır. O yol
/// `ui_web.createImageCodecFromUrl` → CanvasKit `CkImageElementCodec`
/// demektir; bu kodek `HtmlImageElementCodec`ten türer ve
/// `frameCount => 1` bildirir. Yani görsel bir `<img>` öğesiyle indirilip
/// TEK KAREYE çevrilir: GIF ilk karesinde donar. `Image` widget'ını
/// kullanmak tek başına YETMİYOR (8 Ağu'daki eksik düzeltme buydu) —
/// belirleyici olan ImageProvider'ın ürettiği kodek.
/// Tarayıcı ölçümü: canlı sitede avatar/kapak isteklerinin
/// `PerformanceResourceTiming.initiatorType` değeri "img" çıkıyordu.
///
/// Flutter'ın kendi `NetworkImage`i (web uygulaması) baytları XHR ile
/// indirip `ui.ImmutableBuffer` üzerinden çözer → çok kareli kodek →
/// animasyon oynar. Mobilde böyle bir sorun yok, orada disk önbelleği
/// değerli olduğu için `CachedNetworkImage` kalır.
///
/// ÖNBELLEK KAYBI YOK: avatar/kapak sunucudan
/// `cache-control: public, max-age=31536000, immutable` ile geliyor (curl ve
/// tarayıcı ile doğrulandı), XHR tarayıcının HTTP önbelleğini kullanır;
/// ayrıca Flutter'ın `imageCache`i çözülmüş kareyi bellekte tutar.
class AgGorsel extends StatelessWidget {
  final String url;
  final BoxFit fit;

  /// Görsel inerken çizilecek yüzey (sessiz boşluk bırakma).
  final Widget? yerTutucu;

  /// İndirme/çözme başarısızsa çizilecek yüzey.
  final Widget? hata;

  const AgGorsel({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.yerTutucu,
    this.hata,
  });

  @override
  Widget build(BuildContext context) => agGorselKur(
    web: agGorselWebZorla ?? kIsWeb,
    url: url,
    fit: fit,
    yerTutucu: yerTutucu,
    hata: hata,
  );
}

/// YALNIZ TEST: [AgGorsel]'in platform dalını zorlar (`true` = web dalı).
///
/// NEDEN VAR — 13. maddenin (10 Ağu 2026) test tuzağı: `flutter test` DAİMA
/// VM'de koşar, `kIsWeb` orada HEP `false`'tur. Hata ise SADECE web dalındaydı,
/// yani ekranları (akış/yorumlar/Reels) ayağa kaldıran testler hatanın olduğu
/// dalı HİÇ gezemiyordu. [agGorselKur] bayrağı parametre olarak alıyor ama
/// ekran testleri o kurucuyu doğrudan çağırmaz — widget ağacından geçerler.
/// Bu kanca ağacın İÇİNDEN geçen yolu da iki dalda gezilebilir yapar.
/// `null` bırakıldığında (üretim) davranış birebir eskisidir: `kIsWeb`.
/// Test `tearDown`'ında `null`'a döndürülmeli.
@visibleForTesting
bool? agGorselWebZorla;

/// [AgGorsel]'in saf kurucusu — `web` bayrağı DIŞARIDAN verilir ki
/// `flutter test` (her zaman VM'de, `kIsWeb == false`) web yolunu da
/// doğrulayabilsin. 8 Ağu'daki düzeltme tam burada gözden kaçtı: test yalnız
/// VM yolunu görüyordu, hata ise SADECE web yolundaydı.
@visibleForTesting
Widget agGorselKur({
  required bool web,
  required String url,
  BoxFit fit = BoxFit.cover,
  Widget? yerTutucu,
  Widget? hata,
}) {
  if (web) {
    return Image.network(
      url,
      fit: fit,
      // Kare değişiminde beyaz parlama olmasın.
      gaplessPlayback: true,
      loadingBuilder: yerTutucu == null
          ? null
          : (_, cocuk, ilerleme) => ilerleme == null ? cocuk : yerTutucu,
      errorBuilder: hata == null ? null : (_, _, _) => hata,
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    placeholder: yerTutucu == null ? null : (_, _) => yerTutucu,
    errorWidget: hata == null ? null : (_, _, _) => hata,
  );
}

/// Ağdan gelen görseli DAİRE içinde çizen, ANİMASYONU KORUYAN gösterim.
///
/// `CircleAvatar(backgroundImage:)` yerine bunu kullan: orası görseli
/// `DecorationImage` olarak alır ve animasyonlu GIF'in yalnız ilk karesini
/// boyar. Burada [AgGorsel] ağaçta olduğu için kareler akar — web'de
/// tek kareye düşen kodek sorunu için [AgGorsel] belgesine bak.
/// Kanıt: test/gif_animasyon_test.dart.
class DaireGorsel extends StatelessWidget {
  final String url;
  final double cap;
  final Color arkaplan;
  final Color ikonRenk;
  const DaireGorsel({
    super.key,
    required this.url,
    required this.cap,
    required this.arkaplan,
    required this.ikonRenk,
  });

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: cap,
      height: cap,
      child: AgGorsel(
        url: url,
        // Üç hâl: yükleniyor → görsel → hata. Sessiz boşluk bırakma.
        yerTutucu: Container(color: arkaplan),
        hata: Container(
          color: arkaplan,
          child: Icon(Icons.person, size: cap * 0.5, color: ikonRenk),
        ),
      ),
    ),
  );
}

/// Kullanıcı avatarı. [kullaniciAdi] AI hesabıysa sarı çerçeve ve altına
/// bindirilmiş "AI" rozeti ekler; diğer herkes için düz CircleAvatar'dır.
/// Rozetli halde bileşen çerçeve + rozet payı kadar büyür; rozet Stack
/// SINIRLARI İÇİNDE kalır (dışarı taşan Positioned tıklama almaz).
///
/// [hareketli] — animasyonlu GIF avatarların OYNAMASI isteniyorsa true.
/// NEDEN AYRI BAYRAK (8 Ağu 2026 hatası): `CircleAvatar(backgroundImage:)`
/// görseli bir `DecorationImage` olarak boyar ve animasyonlu görselin
/// YALNIZ İLK KARESİNİ çizer; animasyon için `Image` widget'ının kendisi
/// ağaçta olmalıdır (piksel kanıtı: test/gif_animasyon_test.dart).
/// Varsayılan `false`: arama sonucu, beğenenler, takipçi ve sohbet
/// listelerinde aynı anda onlarca avatar bulunur ve orada durağan ilk kare
/// hem yeterli hem ucuzdur.
///
/// AMA ÜÇ YÜZEYDE AÇIKTIR (10 Ağu 2026, kullanıcı isteği md.13): **akış,
/// dizi/film yorumları ve Reels**. Kullanıcı GIF avatarını tam da bu üç
/// yüzeyde donmuş görüyordu; "profilde oynuyor, akışta oynamıyor" tutarsızdı.
/// Maliyet sanıldığı kadar büyük değil: GIF OLMAYAN avatar (jpg/png/webp —
/// çoğunluk) tek karelidir, `Image` widget'ı onu bir kez çözer ve bir daha
/// boyamaz; ek yük yalnız GERÇEKTEN animasyonlu avatarlar kadardır.
/// Hatırlatma: `hareketli: true` tek başına web'de YETMEZ, çünkü belirleyici
/// olan ImageProvider'ın ürettiği kodektir — bkz. [AgGorsel].
class KullaniciAvatari extends StatelessWidget {
  final String? url; // dosyaUrl'den geçmiş TAM adres; null = kişi ikonu
  final String? kullaniciAdi;
  final double yaricap;
  final Color? arkaplan;
  final Color? ikonRenk;
  final bool hareketli;
  const KullaniciAvatari({
    super.key,
    required this.url,
    required this.kullaniciAdi,
    this.yaricap = 20,
    this.arkaplan,
    this.ikonRenk,
    this.hareketli = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget avatar = (hareketli && url != null)
        ? DaireGorsel(
            url: url!,
            cap: yaricap * 2,
            arkaplan: arkaplan ?? DiziRenkler.koyuGri,
            ikonRenk: ikonRenk ?? DiziRenkler.metin38,
          )
        : CircleAvatar(
            radius: yaricap,
            backgroundColor: arkaplan ?? DiziRenkler.koyuGri,
            backgroundImage: url != null
                ? CachedNetworkImageProvider(url!)
                : null,
            child: url == null
                ? Icon(
                    Icons.person,
                    size: yaricap,
                    color: ikonRenk ?? DiziRenkler.metin38,
                  )
                : null,
          );
    if (kullaniciAdi != aiKullaniciAdi) return avatar;
    final kenar = (yaricap * 0.09).clamp(1.2, 2.0);
    final halka = yaricap * 2 + 2 * (kenar + 1.5);
    final yazi = (yaricap * 0.42).clamp(7.0, 11.0);
    final rozetYukseklik = yazi * 1.1 + 3;
    return SizedBox(
      width: halka,
      height: halka + rozetYukseklik / 2,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: halka,
            height: halka,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: DiziRenkler.sari, width: kenar),
            ),
            child: avatar,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: yazi * 0.55),
              decoration: BoxDecoration(
                color: DiziRenkler.sari,
                borderRadius: BorderRadius.circular(rozetYukseklik),
              ),
              // "AI" evrensel kısaltma/marka etiketi — çevrilmez.
              child: Text(
                'AI',
                style: TextStyle(
                  fontSize: yazi,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Okunmamış sayacı rozetli appbar ikonu (zil, zarf, DM).
class RozetliIkon extends StatelessWidget {
  final IconData ikon;
  final int sayi;
  final VoidCallback onTap;
  final String? etiket; // erişilebilirlik + tooltip

  const RozetliIkon({
    super.key,
    required this.ikon,
    required this.sayi,
    required this.onTap,
    this.etiket,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: etiket,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(ikon),
          if (sayi > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: DiziRenkler.sari,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  sayi > 99 ? '99+' : '$sayi',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste içeriği: 3'lü poster ızgarası + yükleniyor / hata / bulunamadı-gizli
/// / boş hâlleri.
///
/// TEK KAYNAK: hem profil modalindeki [ListeSheet] hem `/listeler/:id` tam
/// sayfası ([ListeEkrani], ekranlar/liste.dart) bunu kullanır. İki ayrı kopya
/// tutulsaydı "gizli liste" hâli yalnız birinde düzelirdi.
class ListeIcerigi extends StatefulWidget {
  final int listeId;

  /// Modal içinde mi çiziliyor? Poster dokunuşunda modalin kapanması gerekir,
  /// ve "Keşfet'e dön" çıkışı modalde anlamsızdır (kapatmak zaten yeterli).
  final bool modalIcinde;

  /// Liste kaydı çözülünce çağrılır — tam sayfa başlığı buradan beslenir.
  final ValueChanged<Map<String, dynamic>>? onListe;

  const ListeIcerigi({
    super.key,
    required this.listeId,
    this.modalIcinde = false,
    this.onListe,
  });

  @override
  State<ListeIcerigi> createState() => _ListeIcerigiState();
}

class _ListeIcerigiState extends State<ListeIcerigi> {
  List<dynamic>? _ogeler;
  String? _hata;
  int? _kod;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _hata = null;
      _kod = null;
    });
    try {
      final d = await Api.get('/listeler/${widget.listeId}');
      if (!mounted) return;
      final liste = d as Map<String, dynamic>;
      setState(() => _ogeler = (liste['ogeler'] as List<dynamic>?) ?? const []);
      widget.onListe?.call(liste);
    } on ApiHata catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.mesaj;
        _kod = e.kod;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sunucu, GİZLİ listeyi sahibi olmayana 404 verir (herkese_acik=false).
    // Ziyaretçi için "yok" ile "gizli" ayrımı zaten yapılamaz; ikisi de aynı
    // nazik sayfayı görür — boş beyaz ekran DEĞİL.
    if (_kod == 404) {
      return BosDurum(
        ikon: Icons.link_off,
        baslik: 'Bağlantı geçersiz veya sayfa bulunamadı'.c,
        aksiyon: widget.modalIcinde
            ? null
            : FilledButton(
                onPressed: () => GoRouter.of(context).go('/kesfet'),
                child: Text('Keşfet\'e dön'.c),
              ),
      );
    }
    if (_hata != null) return HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    if (_ogeler == null) {
      return const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    }
    if (_ogeler!.isEmpty) {
      return Center(
        child: Text(
          'Liste boş.'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    }
    return GridView.builder(
      // ALT GÜVENLİ ALAN: GridView de bir BoxScrollView — AÇIK `padding`
      // verildiği an Flutter'ın MediaQuery alt payını kendiliğinden ekleme
      // davranışı kapanır (yalnız padding == null iken ekler). Sabit 20 ile
      // 360x800 / 48 dp navi çubuğu olan telefonda son poster sırasının alt
      // kenarı 780'e, yani çubuğun ALTINA düşüyordu (güvenli sınır 752).
      //
      // `useSafeArea: true` BU İŞİ ÇÖZMEZ: Flutter kaynağında
      // `SafeArea(bottom: false, ...)` — alt kenara hiç dokunmaz.
      // Alt payı sheet'in İÇERİĞİ halletmeli.
      //
      // ÇAĞIRAN-FARKINDALIĞI PARAMETRESİZ: bu ızgara hem kabuk İÇİNDEN
      // (profil sekmesi) hem de kabuk kökünden açılıyor. Ayrımı MediaQuery
      // zaten yapar — kabuğun Scaffold'u `bottomNavigationBar` taşıdığı için
      // gövdesine verdiği MediaQuery'de alt pay ZATEN 0'dır, orada
      // altGuvenli 0 + 20 = 20 döner → FAZLADAN boşluk YOK.
      padding: EdgeInsets.fromLTRB(14, 0, 14, altGuvenli(context, ekstra: 20)),
      // Sütun sayısı SABİT 3 değil: `/listeler/:id` tam sayfası masaüstünde
      // 1400 dp genişliğe açılıyor ve 3 sütunda poster 460 dp'ye şişiyordu.
      // [PosterIzgarasi] ölçülen genişlikten türetir; başlık yok, hücre
      // birebir 2:3 (baslikYuksekligi: 0).
      gridDelegate: const PosterIzgarasi(
        satirBoslugu: 10,
        bosluk: 10,
        baslikYuksekligi: 0,
      ),
      itemCount: _ogeler!.length,
      itemBuilder: (context, i) {
        final o = _ogeler![i] as Map<String, dynamic>;
        return _ListeOgeKart(
          tur: o['tur'] as String,
          tmdbId: (o['tmdb_id'] as num).toInt(),
          modalIcinde: widget.modalIcinde,
        );
      },
    );
  }
}

/// Liste içeriği modalı: [ListeIcerigi]'ni başlıklı bir alt sayfaya sarar.
/// Hem kendi profilinden hem başkasının profilinden açılır.
class ListeSheet extends StatelessWidget {
  final int listeId;
  final String ad;

  const ListeSheet({super.key, required this.listeId, required this.ad});

  static void ac(
    BuildContext context, {
    required int listeId,
    required String ad,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => ListeSheet(listeId: listeId, ad: ad),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.playlist_play, color: DiziRenkler.sari),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ad,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: ListeIcerigi(listeId: listeId, modalIcinde: true)),
        ],
      ),
    );
  }
}

/// Liste öğesi: posteri önbellekli TMDB'den çeker, tıklayınca detaya gider.
class _ListeOgeKart extends StatefulWidget {
  final String tur;
  final int tmdbId;

  /// Modalden açıldıysa detaya gitmeden ÖNCE modal kapatılır; tam sayfada
  /// kapatılacak bir şey yoktur (pop, listenin kendisini kapatırdı).
  final bool modalIcinde;

  const _ListeOgeKart({
    required this.tur,
    required this.tmdbId,
    required this.modalIcinde,
  });

  @override
  State<_ListeOgeKart> createState() => _ListeOgeKartState();
}

class _ListeOgeKartState extends State<_ListeOgeKart> {
  Map<String, dynamic>? _icerik;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final d = await Api.get('/tmdb/${widget.tur}/${widget.tmdbId}');
      if (mounted) setState(() => _icerik = d as Map<String, dynamic>);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl(_icerik?['poster_path'] as String?, boyut: 'w185');
    final ad = (_icerik?['name'] ?? _icerik?['title'] ?? '') as String;
    return InkWell(
      onTap: () {
        // Yönlendiriciyi modal kapanmadan ÖNCE al (ölü context tuzağı)
        final yonlendirici = GoRouter.of(context);
        if (widget.modalIcinde) Navigator.pop(context);
        yonlendirici.push('/icerik/${widget.tur}/${widget.tmdbId}');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: DiziRenkler.kart,
          child: poster != null
              ? CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: DiziRenkler.metin38,
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      ad,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Şikayet sebebi seçtiren alt sayfa; seçilince sunucuya bildirir.
/// tur: 'yorum' | 'mesaj' | 'kullanici' | 'liste'
Future<void> sikayetEtSheet(
  BuildContext context,
  String tur,
  int hedefId,
) async {
  const sebepler = [
    'Spam veya yanıltıcı',
    'Taciz veya nefret söylemi',
    'Uygunsuz / cinsel içerik',
    'Şiddet veya tehlikeli içerik',
    'Telif hakkı ihlali',
    'Çocuk güvenliği',
    'Diğer',
  ];
  final messenger = ScaffoldMessenger.of(context);
  final secilen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: DiziRenkler.koyuGri,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, color: DiziRenkler.sari),
                const SizedBox(width: 10),
                Text(
                  'Şikayet sebebi'.c,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          for (final s in sebepler)
            ListTile(title: Text(s.c), onTap: () => Navigator.pop(context, s)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (secilen == null) return;
  try {
    await Api.sikayetEt(tur, hedefId, secilen);
    messenger.showSnackBar(
      SnackBar(content: Text('Şikayetin alındı, teşekkürler'.c)),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Gönderi/yorum kartlarının sağ üstündeki dikey üç nokta menüsü.
///
/// Kendi içeriğinde gösterilmez (kendini şikayet etmek anlamsız); misafir
/// kullanıcıya da gösterilmez çünkü /sikayet giriş ister ve buton basılınca
/// hata verirdi. [tur] backend SIKAYET_TUR ile aynı olmalı: yorum/kullanici.
class UcNoktaMenu extends StatelessWidget {
  final String tur;
  final int hedefId;
  final bool benimMi;
  final Color renk;

  /// Verilirse menüye "Engelle" de eklenir (gönderiyi paylaşan kişi).
  final VoidCallback? onEngelle;

  const UcNoktaMenu({
    super.key,
    required this.tur,
    required this.hedefId,
    this.benimMi = false,
    this.renk = Colors.white70,
    this.onEngelle,
  });

  @override
  Widget build(BuildContext context) {
    if (benimMi || !context.read<Oturum>().girisli) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20, color: renk),
      tooltip: 'Şikayet et'.c,
      onSelected: (secim) {
        if (secim == 'sikayet') {
          sikayetEtSheet(context, tur, hedefId);
        } else if (secim == 'engelle') {
          onEngelle?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'sikayet',
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, size: 20),
              const SizedBox(width: 10),
              Text('Şikayet et'.c),
            ],
          ),
        ),
        if (onEngelle != null)
          PopupMenuItem(
            value: 'engelle',
            child: Row(
              children: [
                const Icon(Icons.block, size: 20),
                const SizedBox(width: 10),
                Text('Engelle'.c),
              ],
            ),
          ),
      ],
    );
  }
}

/// Push edilen (alt menüsüz) ekranlarda kaydırma sonunun telefonun sistem
/// gezinme çubuğu (3 buton / gesture) altında kalmaması için alt boşluk.
double altGuvenli(BuildContext context, {double ekstra = 16}) =>
    MediaQuery.of(context).padding.bottom + ekstra;

/// Uzun DÜZ metni ([satirSiniri]) satırda kırpar, taşarsa sonuna tek
/// karakterlik `…` koyar ve METNE DOKUNUNCA tamamını açar (biyografi, özet).
///
/// Kullanıcı bildirimi (2026-08-03): "Oyuncu profillerindeki bilgi yazısı
/// büyütülmüyor. sonuna üç nokta ekle, tıklayınca yazının devamı gözüksün."
/// Kişi sayfasında biyografi 6 satırda kırpılıyor ama açılamıyordu.
///
/// DOKUNMA HEDEFİ: üç noktanın kendisi ~8 px, parmakla vurulamaz — bu yüzden
/// dokunma alanı KIRPILMIŞ METNİN TAMAMIDIR (6 satır ≈ 120 px, 44 px kuralının
/// çok üstünde). Açılan metin geri KAPANMAZ: kullanıcı "devamı gözüksün" dedi,
/// kapatma istemedi; kapatma da gizli bir dokunma hedefi olurdu. Akış
/// kartındaki KisaltilmisYorum ile aynı karar.
///
/// Taşmayan metinde ne üç nokta ne de dokunma vardır; metin boşsa hiçbir şey
/// çizilmez (boş kutu / yer tutucu yok).
class AcilirMetin extends StatefulWidget {
  final String metin;

  /// Kırpma sınırı: ekran boyutundan BAĞIMSIZ, her yerde aynı.
  final int satirSiniri;
  final TextStyle? stil;

  const AcilirMetin(this.metin, {super.key, this.satirSiniri = 6, this.stil});

  @override
  State<AcilirMetin> createState() => _AcilirMetinState();
}

class _AcilirMetinState extends State<AcilirMetin> {
  bool _acik = false;

  @override
  void didUpdateWidget(AcilirMetin eski) {
    super.didUpdateWidget(eski);
    // Metin değiştiyse (başka kişiye/bölüme geçiş) kırpma yeniden hesaplanır.
    if (eski.metin != widget.metin) _acik = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metin.trim().isEmpty) return const SizedBox.shrink();
    // Ölçüm ile çizim AYNI stille yapılmalı, yoksa taşma yanlış hesaplanır.
    final stil = DefaultTextStyle.of(context).style.merge(widget.stil);
    if (_acik) return Text(widget.metin, style: stil);
    return LayoutBuilder(
      builder: (context, kisit) {
        final olcer = TextPainter(
          text: TextSpan(text: widget.metin, style: stil),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: widget.satirSiniri,
        )..layout(maxWidth: kisit.maxWidth);
        final tasiyor = olcer.didExceedMaxLines;
        olcer.dispose();

        final govde = Text(
          widget.metin,
          style: stil,
          // Sınırdan KISA metinde sınır konmaz → üç nokta da çıkmaz.
          maxLines: tasiyor ? widget.satirSiniri : null,
          overflow: tasiyor ? TextOverflow.ellipsis : null,
        );
        if (!tasiyor) return govde;
        return Semantics(
          button: true,
          // Ekran okuyucuya "üç nokta" değil ne işe yaradığı söylenir.
          label: 'Devam et'.c,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _acik = true),
            child: govde,
          ),
        );
      },
    );
  }
}

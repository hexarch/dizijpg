import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../bayrak.dart';
import '../ceviri.dart';
import '../gorsel_basliklari.dart';
import '../seviye.dart';
import '../tema.dart';
import 'begenenler.dart';
import 'gonderi_istatistik.dart' show IstatistikGirisi;
import 'ortak.dart';
import 'profil.dart'
    show
        sureBicimle,
        RozetCipi,
        SeviyeSatiri,
        ProfilKimlikBasligi,
        ProfilOlcumSatiri,
        ProfilSayaclari,
        ProfilSekmeleri,
        ProfilTakipSatiri,
        ProfilYorumAkisi;
import 'sosyal.dart';
import 'takip_dugmesi.dart';

/// Başka bir kullanıcının herkese açık profili: istatistik, takip, yorumlar.
class KullaniciProfilEkrani extends StatefulWidget {
  final String kullaniciAdi;
  const KullaniciProfilEkrani({super.key, required this.kullaniciAdi});

  @override
  State<KullaniciProfilEkrani> createState() => _KullaniciProfilEkraniState();
}

class _KullaniciProfilEkraniState extends State<KullaniciProfilEkrani> {
  Map<String, dynamic>? _profil;
  String? _hata;
  bool _takipIsleniyor = false;

  /// 0 = Dizi ve Filmler (rozet/şerit/listeler), 1 = Yorumlar.
  /// Kendi profilimizdeki (profil.dart) iki sekmeli düzenin aynısı.
  int _sekme = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final p = await Api.acikProfil(widget.kullaniciAdi);
      if (mounted) setState(() => _profil = p);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _takip() async {
    setState(() => _takipIsleniyor = true);
    try {
      final d = await Api.takipToggle(widget.kullaniciAdi);
      if (!mounted) return;
      setState(() {
        _profil!['takip_ediyorum'] = d['takip'];
        _profil!['istatistik']['takipci'] = d['takipci'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _takipIsleniyor = false);
    }
  }

  void _liste(bool takipciler) {
    context.push(
      '/kullanici/${widget.kullaniciAdi}/${takipciler ? 'takipciler' : 'takip'}',
    );
  }

  void _listeAc(int id, String? ad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => ListeSheet(listeId: id, ad: ad ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_profil == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else {
      final p = _profil!;
      final st = p['istatistik'] as Map<String, dynamic>;
      final avatar = dosyaUrl(p['avatar'] as String?);
      final girisli = context.watch<Oturum>().girisli;
      final benMi = p['ben_mi'] == true;
      final takipEdiyorum = p['takip_ediyorum'] == true;
      // `engel`: BU kullanıcıyı BEN engelledim. Sunucu bayrağı yalnız
      // ENGELLEYEN tarafa gönderir (karşı taraf beni engellediyse profil yine
      // boş gelir ama bayrak GELMEZ — "seni engelledi" demek engellemeyi bir
      // bildirime çevirirdi). Bayrak varken içerik sekmeleri hiç çizilmez:
      // sunucu zaten boş liste dönüyor, ekranda "Yorum yok" yazmak yerine
      // sebebini söyleyip geri alma yolunu göstermek gerekir.
      final engelledim = p['engel'] == true;
      final yorumlar = (p['yorumlar'] as List<dynamic>? ?? []);
      final listeler = (p['listeler'] as List<dynamic>? ?? []);
      final izlenenler = (p['izlenenler'] as List<dynamic>? ?? []);

      // Sayaçların TEK çözümleyicisi: alan adlarını AÇIK PROFİL şemasından
      // okur (kendi profilim `ProfilSayaclari.kendi` kullanır — aynı sayılar,
      // farklı anahtarlar; eşleme tek yerde, profil.dart'ta).
      final sayaclar = ProfilSayaclari.acik(st);

      // Yorum / beğeni / görüntülenme sayaçlarının dokunma hedefi.
      //
      // Kendi profilimde bu üçü yorum listesi modalini açıyor. Ziyaretçide
      // modal yok, KARŞILIĞI "Yorumlar" sekmesidir (aynı liste, aynı ekran).
      // İki durumda hiç bağlanmaz:
      //  · `yorumlar_gizli` (sahibi hariç) — sekme zaten "yorumlarını gizlemiş"
      //    diyor; sayacı oraya götürmek gizliliği delmez ama boş bir vaat olur.
      //  · engellediğim kişi — sekmeler HİÇ çizilmiyor, `_sekme`yi değiştirmek
      //    hiçbir şey yapmazdı.
      final yorumSekmesi =
          (engelledim || (!benMi && p['yorumlar_gizli'] == true))
          ? null
          : () => setState(() => _sekme = 1);

      final kapak = dosyaUrl(p['kapak'] as String?);
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView(
          padding: EdgeInsets.only(bottom: altGuvenli(context)),
          children: [
            if (kapak != null)
              SizedBox(
                height: 130,
                width: double.infinity,
                // Kapak GIF olabilir ve OYNAMALI: web'de CachedNetworkImage
                // <img> yolundan tek kareye düşüyor (bkz. AgGorsel).
                child: AgGorsel(
                  url: kapak,
                  yerTutucu: Container(color: DiziRenkler.koyuGri),
                  hata: Container(color: DiziRenkler.koyuGri),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      KullaniciAvatari(
                        url: avatar,
                        kullaniciAdi: p['kullanici_adi'] as String?,
                        yaricap: 40,
                        arkaplan: DiziRenkler.kart,
                        // Profil başlığı: GIF avatar BURADA oynasın.
                        hareketli: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Görünen ad (varsa, ÜSTTE) + kullanıcı adı +
                            // (testçiyse) altın onay tiki.
                            // KULLANICI İSTEĞİ (7 Ağu): tik kullanıcı adının
                            // HEMEN YANINDA olacak; eski "Founding Member"
                            // yazısı + dizi.jpg logosu kaldırıldı.
                            //
                            // 21 Ağu 2026: blok ORTAK bileşene taşındı
                            // ([ProfilKimlikBasligi], profil.dart) — kendi
                            // profilim birebir aynı kodu çiziyor. Ölçü de
                            // oradan geliyor: burası sabit 18 px yazıyordu,
                            // kendi profilim 17/21; kullanıcı ikisinin AYNI
                            // görünmesini istedi (21 Ağu). KOPYALAMA YASAK —
                            // bu iki ekran bugün kopyalama yüzünden ayrışmıştı.
                            //
                            // `benMi`: bu ekran KENDİ kullanıcı adınla da
                            // açılabiliyor; "kendi profilim mi" kararı ekranın
                            // türünden değil sunucunun `ben_mi` yargısından
                            // gelir (uzun basma menüsü de aynı alanı kullanır).
                            ProfilKimlikBasligi(
                              ad: p['ad'],
                              kullaniciAdi: '${p['kullanici_adi']}',
                              testci: p['testci'] == true,
                              benMi: benMi,
                              genis: masaustuMu(context),
                            ),
                            // SEVİYE (md. 29): kullanıcı adının HEMEN ALTINDA,
                            // yalnız sayı ("Seviye 7").
                            //
                            // İLERLEME BURADA ÇİZİLMEZ (`ilerlemeGoster`
                            // yalnız `ben_mi` ise true): başkasının profilinde
                            // ilerleme çubuğu, seviyeyi bir sıralama tablosuna
                            // çevirirdi. Zaten sunucu ziyaretçiye puan/eşik
                            // GÖNDERMİYOR — bu bayrak ikinci kilit.
                            //
                            // 1. KADEME VE `izlenenler_gizli` DURUMUNDA
                            // `seviye` null gelir (sunucu süzüyor), o yüzden
                            // burada ayrıca koşul yok: satır hiç çizilmez.
                            if (Seviye.ekranda(p['seviye']) case final sv?)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: SeviyeSatiri(
                                  seviye: sv,
                                  ilerlemeGoster: p['ben_mi'] == true,
                                ),
                              ),
                            // Ülke satırı. Rozet buradan ÇIKTI (artık adın
                            // yanında) — ülke tek başına kaldı.
                            if ((p['ulke'] as String?)?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: UlkeSatiri(ulke: p['ulke'] as String),
                              ),
                            const SizedBox(height: 6),
                            // Takipçi / takip / beğeni / görüntülenme —
                            // KENDİ PROFİLİMDEKİ satır içi biçim (kullanıcı
                            // isteği, 21 Ağu 2026). Kimlik bloğunun İÇİNDE,
                            // ülkenin hemen altında duruyor; tıpkı orada.
                            //
                            // GİZLİLİK KORUNUYOR: `takipciler_gizli` /
                            // `takip_edilenler_gizli` açıkken sayı YAZILIR
                            // ama dokunma bağlanmaz — sunucu sayacı süzmüyor,
                            // süzen şey listeye erişim. Sahibi kendi
                            // profiline bakıyorsa (`ben_mi`) kilit yok.
                            //
                            // Beğeni/görüntülenme eskiden aşağıdaki kutulu
                            // `EtkilesimSatiri` şeridiydi; kendi profilimde 15
                            // Ağu'da buraya taşınmıştı, açık profil geride
                            // kalmıştı. Artık ikisi de aynı bileşeni çiziyor.
                            ProfilTakipSatiri(
                              sayac: sayaclar,
                              takipciTap:
                                  (!benMi && p['takipciler_gizli'] == true)
                                  ? null
                                  : () => _liste(true),
                              takipTap:
                                  (!benMi && p['takip_edilenler_gizli'] == true)
                                  ? null
                                  : () => _liste(false),
                              etkilesimTap: yorumSekmesi,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((p['bio'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      p['bio'] as String,
                      style: TextStyle(color: DiziRenkler.metin, height: 1.4),
                    ),
                  ],
                  // Sosyal bağlantılar (varsa)
                  SosyalSatiri(sosyal: p['sosyal'] as List<dynamic>? ?? []),
                  const SizedBox(height: 16),
                  // Bölüm / film / dizi / yorum — bu ekranın eşit sütunlu
                  // biçimi, artık kendi profilimde de aynısı çiziliyor.
                  // "Dizi" sütunu 21 Ağu 2026'da EKLENDİ (sunucu `dizi`yi
                  // zaten dönüyordu, ekran çizmiyordu); takipçi/takip buradan
                  // ÇIKTI, yukarıdaki kimlik bloğuna taşındı.
                  ProfilOlcumSatiri(
                    sayac: sayaclar,
                    // Bölüm/film/dizi için açık profilde GİDECEK YER YOK:
                    // `/izlediklerim` yalnız kendi hesabını gösteren bir uç.
                    // Ziyaretçinin karşılığı bu ekrandaki "Dizi ve Filmler"
                    // sekmesidir — ama o zaten varsayılan sekme ve hemen
                    // altta duruyor, dokunma eklemek boş bir eylem olurdu.
                    yorumTap: yorumSekmesi,
                  ),
                  // Toplam ekran süresi (kendi profildekiyle aynı biçim)
                  if (((st['tahmini_dakika'] as num?)?.toInt() ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: DiziRenkler.kart,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: DiziRenkler.sariMetin,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          // Expanded: uzun çevirilerde Spacer'lı satır taşıyordu.
                          Expanded(
                            child: Text(
                              'Toplam İzleme Süresi'.c,
                              style: TextStyle(
                                color: DiziRenkler.metin,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            sureBicimle((st['tahmini_dakika'] as num).toInt()),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: DiziRenkler.sariMetin,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // NOT: yorumların toplam beğeni/görüntülenmesi buradaki
                  // kutulu `EtkilesimSatiri` şeridinden ÇIKARILDI (21 Ağu
                  // 2026, kullanıcı isteği); artık yukarıda takipçi/takip ile
                  // aynı satır içi biçimde duruyor. Sınıfın kendisi
                  // `profil.dart`ta duruyor ama artık HİÇBİR ekran çizmiyor.
                  // Uyum: seninle ortak izlenenler + puan uyumu
                  if (!benMi && p['uyum'] != null) ...[
                    const SizedBox(height: 12),
                    _UyumKarti(uyum: p['uyum'] as Map<String, dynamic>),
                  ],
                  const SizedBox(height: 16),
                  // ENGELLİ DURUMU — Takip/Mesaj düğmelerinin YERİNE geçer.
                  // İkisi birden çizilseydi kullanıcı engellediği kişiye
                  // "Mesaj" düğmesine basar ve 403 hatası okurdu.
                  if (engelledim)
                    _EngelKarti(
                      isleniyor: _engelIsleniyor,
                      onKaldir: _engelKaldir,
                    ),
                  // Takip + Mesaj (kendi profilinde gösterme)
                  if (!benMi && girisli && !engelledim)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _takipIsleniyor ? null : _takip,
                            style: takipEdiyorum
                                ? FilledButton.styleFrom(
                                    backgroundColor: DiziRenkler.kart,
                                    foregroundColor: DiziRenkler.metin,
                                  )
                                : null,
                            icon: Icon(
                              takipEdiyorum
                                  ? Icons.person_remove
                                  : Icons.person_add,
                            ),
                            label: Text(
                              takipEdiyorum ? 'Takibi Bırak'.c : 'Takip Et'.c,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/sohbet/${widget.kullaniciAdi}'),
                            icon: Icon(
                              Icons.mail_outline,
                              size: 18,
                              color: DiziRenkler.sariMetin,
                            ),
                            label: Text(
                              'Mesaj'.c,
                              style: TextStyle(color: DiziRenkler.metin),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  // İki sekme: kendi profilimizle BİREBİR aynı widget
                  // (profil.dart > ProfilSekmeleri).
                  if (!engelledim)
                    ProfilSekmeleri(
                      secili: _sekme,
                      onSec: (i) => setState(() => _sekme = i),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            // Sekme içeriği gövdenin 16px yatay dolgusunun DIŞINDA durur:
            // yorum kartı akıştaki gibi ekranı sağdan sola TAM kaplasın,
            // içindeki fotoğraf/video da öyle (kendi profilimizle aynı düzen).
            // Engellediğim kişide sekme içeriği HİÇ çizilmez: sunucu boş liste
            // döndüğü için buraya düşen dal "Bu kullanıcı henüz bir şey
            // izlememiş" gibi YANLIŞ bir sebep gösterirdi. Doğru sebep
            // yukarıdaki _EngelKarti'nda yazıyor.
            if (engelledim)
              const SizedBox.shrink()
            else if (_sekme == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kazanılan rozetler (backend yalnız kazanılanları döner)
                    if ((p['rozetler'] as List<dynamic>? ?? []).isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.military_tech_outlined,
                            size: 18,
                            color: DiziRenkler.sariMetin,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rozetler'.c,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final r in p['rozetler'] as List<dynamic>)
                            RozetCipi(rozet: r as Map<String, dynamic>),
                        ],
                      ),
                    ],
                    // İzledikleri: diziler ve filmler ayrı şeritler.
                    // Başlıktaki sayı GERÇEK toplamdır (şerit son 60'ı gösterir).
                    for (final grup in [
                      (
                        Icons.tv_outlined,
                        'İzlediği Diziler ({})',
                        izlenenler.where((o) => o['tur'] == 'tv').toList(),
                        (st['dizi'] as num?)?.toInt(),
                      ),
                      (
                        Icons.movie_outlined,
                        'İzlediği Filmler ({})',
                        izlenenler.where((o) => o['tur'] == 'movie').toList(),
                        (st['film'] as num?)?.toInt(),
                      ),
                    ])
                      if (grup.$3.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(
                              grup.$1,
                              size: 19,
                              color: DiziRenkler.sariMetin,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              grup.$2.cf([grup.$4 ?? grup.$3.length]),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 208,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: grup.$3.length > 30
                                ? 30
                                : grup.$3.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) {
                              final o = grup.$3[i] as Map<String, dynamic>;
                              return MiniIcerik(
                                key: ValueKey('${o['tur']}-${o['tmdb_id']}'),
                                tmdbId: (o['tmdb_id'] as num).toInt(),
                                tur: o['tur'] as String,
                                izlenenSayi: (o['sayi'] as num?)?.toInt(),
                              );
                            },
                          ),
                        ),
                      ],
                    if (listeler.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.playlist_play,
                            size: 20,
                            color: DiziRenkler.sariMetin,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Listeleri ({})'.cf([listeler.length]),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final l in listeler)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.playlist_play,
                              color: DiziRenkler.sariMetin,
                            ),
                            title: Text(l['ad'] as String? ?? ''),
                            subtitle: Text(
                              '{} içerik'.cf([l['oge_sayisi'] ?? 0]),
                              style: TextStyle(
                                color: DiziRenkler.metin38,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: DiziRenkler.metin38,
                            ),
                            onTap: () =>
                                _listeAc(l['id'] as int, l['ad'] as String?),
                          ),
                        ),
                    ],
                    // Hiç izlemesi/listesi/rozeti olmayan kullanıcıda sekme
                    // bomboş kalmasın
                    if (izlenenler.isEmpty &&
                        listeler.isEmpty &&
                        (p['rozetler'] as List<dynamic>? ?? []).isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: BosDurum(
                          ikon: Icons.movie_outlined,
                          baslik: 'Bu kullanıcı henüz bir şey izlememiş.'.c,
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              )
            // Yorumlarını gizleyen kullanıcı: liste yerine bilgilendirme
            else if (!benMi && p['yorumlar_gizli'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                child: BosDurum(
                  ikon: Icons.visibility_off_outlined,
                  baslik:
                      'Bu kullanıcı yorumlarını gizli tutmayı tercih ediyor.'.c,
                ),
              )
            else ...[
              // Kendi profilimizle BİREBİR aynı widget (profil.dart):
              // görüntülenme, çift dokunuş = beğeni, medyaya dokununca Reels.
              ProfilYorumAkisi(
                yorumlar: yorumlar,
                icerikler: p['icerikler'] as Map<String, dynamic>? ?? {},
                // Bu ekran BAŞKASININ profili — ama /kullanici/<kendi adım>
                // bağlantısıyla da açılabiliyor. Uzun basma menüsü sunucunun
                // `ben_mi` yargısına bağlı: başkasının kartında ASLA çıkmaz.
                benimProfilim: p['ben_mi'] == true,
                onDegisti: _yukle,
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      );
    }

    final p = _profil;
    final digerKullanici =
        p != null && p['ben_mi'] != true && context.watch<Oturum>().girisli;
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.kullaniciAdi}'),
        actions: [
          if (digerKullanici)
            PopupMenuButton<String>(
              onSelected: (secim) {
                if (secim == 'sikayet') {
                  sikayetEtSheet(context, 'kullanici', p['id'] as int);
                } else if (secim == 'engelle') {
                  // ENGELLEME onay ister (yıkıcı: takip bağını koparır),
                  // ENGELİ KALDIRMA istemez (onarıcı, kaybı yok).
                  if (p['engelledim'] == true) {
                    _engelleToggle();
                  } else {
                    _engelleSor();
                  }
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
                PopupMenuItem(
                  value: 'engelle',
                  child: Row(
                    children: [
                      Icon(
                        p['engelledim'] == true
                            ? Icons.block
                            : Icons.block_outlined,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        p['engelledim'] == true
                            ? 'Engeli kaldır'.c
                            : 'Engelle'.c,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      // Kendi profilimizle aynı kural: masaüstünde gövde ortalanır ve azami
      // genişlikte tutulur, mobil düzen gerilmez.
      body: masaustuMu(context)
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: masaustuIcerikGenisligi,
                ),
                child: govde,
              ),
            )
          : govde,
    );
  }

  /// Menüden "Engelle" seçildi: ÖNCE ONAY, sonra istek.
  ///
  /// ONAY ŞART çünkü engelleme YIKICI ve YAN ETKİLİ bir eylem: karşılıklı
  /// takip KOPAR ve engel kaldırılsa bile geri gelmez. Onaysız bir menü
  /// öğesi, yanlış dokunuşla kullanıcının takip ilişkisini sessizce silerdi.
  /// "Engeli kaldır" yönü onay İSTEMEZ — yıkıcı değil, onarıcı bir eylemdir.
  Future<void> _engelleSor() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: DiziRenkler.koyuGri,
        title: Text('@{} engellensin mi?'.cf([widget.kullaniciAdi])),
        content: Text(
          'Birbirinizin gönderilerini, yorumlarını ve profilini göremezsiniz; '
                  'mesaj ve arama da gidemez. Varsa takip bağınız kopar ve '
                  'engeli kaldırsan bile geri gelmez.'
              .c,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: Text('İptal'.c),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dlg, true),
            child: Text('Engelle'.c),
          ),
        ],
      ),
    );
    if (onay == true) await _engelleToggle();
  }

  bool _engelIsleniyor = false;

  Future<void> _engelKaldir() => _engelleToggle();

  Future<void> _engelleToggle() async {
    // Çift dokunuş iki toggle demektir: engel kurulur ve ANINDA geri açılır.
    if (_engelIsleniyor) return;
    setState(() => _engelIsleniyor = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final engellendi = await Api.engelleToggle(widget.kullaniciAdi);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            engellendi ? 'Kullanıcı engellendi'.c : 'Engel kaldırıldı'.c,
          ),
        ),
      );
      // Profili SUNUCUDAN TAZELE: engelleme yalnız bir bayrağı çevirmiyor —
      // sunucu artık içeriği de süzüyor (engellendiyse boş, engel kalktıysa
      // geri gelen gönderiler). Yerel setState ile bayrağı çevirmek ekranı
      // sunucuyla tutarsız bırakırdı (engel kalkınca liste boş kalırdı).
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _engelIsleniyor = false);
    }
  }
}

/// Engellenen kullanıcının profilinde Takip/Mesaj düğmelerinin yerine geçen
/// kart: durumu söyler ve tek dokunuşla geri almayı sunar.
class _EngelKarti extends StatelessWidget {
  final bool isleniyor;
  final Future<void> Function() onKaldir;
  const _EngelKarti({required this.isleniyor, required this.onKaldir});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DiziRenkler.kart,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu kullanıcıyı engelledin'.c,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gönderilerini, yorumlarını ve mesajlarını görmüyorsun; o da seninkileri göremiyor.'
                .c,
            style: TextStyle(
              color: DiziRenkler.metin54,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isleniyor ? null : onKaldir,
              style: FilledButton.styleFrom(
                backgroundColor: DiziRenkler.koyuGri,
                foregroundColor: DiziRenkler.metin,
              ),
              icon: isleniyor
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open, size: 18),
              label: Text('Engeli kaldır'.c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uyum kartı: puan uyumu yüzdesi (varsa) + ortak izlenen dizi/film sayısı.
class _UyumKarti extends StatelessWidget {
  final Map<String, dynamic> uyum;
  const _UyumKarti({required this.uyum});

  @override
  Widget build(BuildContext context) {
    final yuzde = (uyum['yuzde'] as num?)?.toInt();
    final dizi = (uyum['ortak_dizi'] as num?)?.toInt() ?? 0;
    final film = (uyum['ortak_film'] as num?)?.toInt() ?? 0;
    final parcalar = <String>[
      if (dizi > 0) '{} ortak dizi'.cf([dizi]),
      if (film > 0) '{} ortak film'.cf([film]),
    ];
    // Ne yüzde ne ortak varsa kart gösterilmez (backend zaten null döndürür ama
    // ortak da 0 olabilir)
    if (yuzde == null && parcalar.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DiziRenkler.sari.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DiziRenkler.sari.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 22, color: DiziRenkler.sari),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  yuzde != null ? '%$yuzde ${'uyum'.c}' : 'Uyum'.c,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (parcalar.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      parcalar.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: DiziRenkler.metin54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// NOT: buradaki `_Sayac` 21 Ağu 2026'da `profil.dart`a taşındı ve
// `ProfilSayacSutunu` adıyla herkese açıldı — kendi profilim de artık aynı
// sütunları çiziyor. Kopyasını buraya geri koyma; iki ekranın ayrışmasının
// sebebi tam olarak buydu.

/// Profildeki yorum: metin + görüntülenme/beğeni sayıları, içeriğe götürür.
///
/// KENDİ GÖNDERİNDE göz ikonunun sağında "İstatistikleri gör" girişi çıkar
/// (md. 23) — kullanıcının birebir isteği "kendi profiline bakınca kendi
/// yorumunda" idi. Ayrıntılar [IstatistikGirisi] başlığında.
class ProfilYorumKarti extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final Map<String, dynamic> icerikler;
  const ProfilYorumKarti({
    super.key,
    required this.yorum,
    this.icerikler = const {},
  });

  @override
  Widget build(BuildContext context) {
    final tur = yorum['tur'] as String;
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final bolumMu = yorum['sezon'] != null;
    final icerik =
        icerikler['$tur:${yorum['tmdb_id']}'] as Map<String, dynamic>?;
    final ad = icerik?['ad'] as String?;
    final poster = posterUrl(icerik?['poster'] as String?, boyut: 'w92');
    // Bölüm yorumu doğrudan bölüm sayfasına, diğerleri içerik/kişi sayfasına
    final hedef = tur == 'person'
        ? '/kisi/${yorum['tmdb_id']}'
        : bolumMu
        ? '/dizi/${yorum['tmdb_id']}/sezon/${yorum['sezon']}/bolum/${yorum['bolum']}'
        : '/icerik/$tur/${yorum['tmdb_id']}';
    // GÖNDERİ BENİM Mİ? — istatistik girişinin TEK koşulu (md. 23).
    //
    // Kart hem KENDİ profilimin yorumlar sheet'inde hem başkasının profilinde
    // kullanılıyor; ayrım kartın çizildiği YERDEN değil VERİDEN çıkar
    // (`AkisKarti` ile aynı ölçüt). Çıkışsız kullanıcıda `benimId` null olur —
    // `null == null` TUZAĞINA düşmemek için ikisi de dolu olmalı, yoksa
    // `kullanici_id`si olmayan bir satır oturumsuz ziyaretçiye "senin" görünür
    // ve giriş açılıp uçtan 404 alırdı.
    final benimId = context.watch<Oturum>().kullanici?['id'];
    final benim = benimId != null && yorum['kullanici_id'] == benimId;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: DiziRenkler.gonderiZemin,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: Column(
        // KART İÇERİĞİ KADAR YÜKSEK OLMALI. `Column` varsayılanı
        // `MainAxisSize.max`; istatistik girişi (md. 23) için bu Column
        // eklendiğinde kart, sınırsız yükseklikli bir ebeveynde TÜM alanı
        // kaplar hale geldi. Listede fark edilmiyordu ama tıklanabilir
        // InkWell yalnız içerik kadar yüksek kaldığı için kartın alt
        // yarısına yapılan dokunuş HİÇBİR ŞEY YAPMIYORDU.
        // (14 Ağu 2026 — `modal_alt_guvenli_ek_test.dart` iki testi bu
        // yüzden kırıldı: dokunuş boşluğa düşüyor, modal hiç açılmıyordu.)
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: DiziRenkler.koyuGri,
              builder: (_) => _YorumDetayModal(
                yorum: yorum,
                ad: ad,
                poster: poster,
                bolumMu: bolumMu,
                hedef: hedef,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (poster != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: SizedBox(
                              width: 24,
                              height: 34,
                              child: CachedNetworkImage(
                                imageUrl: poster,
                                httpHeaders: gorselBasliklari(poster),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    Container(color: DiziRenkler.koyuGri),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Icon(
                          tur == 'person'
                              ? Icons.person
                              : tur == 'movie'
                              ? Icons.movie
                              : Icons.tv,
                          size: 15,
                          color: DiziRenkler.sariMetin,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          (ad ??
                                  (tur == 'person'
                                      ? 'Kişi yorumu'.c
                                      : tur == 'movie'
                                      ? 'Film yorumu'.c
                                      : 'Dizi yorumu'.c)) +
                              (bolumMu
                                  ? ' · ${'S{}B{}'.cf([yorum['sezon'], yorum['bolum']])}'
                                  : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: DiziRenkler.sariMetin,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tarih,
                        style: TextStyle(
                          fontSize: 11,
                          color: DiziRenkler.gonderiEylem,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    yorum['metin'] as String? ?? '',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  // ETKİLEŞİM SATIRI — kart gövdesinin (poster, başlık, metin)
                  // ALTINDA, AYRI satırda. Medyalı gönderide medya bu kartta değil
                  // detay modalinde çizilir; satır hiçbir hâlde bir Stack'e alınıp
                  // görselin üstüne bindirilmez (kullanıcının açık isteği).
                  //
                  // SIRA VE HİZA: göz → görüntülenme → "İstatistikleri gör" →
                  // beğeni. Satır SOLA DAYALI (Row varsayılanı `start`); giriş
                  // sağa itilmez, sayının hemen yanında durur.
                  Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye,
                        size: 15,
                        color: DiziRenkler.gonderiEylem,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${yorum['goruntulenme'] ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: DiziRenkler.gonderiEylem,
                        ),
                      ),
                      // *** YALNIZ GÖNDERİ SAHİBİNE ***: uç başkasının gönderisine
                      // 404 veriyor (sahiplik SQL'in WHERE'inde), ama arayüzde de
                      // görünmemeli — açılıp "bulunamadı" diyen bir giriş, olmayan
                      // bir girişten daha kötüdür.
                      //
                      // FLEXIBLE: 360 dp'de uzun çevirili dillerde yazı kısalsın,
                      // satır taşmasın (İKON kalır, giriş tanınabilir olur).
                      if (benim) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: IstatistikGirisi(
                            gonderiId: yorum['id'] as int,
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                      // Beğeni sayısına BASILI TUTMAK beğenenleri açar (beğeninin
                      // göründüğü her yerde aynı sheet). onTap YOK: kısa dokunuş
                      // karta ait — gönderi ayrıntısı açılmaya devam eder.
                      InkWell(
                        onLongPress: () =>
                            begenenleriAc(context, yorum['id'] as int),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                size: 15,
                                color: DiziRenkler.sariMetin,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${yorum['begeni'] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DiziRenkler.gonderiEylem,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: DiziRenkler.metin12),
        ],
      ),
    );
  }
}

/// Takipçi ya da takip edilenlerin listesi.
class KullaniciListesiEkrani extends StatefulWidget {
  final String kullaniciAdi;
  final bool takipciler;
  const KullaniciListesiEkrani({
    super.key,
    required this.kullaniciAdi,
    required this.takipciler,
  });

  @override
  State<KullaniciListesiEkrani> createState() => _KullaniciListesiEkraniState();
}

class _KullaniciListesiEkraniState extends State<KullaniciListesiEkrani> {
  List<dynamic>? _liste;

  /// Md. 21 — kullanıcı bu listeyi gizlemeyi seçtiyse sunucu boş liste +
  /// `gizli:true` döner. "Kimse yok" ile "gösterilmiyor" AYNI ŞEY DEĞİL.
  bool _gizli = false;
  String? _hata;

  /// Giriş yapanın takip ettiklerinin kullanıcı adları. null = bilinmiyor
  /// (o hâlde satırlarda düğme çizilmez — bkz. [takipKumesiGetir]).
  Set<String>? _takiptekiler;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  /// İki istek PARALEL gider (`Future.wait`): görüntülenen liste + giriş
  /// yapanın takip ettikleri. Satır başına sorgu (N+1) YOK — 500 satırlık
  /// listede bile toplam 2 istek.
  ///
  /// Kendi "takip ettiklerim" listemde ikinci istek hiç atılmaz: o listedeki
  /// herkesi tanım gereği takip ediyorum.
  Future<void> _yukle() async {
    final benimAdim =
        context.read<Oturum>().kullanici?['kullanici_adi'] as String?;
    final hepsiTakipte =
        !widget.takipciler &&
        benimAdim != null &&
        benimAdim == widget.kullaniciAdi;
    try {
      final sonuc = await Future.wait([
        widget.takipciler
            ? Api.takipciler(widget.kullaniciAdi)
            : Api.takipEdilenler(widget.kullaniciAdi),
        if (!hepsiTakipte)
          takipKumesiGetir(benimAdim)
        else
          Future<Set<String>?>.value(const <String>{}),
      ]);
      final yanit = sonuc[0] as Map<String, dynamic>;
      final liste = yanit['kullanicilar'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        // Md. 21: gizli liste BOŞ liste değildir; ayrı bir metin gerekiyor.
        _gizli = yanit['gizli'] == true;
        _liste = liste;
        _takiptekiler = hepsiTakipte
            ? {
                for (final u in liste)
                  (u as Map<String, dynamic>)['kullanici_adi'] as String,
              }
            : sonuc[1] as Set<String>?;
      });
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  /// Bir satırın düğmesine basılınca kümeyi de güncelle: liste kaydırılıp
  /// satır yeniden kurulduğunda (ListView geri dönüşümü) düğme doğru hâlde
  /// açılsın.
  void _kumeyeYaz(String ad, bool takipte) {
    final k = _takiptekiler;
    if (k == null) return;
    takipte ? k.add(ad) : k.remove(ad);
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_liste == null) {
      govde = const Center(
        child: CircularProgressIndicator(color: DiziRenkler.sari),
      );
    } else if (_gizli) {
      // Md. 21 — gizlenen liste: sebebi SÖYLENİR (yorumlarını gizleyen
      // kullanıcı için zaten aynı kalıp var). Kilit ikonu, "yok" demiyor.
      govde = Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: BosDurum(
          ikon: Icons.lock_outline,
          baslik: widget.takipciler
              ? 'Bu kullanıcı takipçilerini gizli tutmayı tercih ediyor.'.c
              : 'Bu kullanıcı takip ettiklerini gizli tutmayı tercih ediyor.'.c,
        ),
      );
    } else if (_liste!.isEmpty) {
      govde = Center(
        child: Text(
          widget.takipciler ? 'Takipçi yok'.c : 'Kimseyi takip etmiyor'.c,
          style: TextStyle(color: DiziRenkler.metin38),
        ),
      );
    } else {
      final kume = _takiptekiler;
      govde = ListView(
        children: [
          for (final u in _liste!)
            Builder(
              builder: (context) {
                final ad =
                    (u as Map<String, dynamic>)['kullanici_adi'] as String;
                return KullaniciSatiri(
                  key: ValueKey(ad),
                  kullanici: u,
                  takipEdiyorum: satirTakipDurumu(u, kume),
                  onTakipDegisti: (v) => _kumeyeYaz(ad, v),
                );
              },
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.takipciler ? 'Takipçiler'.c : 'Takip Edilenler'.c),
      ),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(azami: masaustuKolonGenisligi, cocuk: govde),
    );
  }
}

/// Kullanıcı listelerinde tek satır: [avatar] [ad + bio] ... [takip düğmesi].
/// Satıra dokunmak profile götürür; sağdaki düğme dokunuşu YUTAR (satır
/// gezinmesini tetiklemez).
///
/// [takipEdiyorum] **null** ise durum bilinmiyordur (sunucu bu uçlarda
/// `takip_ediyorum` döndürmüyor, toplu sorgu da başarısız oldu) ve düğme HİÇ
/// çizilmez: `POST /takip/:ad` bir TOGGLE olduğundan yanlış başlangıç
/// durumuyla çizilen düğme "takip et" sanılan dokunuşta takibi BIRAKIRDI.
class KullaniciSatiri extends StatelessWidget {
  final Map<String, dynamic> kullanici;

  /// Giriş yapan kişi bu satırdakini takip ediyor mu? null = bilinmiyor.
  final bool? takipEdiyorum;

  /// Durum değişince çağrılır (liste sahibinin kendi kaydını tazelemesi için).
  final ValueChanged<bool>? onTakipDegisti;

  const KullaniciSatiri({
    super.key,
    required this.kullanici,
    this.takipEdiyorum,
    this.onTakipDegisti,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = dosyaUrl(kullanici['avatar'] as String?);
    final ad = kullanici['kullanici_adi'] as String? ?? '';
    // Kendi satırım mı? Sunucu bu uçlarda `ben_mi` döndürmüyor, oturumdaki
    // kullanıcı adıyla karşılaştırılır (kendini takip edemezsin).
    final benimAdim =
        context.watch<Oturum>().kullanici?['kullanici_adi'] as String?;
    final benMi =
        kullanici['ben_mi'] == true || (benimAdim != null && benimAdim == ad);
    return ListTile(
      leading: KullaniciAvatari(
        url: avatar,
        kullaniciAdi: ad,
        arkaplan: DiziRenkler.kart,
      ),
      title: Text(
        '@$ad',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: (kullanici['bio'] as String?)?.isNotEmpty == true
          ? Text(
              kullanici['bio'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      // Ad ile düğme arasında ≥12px: yanlışlıkla basmayı zorlaştırır.
      contentPadding: const EdgeInsets.only(left: 16, right: 12),
      horizontalTitleGap: 12,
      minVerticalPadding: 10,
      trailing: (takipEdiyorum == null || benMi)
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 12),
              child: TakipDugmesi(
                kullaniciAdi: ad,
                takipEdiyorum: takipEdiyorum!,
                onDegisti: onTakipDegisti,
              ),
            ),
      onTap: () => context.push('/kullanici/$ad'),
    );
  }
}

/// Kullanıcı arama ekranı (takip edilecek kişileri keşfet).
class KullaniciAramaEkrani extends StatefulWidget {
  const KullaniciAramaEkrani({super.key});

  @override
  State<KullaniciAramaEkrani> createState() => _KullaniciAramaEkraniState();
}

class _KullaniciAramaEkraniState extends State<KullaniciAramaEkrani> {
  final _arama = TextEditingController();
  List<dynamic> _sonuc = [];
  bool _yukleniyor = false;

  /// Takip ettiklerim — ekran açılırken BİR KEZ alınır. Her tuş vuruşunda
  /// yeniden istenseydi arama uçtan uca iki katı istek atardı.
  Set<String>? _takiptekiler;

  @override
  void initState() {
    super.initState();
    final benimAdim =
        context.read<Oturum>().kullanici?['kullanici_adi'] as String?;
    takipKumesiGetir(benimAdim).then((k) {
      if (mounted) setState(() => _takiptekiler = k);
    });
  }

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _ara(String q) async {
    if (q.trim().length < 2) {
      setState(() => _sonuc = []);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final r = await Api.kullaniciAra(q);
      if (mounted) setState(() => _sonuc = r);
    } catch (_) {
      // sessiz geç
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _arama,
          autofocus: true,
          onChanged: _ara,
          decoration: InputDecoration(
            hintText: 'Kullanıcı adı ara...'.c,
            border: InputBorder.none,
          ),
        ),
      ),
      // PC'de akış ile AYNI ortalanmış okuma kolonu (madde 26); mobilde kısıt
      // bağlamaz.
      body: OrtaKolon(
        azami: masaustuKolonGenisligi,
        cocuk: _yukleniyor
            ? const Center(
                child: CircularProgressIndicator(color: DiziRenkler.sari),
              )
            : _sonuc.isEmpty
            ? Center(
                child: Text(
                  'En az 2 harf yaz'.c,
                  style: TextStyle(color: DiziRenkler.metin38),
                ),
              )
            : ListView(
                children: [
                  for (final u in _sonuc)
                    Builder(
                      builder: (context) {
                        final ad =
                            (u as Map<String, dynamic>)['kullanici_adi']
                                as String;
                        final kume = _takiptekiler;
                        return KullaniciSatiri(
                          key: ValueKey(ad),
                          kullanici: u,
                          takipEdiyorum: satirTakipDurumu(u, kume),
                          onTakipDegisti: (v) =>
                              v ? kume?.add(ad) : kume?.remove(ad),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

/// Açık listenin içeriğini gösteren alt sayfa.
/// Profildeki yorumun modal görünümü: içerik başlığı + tam metin + medya.
class _YorumDetayModal extends StatelessWidget {
  final Map<String, dynamic> yorum;
  final String? ad;
  final String? poster;
  final bool bolumMu;
  final String hedef;

  const _YorumDetayModal({
    required this.yorum,
    required this.ad,
    required this.poster,
    required this.bolumMu,
    required this.hedef,
  });

  @override
  Widget build(BuildContext context) {
    final medya = (yorum['medya'] as List<dynamic>? ?? []).cast<String>();
    final tarih = (yorum['tarih'] as String? ?? '').split('T').first;
    final baslik =
        (ad ?? '') +
        (bolumMu ? ' · ${'S{}B{}'.cf([yorum['sezon'], yorum['bolum']])}' : '');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, kontrol) => ListView(
        controller: kontrol,
        // ALT GÜVENLİ ALAN: takvimdeki BolumModali ile aynı hata — açık
        // `padding` Flutter'ın otomatik alt payını kapatıyor.
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          altGuvenli(context, ekstra: 24),
        ),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: DiziRenkler.metin24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // İçerik başlığı: tıklayınca ilgili sayfaya gider
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // Yönlendirici modal kapanmadan ÖNCE alınır (ölü context)
              final yonlendirici = GoRouter.of(context);
              Navigator.pop(context);
              yonlendirici.push(hedef);
            },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 46,
                    height: 68,
                    child: poster != null
                        ? CachedNetworkImage(
                            imageUrl: poster!,
                            httpHeaders: gorselBasliklari(poster),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: DiziRenkler.kart,
                              child: Icon(
                                Icons.movie,
                                color: DiziRenkler.metin38,
                              ),
                            ),
                          )
                        : Container(
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.movie,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    baslik,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: DiziRenkler.sariMetin,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: DiziRenkler.metin),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            yorum['metin'] as String? ?? '',
            style: const TextStyle(height: 1.5, fontSize: 14),
          ),
          if (medya.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: medya.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: medya[i].endsWith('.mp4') || medya[i].endsWith('.webm')
                      ? Container(
                          width: 120,
                          color: DiziRenkler.kart,
                          child: Icon(
                            Icons.play_circle_outline,
                            color: DiziRenkler.metin54,
                            size: 32,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: dosyaUrl(medya[i])!,
                          width: 120,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 120,
                            color: DiziRenkler.kart,
                            child: Icon(
                              Icons.broken_image,
                              color: DiziRenkler.metin38,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.remove_red_eye,
                size: 15,
                color: DiziRenkler.gonderiEylem,
              ),
              const SizedBox(width: 4),
              Text(
                '${yorum['goruntulenme'] ?? 0}',
                style: TextStyle(fontSize: 12, color: DiziRenkler.gonderiEylem),
              ),
              const SizedBox(width: 14),
              InkWell(
                onLongPress: () => begenenleriAc(context, yorum['id'] as int),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 15,
                        color: DiziRenkler.sariMetin,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${yorum['begeni'] ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: DiziRenkler.gonderiEylem,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                tarih,
                style: TextStyle(fontSize: 11, color: DiziRenkler.gonderiEylem),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

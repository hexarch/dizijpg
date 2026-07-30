import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../ceviri.dart';
import '../dosya_oku.dart';
import '../push.dart';
import '../tema.dart';
import 'medya_goster.dart';
import 'ortak.dart';
import 'ses.dart';

/// Sohbet listesi: partner başına son mesaj + okunmamış rozeti.
class SohbetlerEkrani extends StatefulWidget {
  const SohbetlerEkrani({super.key});

  @override
  State<SohbetlerEkrani> createState() => _SohbetlerEkraniState();
}

class _SohbetlerEkraniState extends State<SohbetlerEkrani> {
  List<dynamic>? _sohbetler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final d = await Api.get('/sohbetler');
      if (!mounted) return;
      setState(() => _sohbetler = d['sohbetler'] as List<dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = HataGorunumu(mesaj: _hata!, tekrar: _yukle);
    } else if (_sohbetler == null) {
      govde = const IskeletListe();
    } else if (_sohbetler!.isEmpty) {
      govde = BosDurum(
        ikon: Icons.chat_outlined,
        baslik: 'Henüz sohbetin yok'.c,
        ipucu: 'Bir profile girip mesaj gönderebilirsin.'.c,
      );
    } else {
      govde = RefreshIndicator(
        color: DiziRenkler.sari,
        onRefresh: _yukle,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _sohbetler!.length,
          itemBuilder: (context, i) {
            final s = _sohbetler![i] as Map<String, dynamic>;
            final avatar = dosyaUrl(s['partner_avatar'] as String?);
            final okunmamis = (s['okunmamis'] as int?) ?? 0;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: DiziRenkler.koyuGri,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Icon(Icons.person, color: DiziRenkler.metin38)
                      : null,
                ),
                title: Text(
                  '@${s['partner']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Builder(
                  builder: (_) {
                    // Metinsiz son mesaj: "·" yerine türünü söyle (ses/foto/…)
                    final ozet = mesajOzeti(s);
                    final yazi = Text(
                      ozet.metin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: DiziRenkler.metin54),
                    );
                    if (ozet.ikon == null) return yazi;
                    return Row(
                      children: [
                        Icon(ozet.ikon, size: 14, color: DiziRenkler.metin54),
                        const SizedBox(width: 4),
                        Expanded(child: yazi),
                      ],
                    );
                  },
                ),
                trailing: okunmamis > 0
                    ? CircleAvatar(
                        radius: 11,
                        backgroundColor: DiziRenkler.sari,
                        child: Text(
                          '$okunmamis',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      )
                    : null,
                onTap: () async {
                  await context.push('/sohbet/${s['partner']}');
                  _yukle();
                },
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Mesajlar'.c)),
      body: govde,
    );
  }
}

/// İkili sohbet: metin + fotoğraf/GIF + dizi/film kartı. 5 sn'de bir yenilenir.
class SohbetEkrani extends StatefulWidget {
  final String kullaniciAdi;

  const SohbetEkrani({super.key, required this.kullaniciAdi});

  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  List<dynamic> _mesajlar = [];
  final Map<String, dynamic> _icerikler = {};
  bool _yuklendi = false;
  bool _gonderiliyor = false;
  bool _ekYukleniyor = false;
  bool _yaziyor = false; // karşı taraf yazıyor mu
  String? _hata; // ilk yükleme hatası
  Map<String, dynamic>? _partner; // avatar + son_gorulme
  Map<String, dynamic>? _yanitlanan; // alıntılanan mesaj (yanıt modu)
  int? _duzenlenenId; // düzenlenen mesajın id'si (düzenleme modu)
  DateTime _sonYaziyorBildirimi = DateTime.fromMillisecondsSinceEpoch(0);
  final _metin = TextEditingController();
  final _kaydirma = ScrollController();
  Timer? _sayac;
  // Sesli mesaj kaydı
  // Web'de mikrofon gizli; kaydediciyi hiç kurma ki eklenti kanalı
  // MissingPluginException gürültüsü üretmesin (hata günlüğü #8-16).
  final AudioRecorder? _kaydedici = kIsWeb ? null : AudioRecorder();
  bool _kaydediyor = false;
  int _kayitSn = 0;
  Timer? _kayitSayaci;
  String? _kayitYolu;
  // Kayıt sırasında mikrofon genliği (0..1) — hem canlı çubuklar hem de
  // mesajla gönderilen dalga formu bundan üretilir.
  final List<double> _seviyeler = [];
  StreamSubscription<Amplitude>? _seviyeAbonelik;

  /// Yazarken karşı tarafa "yazıyor" sinyali (3 sn'de bir en fazla).
  void _yaziyorBildir() {
    final simdi = DateTime.now();
    if (simdi.difference(_sonYaziyorBildirimi).inSeconds < 3) return;
    _sonYaziyorBildirimi = simdi;
    Api.post('/yaziyor', {
      'kullanici_adi': widget.kullaniciAdi,
    }).catchError((_) => null);
  }

  @override
  void initState() {
    super.initState();
    _yukle(ilk: true);
    _sayac = Timer.periodic(const Duration(seconds: 5), (_) => _yukle());
    // Bu sohbetin biriken mesaj bildirimini kapat, geçmişini sıfırla
    mesajBildirimleriniTemizle(widget.kullaniciAdi);
  }

  @override
  void dispose() {
    _sayac?.cancel();
    _kayitSayaci?.cancel();
    _seviyeAbonelik?.cancel();
    _kaydedici?.dispose();
    _metin.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  // ---- Sesli mesaj kaydı ----
  Future<void> _kayitBasla() async {
    try {
      if (_kaydedici == null) return;
      if (!await _kaydedici.hasPermission()) return;
      final dizin = await getTemporaryDirectory();
      final yol =
          '${dizin.path}/ses_${DateTime.now().millisecondsSinceEpoch}.ogg';
      await _kaydedici.start(
        const RecordConfig(encoder: AudioEncoder.opus),
        path: yol,
      );
      _kayitYolu = yol;
      if (!mounted) return;
      setState(() {
        _kaydediyor = true;
        _kayitSn = 0;
        _seviyeler.clear();
      });
      // Canlı ses şiddeti: 100 ms'de bir örnek (2 dk × 10 = en çok 1200 örnek)
      _seviyeAbonelik?.cancel();
      _seviyeAbonelik = _kaydedici
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            if (!mounted) return;
            setState(() => _seviyeler.add(genlikNormalle(a.current)));
          });
      _kayitSayaci = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _kayitSn++);
        if (_kayitSn >= 120) _kayitGonder(); // 2 dk üst sınır
      });
    } catch (_) {
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  Future<void> _kayitIptal() async {
    _kayitSayaci?.cancel();
    _seviyeAbonelik?.cancel();
    try {
      await _kaydedici?.stop();
    } catch (_) {}
    _kayitYolu = null;
    if (mounted) {
      setState(() {
        _kaydediyor = false;
        _kayitSn = 0;
      });
    }
  }

  Future<void> _kayitGonder() async {
    _kayitSayaci?.cancel();
    _seviyeAbonelik?.cancel();
    final saniye = _kayitSn;
    final dalga = dalgaKodla(_seviyeler, saniye);
    String? yol;
    try {
      yol = await _kaydedici?.stop();
    } catch (_) {}
    yol ??= _kayitYolu;
    if (mounted) {
      setState(() {
        _kaydediyor = false;
        _kayitSn = 0;
      });
    }
    if (yol == null || saniye < 1) return; // çok kısa → iptal
    if (mounted) setState(() => _ekYukleniyor = true);
    try {
      final bayt = await dosyaOku(yol);
      final sonuc = await Api.medyaYukle(bayt);
      await _gonder(
        medya: sonuc['yol'] as String,
        sesDalga: dalga.isEmpty ? null : dalga,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ses gönderilemedi'.c)));
      }
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  void _sonaKaydir() {
    // Görsel/video baloncukları sonradan yüklenip yüksekliği değiştirdiğinden
    // birkaç kez dener; her seferinde gerçek en-alta sabitler.
    for (final ms in const [0, 120, 400]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted && _kaydirma.hasClients) {
          _kaydirma.jumpTo(_kaydirma.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _yukle({bool ilk = false}) async {
    try {
      final d = await Api.get('/mesajlar/${widget.kullaniciAdi}');
      if (!mounted) return;
      final yeni = d['mesajlar'] as List<dynamic>;
      final degisti = yeni.length != _mesajlar.length;
      // setState'ten ÖNCE ölç: kullanıcı en altta mıydı? (yukarıda eski mesaj
      // okuyorsa yeni mesaj gelince zorla aşağı atmayalım — WhatsApp davranışı)
      final altaYakinDi =
          !_kaydirma.hasClients ||
          _kaydirma.position.pixels >= _kaydirma.position.maxScrollExtent - 250;
      setState(() {
        _mesajlar = yeni;
        _icerikler.addAll(d['icerikler'] as Map<String, dynamic>? ?? {});
        _yaziyor = d['yaziyor'] == true;
        _partner = d['partner'] as Map<String, dynamic>?;
        _yuklendi = true;
        _hata = null;
      });
      if (ilk || (degisti && altaYakinDi)) _sonaKaydir();
    } catch (e) {
      // İlk yüklemede hata → boş sohbet yerine hata + tekrar dene göster
      if (mounted && ilk) {
        setState(() {
          _yuklendi = true;
          _hata = e.toString();
        });
      }
    }
  }

  /// Kendi mesajını sil: önce yerelde kaldır (iyimser), hata olursa geri getir.
  Future<void> _mesajSil(int id) async {
    final yedek = List<dynamic>.from(_mesajlar);
    setState(
      () => _mesajlar = _mesajlar
          .where((m) => (m as Map<String, dynamic>)['id'] != id)
          .toList(),
    );
    try {
      await Api.delete('/mesajlar/$id');
    } catch (e) {
      if (!mounted) return;
      setState(() => _mesajlar = yedek);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mesaj silinemedi'.c)));
    }
  }

  Future<void> _gonder({
    String? metin,
    String? medya,
    String? sesDalga,
    String? icerikTur,
    int? icerikId,
  }) async {
    if (_gonderiliyor) return;
    // Düzenleme modunda: metni PATCH ile güncelle, yeni mesaj atma
    if (_duzenlenenId != null) {
      await _duzenlemeyiKaydet(metin ?? '');
      return;
    }
    setState(() => _gonderiliyor = true);
    try {
      await Api.post('/mesajlar', {
        'kullanici_adi': widget.kullaniciAdi,
        if (metin != null && metin.isNotEmpty) 'metin': metin,
        if (medya != null) 'medya': medya,
        if (sesDalga != null) 'ses_dalga': sesDalga,
        if (icerikTur != null) 'icerik_tur': icerikTur,
        if (icerikId != null) 'icerik_id': icerikId,
        if (_yanitlanan != null)
          'yanit_id': (_yanitlanan!['id'] as num).toInt(),
      });
      _metin.clear();
      setState(() => _yanitlanan = null);
      await _yukle();
      _sonaKaydir();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  /// Bir mesaja yanıt vermeye başla (alıntı kutusu belirir, klavye açılır).
  void _yanitBaslat(Map<String, dynamic> m) {
    setState(() {
      _duzenlenenId = null;
      _yanitlanan = m;
    });
  }

  /// Kendi metin mesajını düzenlemeye başla (metin kutusuna yüklenir).
  void _duzenlemeBaslat(Map<String, dynamic> m) {
    setState(() {
      _yanitlanan = null;
      _duzenlenenId = (m['id'] as num).toInt();
      _metin.text = (m['metin'] as String?) ?? '';
      _metin.selection = TextSelection.fromPosition(
        TextPosition(offset: _metin.text.length),
      );
    });
  }

  void _modIptal() {
    setState(() {
      _yanitlanan = null;
      _duzenlenenId = null;
      _metin.clear();
    });
  }

  Future<void> _duzenlemeyiKaydet(String metin) async {
    final id = _duzenlenenId;
    if (id == null) return;
    if (metin.trim().isEmpty) return;
    setState(() => _gonderiliyor = true);
    try {
      await Api.patch('/mesajlar/$id', {'metin': metin.trim()});
      _metin.clear();
      setState(() => _duzenlenenId = null);
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  /// Galeriden fotoğraf/GIF/video seç, yükle ve mesaj olarak gönder.
  Future<void> _fotoGonder() async {
    final secim = await ImagePicker().pickMedia();
    if (secim == null) return;
    setState(() => _ekYukleniyor = true);
    try {
      final veri = await secim.readAsBytes();
      if (veri.length > 30 * 1024 * 1024) {
        throw ApiHata('Dosya en fazla 30MB olabilir'.c);
      }
      final d = await Api.medyaYukle(veri);
      await _gonder(medya: d['yol'] as String);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  /// Dizi/film arayıp kart olarak gönder.
  Future<void> _icerikPaylas() async {
    final secilen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => const _IcerikSecSheet(),
    );
    if (secilen == null) return;
    final tur = (secilen['media_type'] as String?) ?? 'tv';
    await _gonder(icerikTur: tur, icerikId: (secilen['id'] as num).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final benimId = context.watch<Oturum>().kullanici?['id'];

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => context.push('/kullanici/${widget.kullaniciAdi}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${widget.kullaniciAdi}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_yaziyor)
                Text(
                  'yazıyor...'.c,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DiziRenkler.sariMetin,
                  ),
                )
              else
                _DurumSatiri(sonGorulme: _partner?['son_gorulme'] as String?),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          // Genis ekranda sohbet kolonu ortalanir (Telegram Web gibi)
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Expanded(
                child: !_yuklendi
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: DiziRenkler.sari,
                        ),
                      )
                    : (_hata != null && _mesajlar.isEmpty)
                    ? HataGorunumu(
                        mesaj: _hata!,
                        tekrar: () => _yukle(ilk: true),
                      )
                    : ListView.builder(
                        controller: _kaydirma,
                        padding: const EdgeInsets.all(12),
                        itemCount: _mesajlar.length,
                        itemBuilder: (context, i) {
                          final m = _mesajlar[i] as Map<String, dynamic>;
                          final gun = (m['tarih'] as String? ?? '')
                              .split('T')
                              .first;
                          final oncekiGun = i > 0
                              ? ((_mesajlar[i - 1]
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['tarih']
                                            as String? ??
                                        '')
                                    .split('T')
                                    .first
                              : null;
                          final benimMi = m['gonderen_id'] == benimId;
                          final metinMi =
                              (m['metin'] as String?)?.isNotEmpty == true &&
                              m['medya'] == null &&
                              m['icerik_tur'] == null;
                          final baloncuk = _MesajBaloncugu(
                            // Poll (5sn) listeyi yenilerken baloncuk id ile
                            // eşleşsin: medya yeniden yüklenip kaymasın.
                            key: ValueKey(m['id'] ?? 'm$i'),
                            mesaj: m,
                            benim: benimMi,
                            icerikler: _icerikler,
                            yanitla: m['id'] != null
                                ? () => _yanitBaslat(m)
                                : null,
                            sil: benimMi && m['id'] != null
                                ? () => _mesajSil((m['id'] as num).toInt())
                                : null,
                            duzenle: benimMi && metinMi
                                ? () => _duzenlemeBaslat(m)
                                : null,
                          );
                          if (gun == oncekiGun || gun.isEmpty) return baloncuk;
                          // Tarih ayracı: gün değişince ortada küçük rozet
                          final p = gun.split('-');
                          final etiket = p.length == 3
                              ? '${p[2]}.${p[1]}.${p[0]}'
                              : gun;
                          return Column(
                            children: [
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DiziRenkler.koyuGri,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    etiket,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: DiziRenkler.metin54,
                                    ),
                                  ),
                                ),
                              ),
                              baloncuk,
                            ],
                          );
                        },
                      ),
              ),
              // Yanıt / düzenleme kutusu (giriş alanının hemen üstünde)
              if (_yanitlanan != null || _duzenlenenId != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  color: DiziRenkler.koyuGri,
                  child: Row(
                    children: [
                      Icon(
                        _duzenlenenId != null ? Icons.edit : Icons.reply,
                        size: 18,
                        color: DiziRenkler.sariMetin,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _duzenlenenId != null
                                  ? 'Mesajı düzenle'.c
                                  : 'Yanıtlanıyor'.c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: DiziRenkler.sariMetin,
                              ),
                            ),
                            Text(
                              _duzenlenenId != null
                                  ? ((_metin.text).trim())
                                  : _yanitOnizleme(_yanitlanan!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: DiziRenkler.metin54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _modIptal,
                        icon: Icon(Icons.close, color: DiziRenkler.metin54),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                  child: _kaydediyor
                      ? _kayitCubugu()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Fotoğraf / GIF (düzenleme modunda kapalı — düzenleme yalnız metin)
                            IconButton(
                              tooltip: 'Fotoğraf / video ekle'.c,
                              onPressed:
                                  (_ekYukleniyor || _duzenlenenId != null)
                                  ? null
                                  : _fotoGonder,
                              icon: _ekYukleniyor
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: DiziRenkler.sari,
                                      ),
                                    )
                                  : Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: _duzenlenenId != null
                                          ? DiziRenkler.metin24
                                          : DiziRenkler.sariMetin,
                                    ),
                            ),
                            // Dizi/film kartı paylaş (düzenleme modunda kapalı)
                            IconButton(
                              tooltip: 'İçerik paylaş'.c,
                              onPressed: _duzenlenenId != null
                                  ? null
                                  : _icerikPaylas,
                              icon: Icon(
                                Icons.local_movies_outlined,
                                color: _duzenlenenId != null
                                    ? DiziRenkler.metin24
                                    : DiziRenkler.sariMetin,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _metin,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 2000,
                                buildCounter:
                                    (
                                      _, {
                                      required currentLength,
                                      maxLength,
                                      required isFocused,
                                    }) => null,
                                onChanged: (_) => _yaziyorBildir(),
                                onSubmitted: (_) =>
                                    _gonder(metin: _metin.text.trim()),
                                decoration: InputDecoration(
                                  hintText: 'Mesajını yaz...'.c,
                                ),
                              ),
                            ),
                            // Sesli mesaj kaydı (web'de yok; düzenlemede kapalı)
                            if (!kIsWeb)
                              IconButton(
                                tooltip: 'Sesli mesaj'.c,
                                onPressed:
                                    (_ekYukleniyor || _duzenlenenId != null)
                                    ? null
                                    : _kayitBasla,
                                icon: Icon(
                                  Icons.mic_none,
                                  color: _duzenlenenId != null
                                      ? DiziRenkler.metin24
                                      : DiziRenkler.sariMetin,
                                ),
                              ),
                            const SizedBox(width: 2),
                            IconButton.filled(
                              tooltip: 'Gönder'.c,
                              onPressed: _gonderiliyor
                                  ? null
                                  : () => _gonder(metin: _metin.text.trim()),
                              style: IconButton.styleFrom(
                                backgroundColor: DiziRenkler.sari,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kayıt sırasında giriş çubuğu: iptal + nabız + canlı dalga + süre + gönder.
  Widget _kayitCubugu() {
    final dk = _kayitSn ~/ 60;
    final sn = (_kayitSn % 60).toString().padLeft(2, '0');
    // Son 40 örnek akar; başta soldan doldurmak için sıfırlarla tamamlanır.
    final son = _seviyeler.length > dalgaOrnekSayisi
        ? _seviyeler.sublist(_seviyeler.length - dalgaOrnekSayisi)
        : [
            ..._seviyeler,
            ...List.filled(dalgaOrnekSayisi - _seviyeler.length, 0.0),
          ];
    return Row(
      children: [
        IconButton(
          tooltip: 'İptal'.c,
          onPressed: _kayitIptal,
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        ),
        const _KayitNabzi(),
        const SizedBox(width: 10),
        Text(
          '$dk:$sn',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SesDalga(
            seviyeler: son,
            renk: DiziRenkler.sari,
            yukseklik: 28,
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'Gönder'.c,
          onPressed: _kayitGonder,
          style: IconButton.styleFrom(
            backgroundColor: DiziRenkler.sari,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}

/// Kayıt sırasında yanıp sönen kırmızı nokta.
class _KayitNabzi extends StatefulWidget {
  const _KayitNabzi();
  @override
  State<_KayitNabzi> createState() => _KayitNabziState();
}

class _KayitNabziState extends State<_KayitNabzi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
    child: Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// Başlıktaki durum satırı: son 60 sn içinde aktifse "çevrimiçi", değilse
/// "son görülme ...". son_gorulme ISO zaman damgası (UTC) beklenir.
class _DurumSatiri extends StatelessWidget {
  final String? sonGorulme;
  const _DurumSatiri({this.sonGorulme});

  @override
  Widget build(BuildContext context) {
    if (sonGorulme == null) return const SizedBox.shrink();
    final an = DateTime.tryParse(sonGorulme!)?.toLocal();
    if (an == null) return const SizedBox.shrink();
    final fark = DateTime.now().difference(an);
    final cevrimici = fark.inSeconds < 60;
    final String etiket;
    if (cevrimici) {
      etiket = 'çevrimiçi'.c;
    } else if (fark.inMinutes < 60) {
      etiket = 'son görülme {} dk önce'.cf([fark.inMinutes]);
    } else if (fark.inHours < 24) {
      etiket = 'son görülme {} saat önce'.cf([fark.inHours]);
    } else {
      etiket = 'son görülme {} gün önce'.cf([fark.inDays]);
    }
    return Text(
      etiket,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: cevrimici ? DiziRenkler.sariMetin : DiziRenkler.metin54,
      ),
    );
  }
}

bool sesDosyasi(String yol) =>
    yol.endsWith('.ogg') ||
    yol.endsWith('.m4a') ||
    yol.endsWith('.mp3') ||
    yol.endsWith('.aac');

/// Metinsiz mesajın (ses/foto/video/içerik) kısa özeti: ikon + söz.
/// Hem sohbet listesindeki son mesaj satırında hem alıntı kutusunda kullanılır.
({IconData? ikon, String metin}) mesajOzeti(Map<String, dynamic> m) {
  final metin = (m['metin'] as String?)?.trim();
  if (metin != null && metin.isNotEmpty) return (ikon: null, metin: metin);
  final medya = m['medya'] as String? ?? m['yanit_medya'] as String?;
  if (medya != null) {
    if (sesDosyasi(medya)) {
      return (ikon: Icons.mic, metin: 'Sesli mesaj'.c);
    }
    if (medya.endsWith('.mp4') || medya.endsWith('.webm')) {
      return (ikon: Icons.videocam, metin: 'Video'.c);
    }
    return (ikon: Icons.photo, metin: 'Fotoğraf'.c);
  }
  if (m['icerik_tur'] != null || m['yanit_icerik_tur'] != null) {
    return (ikon: Icons.local_movies, metin: 'İçerik'.c);
  }
  return (ikon: null, metin: '');
}

/// Alıntı/yanıt kutusu için kısa önizleme metni.
String _yanitOnizleme(Map<String, dynamic> m) => mesajOzeti(m).metin;

/// Tek mesaj baloncuğu: metin, medya (foto/GIF/video) ve içerik kartı.
class _MesajBaloncugu extends StatelessWidget {
  final Map<String, dynamic> mesaj;
  final bool benim;
  final Map<String, dynamic> icerikler;
  final VoidCallback? sil;
  final VoidCallback? yanitla;
  final VoidCallback? duzenle;

  const _MesajBaloncugu({
    super.key,
    required this.mesaj,
    required this.benim,
    required this.icerikler,
    this.sil,
    this.yanitla,
    this.duzenle,
  });

  /// Uzun basınca: Yanıtla / Düzenle / Sil (uygun olanlar). Telegram tarzı menü.
  void _menuAc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (yanitla != null)
              ListTile(
                leading: Icon(Icons.reply, color: DiziRenkler.sariMetin),
                title: Text('Yanıtla'.c),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  yanitla!();
                },
              ),
            if (duzenle != null)
              ListTile(
                leading: Icon(Icons.edit, color: DiziRenkler.sariMetin),
                title: Text('Düzenle'.c),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  duzenle!();
                },
              ),
            if (sil != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: Text(
                  'Mesajı sil'.c,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  sil!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = mesaj;
    final metin = m['metin'] as String?;
    final medya = m['medya'] as String?;
    final video =
        medya != null && (medya.endsWith('.mp4') || medya.endsWith('.webm'));
    final ses = medya != null && sesDosyasi(medya);
    final icerikTur = m['icerik_tur'] as String?;
    final icerikId = (m['icerik_id'] as num?)?.toInt();
    final icerik = icerikTur != null
        ? icerikler['$icerikTur:$icerikId'] as Map<String, dynamic>?
        : null;
    final saat = (m['tarih'] as String? ?? '');
    final saatKisa = saat.length >= 16 ? saat.substring(11, 16) : '';
    final yaziRengi = benim ? Colors.black : DiziRenkler.metin;

    final yanitId = m['yanit_id'];
    final duzenlendi = m['duzenlendi'] == true;

    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Uzun bas → Yanıtla / Düzenle / Sil menüsü
        onLongPress: (yanitla == null && duzenle == null && sil == null)
            ? null
            : () => _menuAc(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          constraints: BoxConstraints(
            // PC'de dev baloncuk olmasın: dar ekranda %75, genişte 420px tavan
            maxWidth: MediaQuery.of(context).size.width > 560
                ? 420
                : MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: benim ? DiziRenkler.sari : DiziRenkler.kart,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(benim ? 14 : 3),
              bottomRight: Radius.circular(benim ? 3 : 14),
            ),
          ),
          // IntrinsicWidth: baloncuk en geniş çocuğuna (metin/footer) göre küçülür;
          // kısa mesaj ("selam") artık tüm satırı kaplamaz (WhatsApp/Telegram gibi).
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Alıntılanan mesaj önizlemesi (yanıtsa)
                if (yanitId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: (benim ? Colors.black : DiziRenkler.metin)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: benim ? Colors.black54 : DiziRenkler.sari,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      _yanitOnizleme({
                        'metin': m['yanit_metin'],
                        'yanit_medya': m['yanit_medya'],
                        'yanit_icerik_tur': m['yanit_icerik_tur'],
                      }),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: yaziRengi.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                // Sesli mesaj
                if (ses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SesOynatici(
                      key: ValueKey('ses-$medya'), // poll'da state korunsun
                      url: dosyaUrl(medya)!,
                      renk: yaziRengi,
                      dalga: m['ses_dalga'] as String?,
                    ),
                  ),
                // Fotoğraf / GIF / video
                if (medya != null && !ses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    // Foto/GIF ve video: dokununca tam ekran görüntüleyici
                    // (yakınlaştırma + video oynatma/sarma)
                    child: InkWell(
                      onTap: () => medyaGoster(context, [dosyaUrl(medya)!]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: video
                            ? Container(
                                width: 180,
                                height: 120,
                                color: Colors.black26,
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  size: 40,
                                  color: Colors.white70,
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: dosyaUrl(medya)!,
                                width: 200,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.black26,
                                ),
                                errorWidget: (_, _, _) => Container(
                                  width: 200,
                                  height: 150,
                                  color: Colors.black26,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                // Dizi/film kartı
                if (icerikTur != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => context.push('/icerik/$icerikTur/$icerikId'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 38,
                                height: 56,
                                child: icerik?['poster'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: posterUrl(
                                          icerik!['poster'] as String?,
                                          boyut: 'w92',
                                        )!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: DiziRenkler.koyuGri,
                                        child: Icon(
                                          Icons.movie,
                                          size: 18,
                                          color: DiziRenkler.metin38,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                icerik?['ad'] as String? ?? '...',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: yaziRengi,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: yaziRengi.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (metin != null && metin.isNotEmpty)
                  Text(metin, style: TextStyle(color: yaziRengi, height: 1.35)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (duzenlendi) ...[
                        Text(
                          'düzenlendi'.c,
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: yaziRengi.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        saatKisa,
                        style: TextStyle(
                          fontSize: 10,
                          color: yaziRengi.withValues(alpha: 0.55),
                        ),
                      ),
                      if (benim) ...[
                        const SizedBox(width: 3),
                        // Okundu → WhatsApp geleneği: MAVİ çift tik.
                        Icon(
                          m['okundu'] == true ? Icons.done_all : Icons.done,
                          size: 13,
                          color: m['okundu'] == true
                              ? const Color(0xFF1976D2)
                              : yaziRengi.withValues(alpha: 0.55),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sohbette paylaşmak için dizi/film arama sayfası.
class _IcerikSecSheet extends StatefulWidget {
  const _IcerikSecSheet();

  @override
  State<_IcerikSecSheet> createState() => _IcerikSecSheetState();
}

class _IcerikSecSheetState extends State<_IcerikSecSheet> {
  final _arama = TextEditingController();
  Timer? _geciktirici;
  List<dynamic> _sonuclar = [];

  @override
  void dispose() {
    _arama.dispose();
    _geciktirici?.cancel();
    super.dispose();
  }

  void _degisti(String q) {
    _geciktirici?.cancel();
    _geciktirici = Timer(const Duration(milliseconds: 400), () => _ara(q));
  }

  Future<void> _ara(String q) async {
    if (q.trim().length < 2) return;
    try {
      final d = await Api.get(
        '/tmdb/search/multi?query=${Uri.encodeComponent(q.trim())}',
      );
      if (!mounted) return;
      setState(() {
        _sonuclar = (d['results'] as List<dynamic>)
            .where(
              (r) =>
                  (r['media_type'] == 'tv' || r['media_type'] == 'movie') &&
                  r['poster_path'] != null,
            )
            .toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _arama,
              autofocus: true,
              onChanged: _degisti,
              decoration: InputDecoration(
                hintText: 'Dizi, film veya kişi ara...'.c,
                prefixIcon: Icon(Icons.search, color: DiziRenkler.metin38),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sonuclar.length,
              itemBuilder: (context, i) {
                final r = _sonuclar[i] as Map<String, dynamic>;
                final poster = posterUrl(
                  r['poster_path'] as String?,
                  boyut: 'w92',
                );
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 34,
                      height: 50,
                      child: poster != null
                          ? CachedNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover,
                            )
                          : Container(color: DiziRenkler.kart),
                    ),
                  ),
                  title: Text(
                    (r['name'] ?? r['title'] ?? '?') as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r['media_type'] == 'tv' ? 'Dizi'.c : 'Film'.c,
                    style: TextStyle(fontSize: 11, color: DiziRenkler.metin38),
                  ),
                  onTap: () => Navigator.pop(context, r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

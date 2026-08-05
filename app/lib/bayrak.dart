import 'package:flutter/material.dart';

import 'tema.dart';

/// Ülke adı → bayrak görseli.
///
/// NEDEN EMOJİ DEĞİL: 🇹🇷 gibi emoji bayraklar Windows'ta HİÇ çizilmez
/// (kullanıcı "TR" harf çiftini görür), eski Android sürümlerinde eksiktir ve
/// Flutter web tuvalinde yazı tipine bağımlıdır. Proje kuralı da emoji yerine
/// varlık/ikon kullanmayı söylüyor. Bu yüzden 116 ülke için 80 px genişliğinde
/// PNG varlık gömüldü (toplam ~42 KB): Android, iOS ve web'de aynı çizilir.
///
/// Kaynak: flagcdn.com (kamu malı bayrak görselleri), `assets/bayraklar/`.

/// Ülke adı (ayarlar.dart'taki `ulkeler` listesi) → ISO 3166-1 alfa-2 kodu.
/// İngilizce karşılıklar da eklendi: `ulke` sunucuda serbest metin olarak
/// saklanıyor (60 karakter sınırı dışında doğrulama yok), bu yüzden uygulama
/// dışından gelmiş bir değer de yakalanabilsin.
const Map<String, String> _adKod = {
  // --- Uygulamanın ülke seçicisindeki 116 ad ---
  'Türkiye': 'tr',
  'Almanya': 'de',
  'Amerika Birleşik Devletleri': 'us',
  'Andorra': 'ad',
  'Angola': 'ao',
  'Arjantin': 'ar',
  'Arnavutluk': 'al',
  'Avustralya': 'au',
  'Avusturya': 'at',
  'Azerbaycan': 'az',
  'Bahreyn': 'bh',
  'Bangladeş': 'bd',
  'Belarus': 'by',
  'Belçika': 'be',
  'Birleşik Arap Emirlikleri': 'ae',
  'Birleşik Krallık': 'gb',
  'Bolivya': 'bo',
  'Bosna-Hersek': 'ba',
  'Brezilya': 'br',
  'Bulgaristan': 'bg',
  'Cezayir': 'dz',
  'Çekya': 'cz',
  'Çin': 'cn',
  'Danimarka': 'dk',
  'Endonezya': 'id',
  'Ermenistan': 'am',
  'Estonya': 'ee',
  'Etiyopya': 'et',
  'Fas': 'ma',
  'Filipinler': 'ph',
  'Filistin': 'ps',
  'Finlandiya': 'fi',
  'Fransa': 'fr',
  'Gana': 'gh',
  'Guatemala': 'gt',
  'Güney Afrika': 'za',
  'Güney Kore': 'kr',
  'Gürcistan': 'ge',
  'Hindistan': 'in',
  'Hırvatistan': 'hr',
  'Hollanda': 'nl',
  'Honduras': 'hn',
  'Irak': 'iq',
  'İran': 'ir',
  'İrlanda': 'ie',
  'İspanya': 'es',
  'İsrail': 'il',
  'İsveç': 'se',
  'İsviçre': 'ch',
  'İtalya': 'it',
  'İzlanda': 'is',
  'Jamaika': 'jm',
  'Japonya': 'jp',
  'Kamboçya': 'kh',
  'Kanada': 'ca',
  'Karadağ': 'me',
  'Katar': 'qa',
  'Kazakistan': 'kz',
  'Kenya': 'ke',
  'Kıbrıs': 'cy',
  'Kırgızistan': 'kg',
  'Kolombiya': 'co',
  'Kosova': 'xk',
  'Kosta Rika': 'cr',
  'Küba': 'cu',
  'Kuveyt': 'kw',
  'Letonya': 'lv',
  'Libya': 'ly',
  'Litvanya': 'lt',
  'Lübnan': 'lb',
  'Lüksemburg': 'lu',
  'Macaristan': 'hu',
  'Makedonya': 'mk',
  'Malezya': 'my',
  'Malta': 'mt',
  'Meksika': 'mx',
  'Mısır': 'eg',
  'Moğolistan': 'mn',
  'Moldova': 'md',
  'Monako': 'mc',
  'Nepal': 'np',
  'Nijerya': 'ng',
  'Norveç': 'no',
  'Özbekistan': 'uz',
  'Pakistan': 'pk',
  'Panama': 'pa',
  'Paraguay': 'py',
  'Peru': 'pe',
  'Polonya': 'pl',
  'Portekiz': 'pt',
  'Romanya': 'ro',
  'Rusya': 'ru',
  'Senegal': 'sn',
  'Sırbistan': 'rs',
  'Singapur': 'sg',
  'Slovakya': 'sk',
  'Slovenya': 'si',
  'Somali': 'so',
  'Sri Lanka': 'lk',
  'Sudan': 'sd',
  'Suriye': 'sy',
  'Suudi Arabistan': 'sa',
  'Şili': 'cl',
  'Tayland': 'th',
  'Tayvan': 'tw',
  'Tunus': 'tn',
  'Türkmenistan': 'tm',
  'Ukrayna': 'ua',
  'Umman': 'om',
  'Ürdün': 'jo',
  'Uruguay': 'uy',
  'Venezuela': 've',
  'Vietnam': 'vn',
  'Yemen': 'ye',
  'Yeni Zelanda': 'nz',
  'Yunanistan': 'gr',

  // --- İngilizce/yaygın karşılıklar (aynı 116 ülke) ---
  'Turkey': 'tr',
  'Germany': 'de',
  'United States': 'us',
  'United States of America': 'us',
  'USA': 'us',
  'Argentina': 'ar',
  'Albania': 'al',
  'Australia': 'au',
  'Austria': 'at',
  'Azerbaijan': 'az',
  'Bahrain': 'bh',
  'Bangladesh': 'bd',
  'Belgium': 'be',
  'United Arab Emirates': 'ae',
  'UAE': 'ae',
  'United Kingdom': 'gb',
  'England': 'gb',
  'Great Britain': 'gb',
  'Bolivia': 'bo',
  'Bosnia and Herzegovina': 'ba',
  'Brazil': 'br',
  'Bulgaria': 'bg',
  'Algeria': 'dz',
  'Czechia': 'cz',
  'Czech Republic': 'cz',
  'China': 'cn',
  'Denmark': 'dk',
  'Indonesia': 'id',
  'Armenia': 'am',
  'Estonia': 'ee',
  'Ethiopia': 'et',
  'Morocco': 'ma',
  'Philippines': 'ph',
  'Palestine': 'ps',
  'Finland': 'fi',
  'France': 'fr',
  'Ghana': 'gh',
  'South Africa': 'za',
  'South Korea': 'kr',
  'Korea': 'kr',
  'Georgia': 'ge',
  'India': 'in',
  'Croatia': 'hr',
  'Netherlands': 'nl',
  'Holland': 'nl',
  'Iraq': 'iq',
  'Iran': 'ir',
  'Ireland': 'ie',
  'Spain': 'es',
  'Israel': 'il',
  'Sweden': 'se',
  'Switzerland': 'ch',
  'Italy': 'it',
  'Iceland': 'is',
  'Japan': 'jp',
  'Cambodia': 'kh',
  'Canada': 'ca',
  'Montenegro': 'me',
  'Qatar': 'qa',
  'Kazakhstan': 'kz',
  'Cyprus': 'cy',
  'Kyrgyzstan': 'kg',
  'Colombia': 'co',
  'Kosovo': 'xk',
  'Costa Rica': 'cr',
  'Cuba': 'cu',
  'Kuwait': 'kw',
  'Latvia': 'lv',
  'Lithuania': 'lt',
  'Lebanon': 'lb',
  'Luxembourg': 'lu',
  'Hungary': 'hu',
  'North Macedonia': 'mk',
  'Malaysia': 'my',
  'Mexico': 'mx',
  'Egypt': 'eg',
  'Mongolia': 'mn',
  'Monaco': 'mc',
  'Nigeria': 'ng',
  'Norway': 'no',
  'Uzbekistan': 'uz',
  'Poland': 'pl',
  'Portugal': 'pt',
  'Romania': 'ro',
  'Russia': 'ru',
  'Serbia': 'rs',
  'Singapore': 'sg',
  'Slovakia': 'sk',
  'Slovenia': 'si',
  'Somalia': 'so',
  'Syria': 'sy',
  'Saudi Arabia': 'sa',
  'Chile': 'cl',
  'Thailand': 'th',
  'Taiwan': 'tw',
  'Tunisia': 'tn',
  'Turkmenistan': 'tm',
  'Ukraine': 'ua',
  'Oman': 'om',
  'Jordan': 'jo',
  'New Zealand': 'nz',
  'Greece': 'gr',
};

/// Aksanlı/Türkçe harfleri düz ASCII karşılıklarına indirger.
const Map<String, String> _harfler = {
  'ı': 'i',
  'ş': 's',
  'ğ': 'g',
  'ü': 'u',
  'ö': 'o',
  'ç': 'c',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'à': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'î': 'i',
  'í': 'i',
  'ï': 'i',
  'ó': 'o',
  'ô': 'o',
  'ø': 'o',
  'û': 'u',
  'ú': 'u',
  'ñ': 'n',
  'ß': 'ss',
  'æ': 'ae',
};

/// Karşılaştırma anahtarı: küçük harf, aksansız, boşluk/noktalama atılmış.
/// "Bosna-Hersek", "bosna hersek" ve "BOSNAHERSEK" aynı anahtara iner.
String _sadelestir(String ad) {
  final kucuk = ad.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final b = StringBuffer();
  for (final kod in kucuk.runes) {
    final harf = String.fromCharCode(kod);
    final duz = _harfler[harf];
    if (duz != null) {
      b.write(duz);
    } else if ((kod >= 0x61 && kod <= 0x7A) || (kod >= 0x30 && kod <= 0x39)) {
      b.write(harf);
    }
    // Boşluk, tire, nokta vb. tamamen atılır.
  }
  return b.toString();
}

Map<String, String>? _indeks;

Map<String, String> get _dizin =>
    _indeks ??= {for (final g in _adKod.entries) _sadelestir(g.key): g.value};

/// Pakette bulunması gereken bütün bayrak kodları (doğrulama/test için).
Set<String> get tumKodlar => _adKod.values.toSet();

/// Ülke adından ISO alfa-2 bayrak kodu. Eşleşme yoksa null.
///
/// Ad çözülmezse doğrudan iki harfli kod da kabul edilir ("TR", "de"), çünkü
/// alan serbest metin ve ileride kod saklanmaya başlarsa satır bozulmasın.
String? ulkeKodu(String? ad) {
  if (ad == null) return null;
  final anahtar = _sadelestir(ad);
  if (anahtar.isEmpty) return null;
  final kod = _dizin[anahtar];
  if (kod != null) return kod;
  if (anahtar.length == 2 && _adKod.containsValue(anahtar)) return anahtar;
  return null;
}

/// Profil ülke satırındaki bayrak. Konum iğnesinin (Icons.location_on) yerini
/// alır. Bayrak bulunamazsa satır BOZULMAZ: yerine dünya ikonu çizilir, ülke
/// metni yanında olduğu gibi kalır.
class UlkeBayragi extends StatelessWidget {
  const UlkeBayragi({super.key, required this.ulke, this.yukseklik = 12});

  /// Profildeki ham `ulke` değeri.
  final String? ulke;

  /// Bayrak yüksekliği; genişlik bayrağın kendi en-boy oranından gelir
  /// (Nepal ve İsviçre dikdörtgen değil — esnetme yok).
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final kod = ulkeKodu(ulke);
    if (kod == null) return _yedek();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        // Beyaz ağırlıklı bayraklar (Japonya) açık temada kaybolmasın.
        border: Border.all(color: DiziRenkler.metin24, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Image.asset(
          'assets/bayraklar/$kod.png',
          height: yukseklik,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          // Ülke adı hemen yanında yazıyor; ekran okuyucu iki kez okumasın.
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => _yedek(),
        ),
      ),
    );
  }

  Widget _yedek() =>
      Icon(Icons.public, size: yukseklik + 2, color: DiziRenkler.sariMetin);
}

/// Profil başlığındaki "bayrak + ülke adı" ikilisi.
///
/// Kendi profilim (profil.dart) ve başkasının profili (kullanici_profil.dart)
/// aynı satırı çizdiği için tek yerde durur: biri değişip diğeri unutulmasın.
/// `mainAxisSize.min` + `Flexible`: kısa adlarda kendi genişliğinde kalır, uzun
/// adlarda ("Amerika Birleşik Devletleri") verilen genişliği aşmadan üç noktayla
/// kısalır — yanına başka bir şey (aile rozeti) konsa da satır TAŞMAZ.
class UlkeSatiri extends StatelessWidget {
  const UlkeSatiri({super.key, required this.ulke});

  final String ulke;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UlkeBayragi(ulke: ulke),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            ulke,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: DiziRenkler.metin54, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

import 'dil_en.dart';
import 'dil_zh.dart';
import 'dil_hi.dart';
import 'dil_es.dart';
import 'dil_fr.dart';
import 'dil_ar.dart';
import 'dil_bn.dart';
import 'dil_pt.dart';
import 'dil_ru.dart';
import 'dil_ur.dart';
import 'dil_id.dart';
import 'dil_de.dart';
import 'dil_ja.dart';
import 'dil_sw.dart';
import 'dil_mr.dart';
import 'dil_te.dart';
import 'dil_vi.dart';
import 'dil_ko.dart';
import 'dil_ta.dart';
import 'dil_it.dart';
import 'dil_fa.dart';
import 'dil_pl.dart';
import 'dil_uk.dart';
import 'dil_ro.dart';
import 'dil_nl.dart';
import 'dil_th.dart';
import 'dil_gu.dart';
import 'dil_kn.dart';
import 'dil_ml.dart';
import 'dil_pa.dart';
import 'dil_ms.dart';
import 'dil_my.dart';
import 'dil_am.dart';
import 'dil_az.dart';
import 'dil_el.dart';
import 'dil_hu.dart';
import 'dil_cs.dart';
import 'dil_sv.dart';
import 'dil_he.dart';
import 'dil_fil.dart';
import 'dil_sr.dart';
import 'dil_bg.dart';
import 'dil_da.dart';
import 'dil_fi.dart';
import 'dil_nb.dart';

/// Dil kodu → çeviri haritası. 'tr' anahtarların kendisidir, haritası yoktur.
const Map<String, Map<String, String>> tumCeviriler = {
  'en': cevirilerEn,
  'zh': cevirilerZh,
  'hi': cevirilerHi,
  'es': cevirilerEs,
  'fr': cevirilerFr,
  'ar': cevirilerAr,
  'bn': cevirilerBn,
  'pt': cevirilerPt,
  'ru': cevirilerRu,
  'ur': cevirilerUr,
  'id': cevirilerId,
  'de': cevirilerDe,
  'ja': cevirilerJa,
  'sw': cevirilerSw,
  'mr': cevirilerMr,
  'te': cevirilerTe,
  'vi': cevirilerVi,
  'ko': cevirilerKo,
  'ta': cevirilerTa,
  'it': cevirilerIt,
  'fa': cevirilerFa,
  'pl': cevirilerPl,
  'uk': cevirilerUk,
  'ro': cevirilerRo,
  'nl': cevirilerNl,
  'th': cevirilerTh,
  'gu': cevirilerGu,
  'kn': cevirilerKn,
  'ml': cevirilerMl,
  'pa': cevirilerPa,
  'ms': cevirilerMs,
  'my': cevirilerMy,
  'am': cevirilerAm,
  'az': cevirilerAz,
  'el': cevirilerEl,
  'hu': cevirilerHu,
  'cs': cevirilerCs,
  'sv': cevirilerSv,
  'he': cevirilerHe,
  'fil': cevirilerFil,
  'sr': cevirilerSr,
  'bg': cevirilerBg,
  'da': cevirilerDa,
  'fi': cevirilerFi,
  'nb': cevirilerNb,
};

/// YALNIZ GERÇEK KULLANICI DİLLERİNE çevrilen anahtarlar.
///
/// KULLANICI KARARI (2 Eyl 2026, sürüm duyurusu işi): "45 dile çevirmene
/// gerek yok, kaç dilde kullanıcımız varsa ona çevir." Ölçüm (cihaz_tokenlari
/// dil dağılımı, 2 Eyl): tr 234 · en 18 · ru 2 · ar 2 · es 1 · zh 1 · ro 1.
/// Bu kümedeki anahtarlar SADECE en/ru/ar/es/zh/ro haritalarında bulunur;
/// diğer 39 dil Türkçe kaynağa düşer (o dillerde bugün kullanıcı yok, yeni
/// bir dilde kullanıcı belirirse anahtarlar o dile de eklenir).
///
/// 45/45 eşitlik testleri (`ceviri_bosluklari_test`,
/// `arama_ceviri_gizlilik_test`) bu kümeyi karşılaştırma DIŞI tutar — küme
/// buradan okunur ki kod ile test aynı listeye baksın.
const Set<String> sinirliDilAnahtarlari = {
  'dizi.jpg {} yayında',
  'Yenilikler',
  'Bu sürümde neler değişti, aşağıda.',
  'Bildirimler yenilendi',
  'Beğeniler artık gönderi başına tek satırda toplanıyor, satırın sağında gönderinin küçük görseli duruyor ve liste arka planla tek parça görünüyor.',
  'Sarı rozet her yerde',
  'Rozetli kullanıcıların adının yanında artık bildirimlerde, gönderilerde ve beğenenler listesinde sarı onay rozeti görünüyor.',
  'Reels yorumları yarım ekranda',
  'Reels izlerken yorumlar ve yazının devamı ekranın yarısından biraz fazlasını kaplayan bir pencerede açılıyor; video üstte oynamaya devam ediyor.',
  'Tek renkli ilerleme çubuğu',
  'Liste görünümündeki izleme çubuğu artık tek renk: az izlediysen kırmızı, ortalarındaysan sarı, sona yaklaştıysan yeşil.',
  'Sohbet düzeltmeleri',
  'Mesaj yazma kutusu ile istek düğmeleri artık telefonun gezinme tuşlarının altında kalmıyor; sohbete girince alt menü kendiliğinden gizleniyor.',
  'Bu sürümün notlarını görmek için uygulamayı güncelle',
  'Hesabını gizleyebilirsin',
  'Profilini gizliye aldığında gönderilerini yalnız onayladığın takipçiler görür. Yeni takipler bildirimlerine istek olarak düşer; Onayla ya da Sil ile karar verirsin.',
  'IMDb, Rotten Tomatoes ve Metacritic puanları',
  'Film ve dizi sayfalarında dış puanlar da görünüyor; hangi kaynağın ne verdiğini tek bakışta karşılaştırırsın.',
  'Reels\'te iki kat hız',
  'Reels izlerken ekranın sağ yarısını basılı tut, video iki kat hızlı oynasın; parmağını çekince normal hıza döner.',
  'Yönetmen ve senarist kredileri',
  'Kişi sayfasında oyunculuğun yanında, o kişinin yönetmenlik ve senaristlik yaptığı yapımlar da listeleniyor.',
  'Videoda geri sarma düzeldi',
  'Videoyu geri sardığında baştan yüklenmiyor; oynatma kaldığın yerden anında devam ediyor.',
  'Bu sürümde görünür bir yenilik yok; arka planda iyileştirmeler ve düzeltmeler var.',
  'Bildirimler ekranın üstünde beliriyor',
  'Uygulamayı kullanırken gelen beğeni, yorum ve mesajlar artık üstten kayan küçük bir pencerede görünüyor. Dokununca ilgili yere gidiyor, yukarı sürükleyince kapanıyor.',
  'Ondalıklı puan verebilirsin',
  'Yıldızların üzerinde parmağını sürükle: artık 4 ya da 5 değil, aradaki 4,6 gibi puanları da verebiliyorsun.',
  'Yanıtın yanıtı girintili görünüyor',
  'Bir yanıta yazdığın yanıt artık onun altında girintili duruyor; hangi cümlenin kime yazıldığı tek bakışta anlaşılıyor.',
  'Sohbette gerçek yükleme yüzdesi',
  'Fotoğraf ya da video gönderirken yüzde gerçekten ilerliyor; yükleme sürerken yeni mesaj da yazabiliyorsun.',
  'İzleme odası tek satırda',
  'Odadaki oynat, sar ve ses düğmeleri tek satıra indi. Yayın takılırsa nöbetçi bunu fark edip kendiliğinden toparlıyor.',
  'İçe aktarım için ZIP şart değil',
  'Başka bir uygulamadan liste aktarırken tek bir CSV ya da JSON dosyası da yeterli; arşivi açıp hazırlamana gerek yok.',
};

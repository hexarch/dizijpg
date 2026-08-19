// ---------------------------------------------------------------------------
// Dizi durum otomatiği — SAF MANTIK (DB yok, ağ yok, express yok, saat yok).
//
// Neden ayrı dosya: hem `/izleme/toggle` ve `/izleme/sezon` uçları, hem 12
// saatlik tarama (`durumlariTara`), hem de geriye dönük düzeltme betiği
// (`araclar/durum_duzelt.js`) AYNI kararı vermek zorunda. Üç yerde üç kopya
// mantık olursa betiğin ürettiği durum ile ucun ürettiği durum ayrışır.
// Saf olduğu için `node --test` ile sınanır (test/dizi_durum.test.js).
//
// KULLANICI KURALI (4 Ağu 2026):
//   "Bitirdiğim diziler izliyorumda kalıyor. Tüm bölümleri izlediysem
//    bitirdiğime alacaksın; 3. sezonu geldiğinde veya geleceği kesin
//    olduğunda geri izliyoruma çekeceksin."
//
// KARARLAR (gerekçeleriyle):
//
//  1) "Yayınlanmış bölüm" = bugüne kadar YAYINA GİRMİŞ bölüm. Ölçüt tek bir
//     `/tv/{id}` çağrısından çıkar (sezon sezon bölüm listesi çekmek 20+ istek
//     demek olurdu, bu proje bu yüzden `/takvim`de 15 sn yiyor):
//       - `last_episode_to_air` yayının nerede durduğunu söyler; ondan
//         SONRAKİ sezonlar ve o sezondaki sonraki bölümler sayılmaz.
//       - Yayın tarihi GELECEK olan sezon hiç başlamamıştır, sayılmaz.
//     Böylece "bugünden sonraki tarihli bölüm" hiçbir koşulda toplama girmez.
//
//  2) ÖZEL BÖLÜMLER (sezon 0) SAYILMAZ. Gerekçe: TMDB'de özel sezon çoğu dizide
//     tanıtım/kamera arkası/derleme yığınıdır ve hiçbir platformda izlenemez.
//     Şart koşulursa "bitirdim" pratikte ERİŞİLEMEZ olur — kullanıcı diziyi
//     bitirdiği halde sonsuza dek izliyorumda kalır ki bu tam da şikâyet edilen
//     hatanın ta kendisidir. İzlenmiş özel bölüm ceza da değildir: yalnız
//     "eksik bölüm" hesabının dışında tutulur.
//
//  3) ELLE SEÇİM EZİLMEZ: "biraktim" bilinçli bir karardır. Bir diziyi bırakan
//     kullanıcı eski bölümlerini işaretlemeye devam edebilir; otomatik olarak
//     "bitirdim"e ya da "izliyorum"a çekmek onun kararını siler. Bu yüzden
//     "biraktim" MUTLAK duraktır: otomatik hiçbir geçiş ondan çıkamaz.
//     İzinli otomatik geçişler yalnızca şunlardır:
//         (durumsuz | izleyecegim | izliyorum | bitirdim) → izliyorum | bitirdim
//
//  4) GERİ ÇEKME "KESİN" OLMALI: yeni sezon sinyali ya `next_episode_to_air`in
//     TARİHİ ya da henüz başlamamış bir sezonun AÇIKLANMIŞ tarihidir. Tarihi
//     `null` olan sezon (TMDB'de yıllarca boş duran "Season 5" kabuğu) kesin
//     SAYILMAZ — sayılsaydı beklemedeki her dizi sonsuza dek izliyorumda
//     kalırdı, yani düzeltmeye çalıştığımız hatanın aynısı geri gelirdi.
//
//  5) TAMAMLANMA SAYIYLA DEĞİL KÜMEYLE ölçülür: "izlenen adet >= yayınlanan
//     adet" yanıltıcıdır. Canlı örnek (alcelik, Chernobyl): izlemeler {0,1,2,4,5}
//     — 5 kayıt var, yayınlanan da 5 bölüm, ama 3. bölüm İZLENMEMİŞ ve sahte bir
//     "bölüm 0" kaydı sayıyı dolduruyordu. Eski sayım mantığı buna "bitirdim"
//     diyordu. Küme karşılaştırması eksik bölümü görür.
//
//  6) VERİ UYUŞMAZLIĞI KORUMASI (karar 5'in kaçınılmaz yan etkisi): TMDB kaydı
//     kullanıcının kaydıyla hiç örtüşmüyorsa küme karşılaştırması "eksik" der ve
//     doğru durumu BOZAR. Canlı örnek (alcelik, TMDB 283317 "Muhteşem Yüzyıl"):
//     TMDB'de tek bir "Sezon 310 / 1 bölüm" var, kullanıcıda 1-4. sezonların 139
//     bölümü. Ortak sezon YOKSA veri güvenilmezdir: durum DEĞİŞTİRİLMEZ.
// ---------------------------------------------------------------------------

/// Otomatiğin ASLA değiştirmeyeceği durumlar (karar 3).
export const DOKUNULMAZ_DURUMLAR = ['biraktim'];

/// Tek sezonda dikkate alınacak azami bölüm sayısı.
///
/// TAVAN NEDEN VAR: `episode_count` TMDB'de topluluk düzenlemesine açık bir
/// alandır; bozuk tek bir kayıt (ör. 99999) buradan yüz binlerce elemanlı bir
/// diziye, oradan da tek seferde o kadar satırlık bir INSERT'e dönüşür.
/// Tavan, veri hatasının maliyetini sabitler.
///
/// NEDEN ARTIK 500 DEĞİL: 500 gerçek dizileri kesiyordu. TMDB tek sezona
/// yığılmış uzun soluklu yapımlar barındırır (Doraemon 1979 ve benzeri günlük
/// animeler tek sezonda 1700+ bölüm). Böyle bir dizide "bitirdim" işaretlemesi
/// 500. bölümde susuyordu: kullanıcı 501+ bölümleri izlenmemiş görüyor ama
/// nedenini gösteren hiçbir iz yoktu — arayüz de günlük de sessizdi.
/// 3000, bilinen en uzun TMDB sezonunun belirgin üstünde; hâlâ tek sorguya
/// sığan bir büyüklük.
export const SEZON_BOLUM_TAVANI = 3000;

/// Bir kaydın anahtarı: "sezon:bolum".
const anahtar = (s, b) => `${s}:${b}`;

/// `[[sezon,bolum], ...]` ya da `{sezon,bolum}` listesini Set'e çevirir.
function izlenenKume(izlenen) {
  const k = new Set();
  for (const it of izlenen || []) {
    const s = Array.isArray(it) ? it[0] : it.sezon;
    const b = Array.isArray(it) ? it[1] : it.bolum;
    if (Number.isInteger(s) && Number.isInteger(b)) k.add(anahtar(s, b));
  }
  return k;
}

/// TMDB `/tv/{id}` gövdesinden YAYINLANMIŞ bölüm çiftleri: `[[sezon,bolum],...]`.
/// `bugunIso` = "YYYY-MM-DD". TMDB tarihleri de bu biçimde geldiği için
/// karşılaştırma metin üzerinden yapılır: saat dilimi kayması olmaz.
export function yayinlanmisBolumler(dizi, bugunIso) {
  const son = dizi?.last_episode_to_air;
  const ciftler = [];
  for (const s of dizi?.seasons || []) {
    const no = s?.season_number;
    if (!Number.isInteger(no) || no < 1) continue; // özel sezon (karar 2)
    // Yayın tarihi gelecekte olan sezon hiç başlamamıştır (karar 1).
    if (s.air_date && bugunIso && s.air_date > bugunIso) continue;
    let adet = Number.isInteger(s.episode_count) ? s.episode_count : 0;
    if (son && Number.isInteger(son.season_number)) {
      if (no > son.season_number) continue;
      if (no === son.season_number) {
        adet = Math.min(adet, son.episode_number || adet);
      }
    }
    // Tavan aşılırsa KESİLİR AMA SESSİZ KALINMAZ: kesilen bölümler
    // "bitirdim"de eksik kalıyor ve kullanıcı bunu ancak listeyi tek tek
    // sayarak fark edebilir. Günlüğe düşen satır, şikâyet geldiğinde aranacak
    // ilk yer olsun diye var.
    const sinirli = Math.min(adet, SEZON_BOLUM_TAVANI);
    if (adet > SEZON_BOLUM_TAVANI) {
      console.warn(
        `[dizi_durum] SEZON BÖLÜM TAVANI AŞILDI: tmdb=${dizi?.id ?? '?'} `
        + `"${dizi?.name ?? '?'}" sezon ${no} → ${adet} bölüm, `
        + `${SEZON_BOLUM_TAVANI} tanesi işlendi. Kalan ${adet - SEZON_BOLUM_TAVANI} `
        + 'bölüm "bitirdim" işaretlemesinde EKSİK kalır.',
      );
    }
    for (let b = 1; b <= sinirli; b++) ciftler.push([no, b]);
  }
  return ciftler;
}

/// Yeni bölüm/sezon geleceği KESİN mi? (karar 4)
export function yeniSezonBekleniyorMu(dizi, bugunIso) {
  // TMDB sıradaki bölümün tarihini biliyorsa yayın kesindir.
  const sonraki = dizi?.next_episode_to_air;
  if (sonraki?.air_date && (!bugunIso || sonraki.air_date >= bugunIso)) {
    return true;
  }
  // Tarihi açıklanmış ama henüz başlamamış sezon da kesindir.
  for (const s of dizi?.seasons || []) {
    const no = s?.season_number;
    if (!Number.isInteger(no) || no < 1) continue;
    if (s.air_date && bugunIso && s.air_date > bugunIso) return true;
  }
  return false;
}

/// Kullanıcının bu dizideki hedef durumu.
/// Dönüş: 'bitirdim' | 'izliyorum' | null (null = DEĞİŞİKLİK YOK).
///
/// - `dizi`        : TMDB `/tv/{id}` gövdesi
/// - `izlenen`     : izlenmiş `[[sezon,bolum],...]` (sezon 0 zararsız, sayılmaz)
/// - `mevcutDurum` : `durumlar` tablosundaki değer ya da null
/// - `bugunIso`    : "YYYY-MM-DD"
export function hedefDurum({ dizi, izlenen, mevcutDurum = null, bugunIso }) {
  // Elle bırakılan diziye otomatik dokunulmaz (karar 3).
  if (DOKUNULMAZ_DURUMLAR.includes(mevcutDurum)) return null;

  const kume = izlenenKume(izlenen);
  // Sezon 0 dışında hiç bölüm işaretlenmemişse ortada "izleme" yok: otomatik
  // durum UYDURMAZ (kullanıcı yalnız özel bölüm işaretlemiş olabilir).
  const izlenenSezonlar = new Set();
  for (const k of kume) {
    const s = Number(k.slice(0, k.indexOf(':')));
    if (s >= 1) izlenenSezonlar.add(s);
  }
  if (izlenenSezonlar.size === 0) return null;

  const yayinlanmis = yayinlanmisBolumler(dizi, bugunIso);
  // VERİ UYUŞMAZLIĞI (karar 6): ortak sezon yoksa TMDB kaydı bu kullanıcının
  // izlemeleriyle ilgisizdir; hiçbir yönde karar verilmez.
  if (yayinlanmis.length > 0
      && !yayinlanmis.some(([s]) => izlenenSezonlar.has(s))) {
    return null;
  }

  const tamamlandi = yayinlanmis.length > 0
    && yayinlanmis.every(([s, b]) => kume.has(anahtar(s, b)));
  const bekleyen = yeniSezonBekleniyorMu(dizi, bugunIso);

  const hedef = tamamlandi && !bekleyen ? 'bitirdim' : 'izliyorum';
  return hedef === mevcutDurum ? null : hedef;
}

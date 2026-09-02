// ---------------------------------------------------------------------------
// Akış / Keşfet sıralama motoru — SAF MANTIK (DB yok, express yok, zaman yok).
//
// Neden ayrı dosya: hem `/akis` ve `/kesfet-akis` uçları hem de admin
// önizlemesi (`/admin/algoritma-onizleme`) AYNI fonksiyonu çağırır. Panelde
// gördüğün sıra ile kullanıcının gördüğü sıra aynı koddan çıkmazsa önizleme
// yalan söyler. Ayrıca saf olduğu için `node --test` ile birim testi yazılır
// (backend/test/siralama.test.js).
//
// FORMÜL (ALGORITMA-PLANI.md §4.1):
//     Skor = [ Σ aᵢ·nᵢ ] × T(yaş) × Π cⱼ
//            └ ilgi (0-1) ┘  └taze ┘  └ceza┘
// Ağırlıklar 0-100 girilir, motor 100'e normalize eder. Sert filtreler
// (engelleme, yasaklı, bölüm uygunluğu, görülmüş) BURAYA GİRMEZ — onlar SQL
// WHERE'de kalır (plan §7.3): engelleme bir tercih değil, sınırdır.
// ---------------------------------------------------------------------------

// Sayım tipi sinyaller: P95'i hacim eşiğinin altındaysa OTOMATİK susarlar
// (plan §4.3). Boolean ve merdiven sinyalleri bu kurala girmez — onların
// varyansı sayıdan değil, kullanıcının kendi verisinden gelir.
export const SAYIM_SINYALLERI = ['begeni', 'yanit', 'takip_begendi', 'icerik_pop'];

// Panelde slider'ı olan bütün ilgi ağırlıkları (sıra = paneldeki sıra).
export const AGIRLIK_ANAHTARLARI = [
  'kitaplik', 'takip_ettigim', 'icerik_pop', 'medya',
  'yazar_kalite', 'dil', 'begeni', 'yanit', 'takip_begendi',
];

// Ağırlık dışı alanlar: çarpanlar, kotalar, yarı ömür. "Toplamı 100" kuralına
// DAHİL DEĞİL — aksi halde bir cezayı açmak bir ilgi sinyalini kısardı.
export const SAYI_ALANLARI = {
  yari_omur_saat: { alt: 1, ust: 8760 },
  tazelik_gucu: { alt: 0, ust: 100 }, // % — 0: zaman hiç önemsiz, 100: tam çürüme
  yazar_doygunluk: { alt: 0.1, ust: 1 },
  icerik_doygunluk: { alt: 0.1, ust: 1 },
  spoiler_ceza: { alt: 0.1, ust: 1 },
  ai_payi: { alt: 0, ust: 100 }, // % — AI hesabının listedeki azami payı
  arsiv_payi: { alt: 0, ust: 100 }, // % — arşiv gönderilerinin azami payı
  // TAVANLARIN SİMETRİĞİ: seçilen kartlarda videolu gönderinin ASGARİ payı.
  // Üst sınır 50 — yarıdan fazlası zorla video olan bir akış artık Keşfet'tir.
  video_tabani: { alt: 0, ust: 50 }, // % — 0: kapalı (bugünkü davranış)
  hacim_esigi: { alt: 0, ust: 1000 },
  // KİTAPLIK ÖNCELİĞİ (3 Eyl 2026, kullanıcı): "akışta öncelik izlediğim
  // yapımlar olmalı; TWD izlediysem TWD gönderileri gelmeli, kitaplığımı
  // doldurmama rağmen hâlâ Breaking Bad önerisi geliyor." Ölçüldü (canlı,
  // kullanıcı 481: kitaplığı TWD + Squid Game + Peaky Blinders + Titanic):
  // ilk 3 kart kitaplık DIŞI taze gönderiydi (tazelik 0,98 × ilgi 0,22),
  // TWD gönderileri 4., 10. ve 24. sıradaydı (tazelik 0,15 × ilgi 0,6).
  // Kitaplık ağırlığı %100'e çekilmişken bile tazelik çürümesi (36 sa yarı
  // ömür, taban %15) kitaplığı eziyordu; ağırlık kolu bunu ÇÖZEMEZ çünkü
  // ilgi ≤ 1 iken taze/eski çarpanı 6,5×. Bu kol skora KADEME ekler: kitaplık
  // eşleşmesi olan gönderi, tazeliği ne olursa olsun eşleşmeyenlerin ÜSTÜNE
  // çıkar (bkz. `skorla`). %0: kapalı (dünkü davranış). Keşfet'te kapalı:
  // Reels "ne varmış" yüzeyi, kitaplığa kilitlenmemeli.
  kitaplik_oncelik: { alt: 0, ust: 100 },
};

// Arşiv sayılma sınırı: bundan eski gönderi "arşiv" kotasına girer.
// Ölçüm (plan §2.5): 2017-2021 arası 2.184 gönderi (%45,1) Instagram aktarımı.
export const ARSIV_YAS_SAAT = 2 * 365 * 24;

// Merdiven değerleri kodda sabit, AĞIRLIKLARI panelde ayarlanır (plan §4.2c) —
// aksi halde panel 30 alanlık bir tabloya dönerdi.
export const MEDYA_MERDIVEN = { 0: 1, 1: 0.55, 2: 0.3 }; // 0 video, 1 foto, 2 yazı
export const DURUM_MERDIVEN = {
  izliyorum: 1, bitirdim: 0.7, izleyecegim: 0.5, biraktim: 0,
};

export const VARSAYILAN_AKIS = Object.freeze({
  kitaplik: 35, takip_ettigim: 30, icerik_pop: 15, medya: 0,
  yazar_kalite: 10, dil: 10, begeni: 0, yanit: 0, takip_begendi: 0,
  yari_omur_saat: 36, tazelik_gucu: 85,
  yazar_doygunluk: 0.7, icerik_doygunluk: 0.8, spoiler_ceza: 0.85,
  // video_tabani %10: her 10 kartta en az 1 video. Ölçüm (26 Ağu 2026):
  // medya ağırlığı 0 + 36 saatlik yarı ömür, arşiv videolarını (460'ın %91,5'i
  // 2017-2021 Instagram aktarımı) hiçbir sayfada sıraya sokmuyordu.
  ai_payi: 50, arsiv_payi: 45, video_tabani: 10, hacim_esigi: 3,
  kitaplik_oncelik: 100,
});

// Keşfet ayrı set (plan §4.4): sosyal graf 20 kenarla Keşfet'i besleyemez,
// medya türü orada belirleyici, yarı ömür uzun ("ne varmış" yüzeyi).
// yazar_doygunluk daha sert: videoların %91,5'i tek hesapta.
export const VARSAYILAN_KESFET = Object.freeze({
  kitaplik: 30, takip_ettigim: 5, icerik_pop: 30, medya: 25,
  yazar_kalite: 10, dil: 0, begeni: 0, yanit: 0, takip_begendi: 0,
  yari_omur_saat: 168, tazelik_gucu: 85,
  yazar_doygunluk: 0.5, icerik_doygunluk: 0.8, spoiler_ceza: 0.85,
  ai_payi: 50, arsiv_payi: 45, video_tabani: 0, hacim_esigi: 3,
  kitaplik_oncelik: 0,
});

export const varsayilan = (yuzey) => (yuzey === 'kesfet' ? VARSAYILAN_KESFET : VARSAYILAN_AKIS);

const kis = (x, alt, ust) => Math.min(ust, Math.max(alt, x));

/** Ham (panelden/DB'den gelen) ayarı doğrula, eksikleri varsayılanla doldur.
 *  Bilinmeyen anahtar YOK SAYILIR, bozuk sayı varsayılana düşer (plan §5.4). */
export function ayarBirlestir(ham, yuzey) {
  const v = varsayilan(yuzey);
  const cikti = { ...v };
  const kaynak = (ham && typeof ham === 'object') ? ham : {};
  for (const a of AGIRLIK_ANAHTARLARI) {
    const s = Number(kaynak[a]);
    if (Number.isFinite(s)) cikti[a] = kis(Math.round(s), 0, 100);
  }
  for (const [a, sinir] of Object.entries(SAYI_ALANLARI)) {
    const s = Number(kaynak[a]);
    if (Number.isFinite(s)) cikti[a] = kis(s, sinir.alt, sinir.ust);
  }
  // Emniyet: tüm ağırlıklar sıfırsa sıralama tamamen tazeliğe iner ve akış
  // kronolojiye çöker. Çalışma anında varsayılan sete DÜŞÜLÜR (plan §5.4).
  if (AGIRLIK_ANAHTARLARI.every((a) => cikti[a] === 0)) {
    for (const a of AGIRLIK_ANAHTARLARI) cikti[a] = v[a];
  }
  return cikti;
}

/** Hacim eşiği (plan §4.3): P95'i eşiğin altında kalan SAYIM sinyalinin
 *  ağırlığı 0 sayılır, kalanlar oranlarını koruyarak 100'e yeniden ölçeklenir.
 *  Döner: { agirlik: {..0-1 arası pay..}, susan: ['begeni', ...] } */
export function hacimUygula(ayar, olcum) {
  const esik = Number.isFinite(ayar.hacim_esigi) ? ayar.hacim_esigi : 3;
  const p95 = (olcum && olcum.p95) || {};
  const susan = [];
  const etkin = {};
  for (const a of AGIRLIK_ANAHTARLARI) {
    let w = ayar[a] || 0;
    if (SAYIM_SINYALLERI.includes(a)) {
      const d = Number(p95[a]);
      // Ölçüm yoksa (P95 bilinmiyor) sinyali SUSTURMA — ölçüm gelene kadar
      // çalışsın; susturmak "veri yok" ile "veri sıfır"ı karıştırırdı.
      // Ağırlık zaten 0 olsa bile susan listesine girer: panel rozeti
      // "bu slider'ı yükseltmek bugün işe yaramaz" demek zorunda.
      if (Number.isFinite(d) && d < esik) { susan.push(a); w = 0; }
    }
    etkin[a] = w;
  }
  const toplam = Object.values(etkin).reduce((t, x) => t + x, 0);
  const pay = {};
  for (const a of AGIRLIK_ANAHTARLARI) {
    pay[a] = toplam > 0 ? etkin[a] / toplam : 0;
  }
  return { pay, susan, toplam };
}

/** Tazelik çarpanı. tazelik_gucu %0 → zaman hiç etkilemez (taban 1),
 *  %100 → saf üstel yarı ömür (taban 0). Arşiv tuzağı (plan §2.5) bu
 *  tabanla çözülür: eski içerik sıfırlanmaz, yalnız geri düşer. */
export function tazelik(yasSaat, ayar) {
  const taban = 1 - kis(ayar.tazelik_gucu, 0, 100) / 100;
  const yariOmur = Math.max(1, ayar.yari_omur_saat || 1);
  const yas = Math.max(0, yasSaat || 0);
  return Math.max(taban, Math.pow(0.5, yas / yariOmur));
}

/** Sayım sinyali normalizasyonu: log + P95 kırpma (plan §4.2a).
 *  P95 < 1 ise bölme tanımsız → 0 döner (sinyal zaten hacim eşiğinde susar). */
export function logNorm(x, p95) {
  const d = Number(p95);
  if (!Number.isFinite(d) || d < 1) return 0;
  const v = Math.max(0, Number(x) || 0);
  return Math.min(1, Math.log(1 + v) / Math.log(1 + d));
}

/** Tek gönderinin ilgi/tazelik/ceza kırılımı. Doygunluk cezaları BURADA YOK —
 *  onlar ardışıktır, `siralaVeKotala` içinde uygulanır. */
export function skorla(g, ayar, olcum, hacim, sinyalGerek = true) {
  const h = hacim || hacimUygula(ayar, olcum);
  const p95 = (olcum && olcum.p95) || {};
  const n = {
    // Kullanıcının kendi verisi — manipüle edilemez, bedava (`guvenli` zaten
    // AKIS_GOVDE'de hesaplanıyor). Kitaplıkta olan yapım 1; durum kaydı varsa
    // merdivenle inceltilir (izliyorum > bitirdim > izleyeceğim).
    kitaplik: g.guvenli
      ? Math.max(0.6, DURUM_MERDIVEN[g.durum] ?? 0.6)
      : (DURUM_MERDIVEN[g.durum] ?? 0),
    takip_ettigim: g.takip_ediyorum ? 1 : 0,
    icerik_pop: logNorm(g.populerlik, p95.icerik_pop),
    medya: MEDYA_MERDIVEN[g.kat] ?? 0,
    // Yazar kalitesi: gönderi başına beğeni. Oran olduğu için hacim eşiğine
    // girmez; 1,0 beğeni/gönderi tavan sayılır (ölçüm: 0,018 – 1,25).
    yazar_kalite: Math.min(1, Math.max(0, Number(g.yazar_kalite) || 0)),
    dil: g.dil_uygun ? 1 : 0,
    begeni: logNorm(g.begeni, p95.begeni),
    yanit: logNorm(g.yanit, p95.yanit),
    takip_begendi: logNorm(g.takip_begendi, p95.takip_begendi),
  };
  let ilgi = 0;
  for (const a of AGIRLIK_ANAHTARLARI) ilgi += h.pay[a] * n[a];

  const t = tazelik(g.yas_saat, ayar);
  // Spoiler PERDESİ ayrı bir şeydir (yanıt alanı, istemci bulanıklaştırır);
  // bu yalnız sıralama cezası. İşaretli VE kitaplıkta değilse geri düşer.
  const cezaSpoiler = (g.spoiler_isaret && !g.guvenli) ? ayar.spoiler_ceza : 1;
  // KİTAPLIK KADEMESİ (gerekçe SAYI_ALANLARI.kitaplik_oncelik'te). Toplama
  // olarak eklenir, çarpan olarak DEĞİL: çarpan tazelik tabanıyla (0,15)
  // çarpılıp yine taze yabancı gönderinin altında kalırdı. Katsayı 2 şart:
  // ilgi × tazelik en fazla 1; en zayıf eşleşme (izleyeceğim, 0,5) bile
  // %100 öncelikte +1 alır ve kitaplık dışı HER gönderiyi geçer. Merdiven
  // korunur: izliyorum (+2) > bitirdim (+1,4) > izleyeceğim (+1) — kademe
  // içinde sıra yine ilgi × tazelik. Doygunluk cezası (siralaVeKotala) bu
  // skoru da çarpar: aynı dizinin 5. kartından sonra yabancı kart araya
  // girebilir — akış tek diziye kilitlenmez.
  const oncelik = kis(Number(ayar.kitaplik_oncelik) || 0, 0, 100) / 100;
  const kademe = 2 * oncelik * n.kitaplik;
  return {
    id: g.id,
    skor: ilgi * t * cezaSpoiler + kademe,
    ilgi,
    tazelik: t,
    ceza_spoiler: cezaSpoiler,
    // Kırılım yalnız admin önizlemesinde gerekiyor. Kullanıcı yolunda 4.840
    // adayın her biri için 9 alanlı bir nesne daha ayırmak ölçüldü: Keşfet'te
    // skorlama 119 ms → 40 ms bandına iniyor.
    sinyal: sinyalGerek ? n : null,
  };
}

/** Skorla + doygunluk cezası + AI/arşiv kotası → sıralı id listesi.
 *
 *  Kotalar CAP (tavan) mantığıyla çalışır ve gönderiyi ATMAZ, ERTELER: aday
 *  kalmazsa yine listeye girer. Böylece "AI payı %0" ya da "arşiv payı %5"
 *  gibi uç ayarlar havuzu boşaltmaz (plan §5.4 güvenli mod gerekçesi;
 *  ölçüm: Keşfet videolarının %91,5'i arşiv hesabında).
 *
 *  Doygunluk: liste skora göre sıralanır, sonra baştan geçilirken her seçilen
 *  kart aynı yazarın/yapımın kalan kartlarını çarpanla düşürür — O(n·log n). */
// Doygunluk/kota taraması yalnız listenin BAŞINDAKİ bu kadar adaya bakar.
// Gerekçe: liste zaten skora göre sıralı ve cezalar skoru YALNIZ DÜŞÜRÜR, yani
// kazanan bu pencerenin dışından çıkamaz. Pencere olmadan döngü O(n²) olurdu —
// 4.845 adayda 23 milyon karşılaştırma; pencereyle 4.845 × 150.
const DOYGUNLUK_PENCERESI = 150;

// Çeşitlilik/kota yalnız listenin İLK bu kadar kartında uygulanır; gerisi saf
// skor sırasıyla eklenir. Gerekçe ölçüldü: kullanıcı başına ortalama kaydırma
// derinliği 19,3 kart, en derin oturum bile birkaç yüz kartı geçmiyor —
// 4.800. kartta yazar çeşitliliğini hesaplamak kimseye fayda etmez ama
// döngüyü 730 bin adımdan 60 bine indirir.
const CESITLENDIR_ADET = 400;

export function siralaVeKotala(adaylar, ayar, olcum, {
  kirilimAdet = 0, cesitlendirAdet = CESITLENDIR_ADET,
} = {}) {
  const hacim = hacimUygula(ayar, olcum);
  const sinyalGerek = kirilimAdet > 0;
  const puanli = adaylar.map((g) => ({ g, ...skorla(g, ayar, olcum, hacim, sinyalGerek) }));
  puanli.sort((a, b) => (b.skor - a.skor) || (b.id - a.id));

  const yazarSayac = new Map();
  const icerikSayac = new Map();
  const secilen = [];
  const kirilim = [];
  let aiSayi = 0;
  let arsivSayi = 0;
  const aiTavan = kis(ayar.ai_payi, 0, 100) / 100;
  const arsivTavan = kis(ayar.arsiv_payi, 0, 100) / 100;
  // VİDEO TABANI (26 Ağu 2026): tavanlar "en fazla şu kadar" der, bu "en az
  // şu kadar". Videolar skor sıralı listenin DİBİNDE yaşadığı için (akışta
  // medya ağırlığı 0 + tazelik arşivi tabana çakar) doygunluk penceresi onları
  // asla görmez; taban tetiklenince en iyi video TÜM kalan havuzdan seçilir.
  // Maliyet ölçülü: tetik seçimlerin ~%10'unda, tarama O(kalan) → 400 kart ×
  // 25k aday en kötü halde ~1M ucuz karşılaştırma, tek sefer (liste donuyor).
  const videoTaban = kis(ayar.video_tabani ?? 0, 0, 100) / 100;
  let videoSayi = 0;
  const kalan = puanli;
  let bas = 0; // kalan[bas..] henüz seçilmemişler (seçilen öne takas edilir)

  while (bas < kalan.length) {
    // Çeşitlendirme bütçesi bitti: kalanı saf skor sırasıyla ekle. Takas
    // sırayı hafifçe bozmuş olabilir, yeniden sıralanır — sonuç DETERMİNİSTİK
    // kalmalı, tur tohumu sayfalaması buna dayanıyor.
    if (secilen.length >= cesitlendirAdet) {
      const tail = kalan.slice(bas).sort((a, b) => (b.skor - a.skor) || (b.id - a.id));
      for (const p of tail) secilen.push(p.id);
      break;
    }
    const son = Math.min(kalan.length, bas + DOYGUNLUK_PENCERESI);
    let enIyi = -1;
    let enIyiPuan = -Infinity;
    const sonraki = secilen.length + 1;
    // Taban tetiği: floor() BİLEREK — taban %10'da ilk video 10. kartta
    // belirir, 1. kartta değil (akışın girişi videoya kilitlenmesin).
    // AI/arşiv tavanları bu seçimde BİLEREK atlanır: videoların %91,5'i arşiv
    // AI hesabında, tavanlar uygulansa taban hiç çalışmazdı. Sayaçlara yine de
    // işlenir ki organik seçim dengelesin. Doygunluk cezaları uygulanır —
    // taban aynı yazarın/yapımın videolarını art arda dizmesin.
    if (videoTaban > 0 && videoSayi < Math.floor(videoTaban * sonraki + 1e-9)) {
      for (let i = bas; i < kalan.length; i++) {
        const v = kalan[i];
        if (v.g.kat !== 0) continue;
        const yz = yazarSayac.get(v.g.kullanici_id) || 0;
        const ic = icerikSayac.get(`${v.g.tur}:${v.g.tmdb_id}`) || 0;
        const puan = v.skor
          * Math.pow(ayar.yazar_doygunluk, yz)
          * Math.pow(ayar.icerik_doygunluk, ic);
        if (puan > enIyiPuan) { enIyiPuan = puan; enIyi = i; }
      }
      // Havuzda hiç video kalmadıysa taban sessizce devreden çıkar (enIyi=-1
      // kaldı) ve normal pencere seçimi çalışır — liste asla kısalmaz.
    }
    if (enIyi < 0) for (let i = bas; i < son; i++) {
      const p = kalan[i];
      // Kota kontrolü: bu kartı ALIRSAK pay tavanı aşılıyor mu?
      if (p.g.ai && (aiSayi + 1) / sonraki > aiTavan + 1e-9) continue;
      if (p.g.arsiv && (arsivSayi + 1) / sonraki > arsivTavan + 1e-9) continue;
      const yz = yazarSayac.get(p.g.kullanici_id) || 0;
      const ic = icerikSayac.get(`${p.g.tur}:${p.g.tmdb_id}`) || 0;
      const puan = p.skor
        * Math.pow(ayar.yazar_doygunluk, yz)
        * Math.pow(ayar.icerik_doygunluk, ic);
      if (puan > enIyiPuan) { enIyiPuan = puan; enIyi = i; }
    }
    // Kotalar yüzünden pencerede hiçbir aday uygun değilse ERTELEMEYİ BIRAK:
    // sıradakini al. Havuz asla boşalmaz — uç ayar (AI payı %0 gibi) listeyi
    // kısaltmaz, yalnız sırasını değiştirir (plan §5.4 güvenli mod gerekçesi).
    const secim = enIyi >= 0 ? enIyi : bas;
    const p = kalan[secim];
    kalan[secim] = kalan[bas];
    kalan[bas] = p;
    bas++;
    secilen.push(p.id);
    if (kirilim.length < kirilimAdet) {
      kirilim.push({
        id: p.id, skor: p.skor, etkin_skor: enIyi >= 0 ? enIyiPuan : p.skor,
        ilgi: p.ilgi, tazelik: p.tazelik, ceza_spoiler: p.ceza_spoiler,
        sinyal: p.sinyal, kullanici_id: p.g.kullanici_id,
        ai: !!p.g.ai, arsiv: !!p.g.arsiv, videolu: p.g.kat === 0,
      });
    }
    yazarSayac.set(p.g.kullanici_id, (yazarSayac.get(p.g.kullanici_id) || 0) + 1);
    const ick = `${p.g.tur}:${p.g.tmdb_id}`;
    icerikSayac.set(ick, (icerikSayac.get(ick) || 0) + 1);
    if (p.g.ai) aiSayi++;
    if (p.g.arsiv) arsivSayi++;
    if (p.g.kat === 0) videoSayi++; // organik seçilen video da tabanı doldurur
  }
  return { idler: secilen, kirilim };
}

// ---------------------------------------------------------------------------
// SAYFALAMA — tur tohumu (plan §4.5)
//
// Skor zamana bağlıdır (tazelik) ve doygunluk cezası ardışıktır; bu yüzden
// "(skor, id) bileşik imleç" kayar → tekrar ve atlama olur. Çözüm: ilk sayfada
// sıralı id listesi DONDURULUR, imleç yalnız o listedeki ofseti taşır.
//
// GERİYE UYUM ZORUNLU: eski istemciler `?once=<id>` (akış) ve
// `<tur>:<kat>:<id>` (keşfet) göndermeye devam eder. Yeni biçim `s` ile
// başlar, eski desenlerin hiçbiriyle çakışmaz.
// ---------------------------------------------------------------------------

const YENI_IMLEC = /^s([0-9a-z]{1,12}):(\d{1,7})(?::([01]))?$/;
const ESKI_KESFET_IMLEC = /^([01]):(?:([0-2]):(\d{1,9}))?$/;

export const imlecYaz = (tohum, ofset, tur) => `s${tohum}:${ofset}${tur ? `:${tur}` : ''}`;

/** İmleci çöz. Döner:
 *   {bicim:'yeni', tohum, ofset, tur}
 *   {bicim:'eski_kesfet', tekrar, kat, once}
 *   {bicim:'eski_akis', once}
 *   {bicim:'yok'}                                  */
export function imlecCoz(ham, once) {
  const s = String(ham || '');
  const y = YENI_IMLEC.exec(s);
  if (y) {
    return {
      bicim: 'yeni', tohum: y[1], ofset: parseInt(y[2], 10),
      tur: y[3] ? parseInt(y[3], 10) : 0,
    };
  }
  const e = ESKI_KESFET_IMLEC.exec(s);
  if (e) {
    return {
      bicim: 'eski_kesfet',
      tekrar: e[1] === '1',
      kat: e[2] !== undefined ? parseInt(e[2], 10) : null,
      once: e[3] !== undefined ? parseInt(e[3], 10) : null,
    };
  }
  const o = parseInt(once, 10);
  if (Number.isInteger(o) && o > 0) return { bicim: 'eski_akis', once: o };
  return { bicim: 'yok' };
}

/** Tur tohumu deposu: TTL + LRU. Bellek ölçüsü (plan §4.5): 4.843 id ≈ 39 KB
 *  oturum başına; 100 eşzamanlı oturum ≈ 3,9 MB. */
export class TohumDeposu {
  constructor({ ttlMs = 600000, azami = 500 } = {}) {
    this.ttlMs = ttlMs;
    this.azami = azami;
    this.harita = new Map();
  }

  yaz(anahtar, idler, simdi = Date.now()) {
    if (this.harita.has(anahtar)) this.harita.delete(anahtar);
    this.harita.set(anahtar, { ts: simdi, idler });
    while (this.harita.size > this.azami) {
      this.harita.delete(this.harita.keys().next().value);
    }
  }

  oku(anahtar, simdi = Date.now()) {
    const k = this.harita.get(anahtar);
    if (!k) return null;
    if (simdi - k.ts > this.ttlMs) { this.harita.delete(anahtar); return null; }
    // LRU tazeleme: okunan kayıt sona taşınır.
    this.harita.delete(anahtar);
    this.harita.set(anahtar, k);
    return k.idler;
  }

  get boyut() { return this.harita.size; }
}

// Tur tohumu, kullanıcı + ZAMAN PENCERESİNDEN türetilir (plan §4.5:
// "rastgele 32-bit ya da kullanıcı+dakika hash'i"). Rastgele tohum ölçüldü ve
// REDDEDİLDİ: her ilk-sayfa isteği yeni tohum üretiyor, 10 dakikalık önbellek
// hiç tutmuyor ve her yenilemede 4.845 aday baştan skorlanıyordu
// (/kesfet-akis 0,65 s → 1,05 s). Pencere içinde tohum sabit olduğu için
// aynı kullanıcının ard arda yenilemesi önbellekten döner; pencere dolunca
// liste tazelenir ve bu arada "görüldü" işaretlenenler havuzdan düşer.
export const TOHUM_PENCERESI_MS = 120000; // 2 dakika

export const tohumUret = (kullaniciId = 0, yuzey = '', simdi = Date.now()) => {
  const pencere = Math.floor(simdi / TOHUM_PENCERESI_MS);
  const y = yuzey === 'kesfet' ? 1 : 0;
  // 32-bit karıştırma (Knuth çarpanı) — tohum tahmin edilebilir olmamalı ki
  // başkasının imlecini uydurmak işe yaramasın; zaten liste kullanıcı
  // anahtarıyla saklanıyor, tohum yalnız tur kimliği.
  const h = Math.imul(kullaniciId * 2 + y + pencere * 7919, 2654435761) >>> 0;
  return h.toString(36);
};


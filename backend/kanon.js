// "ÖLMEDEN İZLENMESİ GEREKEN" KANON LİSTELERİ — saf mantık (16 Eyl 2026).
//
// İSTEK (birebir): "Ölmeden izlenmesi gereken 100 film 250 film 500 film 1000
// film listeleri yap, bunları da ana sayfada ve akışta göster; aynısının dizi
// versiyonunu 10 25 50 100 olarak; ana sayfada aralara serpiştir."
//
// KAYNAK: TMDB `discover` — puan sıralı (`vote_average.desc`), oy eşiği
// (film ≥ 3000, dizi ≥ 1000; IMDB-TOP500.md ile aynı ölçüt). Listeler İÇ İÇE
// GEÇMİŞ: 100 ⊂ 250 ⊂ 500 ⊂ 1000 (aynı sıralamanın ilk N'i) — "100 film"
// listesindeki bir yapım "1000 film"de de aynı sırada durur.
//
// NEDEN TABLO YOK: TMDB yanıtları zaten `tmdb_onbellek`te (7 gün TTL) durur;
// liste bellek içinde 24 saatte bir yeniden kurulur, her işçi ilk istekte
// önbellekten (ağ yok) toplar. Migrasyon/cron gerekmez.

export const KANON_BOYLAR = Object.freeze({
  movie: [100, 250, 500, 1000],
  tv: [10, 25, 50, 100],
});

/** TMDB discover sayfa boyu (sabit). */
export const TMDB_SAYFA = 20;

/** Postersiz/adsız kayıtlar düştüğü için hedefin %30 fazlası çekilir. */
export const KANON_PAY = 1.3;

export const KANON_SORGU = Object.freeze({
  movie: '/discover/movie?sort_by=vote_average.desc&vote_count.gte=3000&language=tr-TR',
  tv: '/discover/tv?sort_by=vote_average.desc&vote_count.gte=1000&language=tr-TR',
});

export function kanonGecerli(medya, boy) {
  return Array.isArray(KANON_BOYLAR[medya]) && KANON_BOYLAR[medya].includes(Number(boy));
}

/** Raf başlığı — istemcide AYNI dize çeviri anahtarıdır (kesfet.dart). */
export function kanonBasligi(medya, boy) {
  return `Ölmeden İzlenmesi Gereken ${boy} ${medya === 'tv' ? 'Dizi' : 'Film'}`;
}

/** Gereken TMDB sayfa sayısı (en büyük liste için, payla). */
export function kanonSayfaSayisi(medya) {
  const enBuyuk = Math.max(...KANON_BOYLAR[medya]);
  return Math.ceil((enBuyuk * KANON_PAY) / TMDB_SAYFA);
}

/** Sayfa yolları: `&page=N` eklenmiş sorgular, 1'den başlar. */
export function kanonSayfaYollari(medya) {
  const n = kanonSayfaSayisi(medya);
  return Array.from({ length: n }, (_, i) => `${KANON_SORGU[medya]}&page=${i + 1}`);
}

/**
 * TMDB sayfalarını (sırayla) tek sıralı listeye indirger: posterli + adlı,
 * tekrarsız (TMDB sayfa kayması aynı kaydı iki sayfada verebilir), en fazla
 * `azami`. Her öğeye `sira` (1'den), `tur`, `tmdb_id`, `media_type` eklenir.
 */
export function kanonSirala(medya, sayfalar, azami = Math.max(...KANON_BOYLAR[medya])) {
  const gorulen = new Set();
  const liste = [];
  for (const sayfa of sayfalar) {
    for (const r of (sayfa && sayfa.results) || []) {
      if (!r || !r.poster_path || !(r.title || r.name) || !Number.isInteger(r.id)) continue;
      if (gorulen.has(r.id)) continue;
      gorulen.add(r.id);
      liste.push({ ...r, media_type: medya, tur: medya, tmdb_id: r.id, sira: liste.length + 1 });
      if (liste.length >= azami) return liste;
    }
  }
  return liste;
}

/** 1 tabanlı sayfa dilimi; `adet` 1..1000. */
export function kanonSayfaDilimi(liste, sayfa, adet) {
  const s = Math.max(1, parseInt(sayfa, 10) || 1);
  const a = Math.min(1000, Math.max(1, parseInt(adet, 10) || TMDB_SAYFA));
  const bas = (s - 1) * a;
  return { ogeler: liste.slice(bas, bas + a), devam: bas + a < liste.length, toplam: liste.length, sayfa: s, adet: a };
}

/** Ana sayfa/akış serpiştirme sırası: film ve dizi rafları dönüşümlü. */
export function kanonRafSirasi() {
  const f = KANON_BOYLAR.movie, d = KANON_BOYLAR.tv;
  const sira = [];
  for (let i = 0; i < Math.max(f.length, d.length); i++) {
    if (f[i] != null) sira.push({ medya: 'movie', boy: f[i] });
    if (d[i] != null) sira.push({ medya: 'tv', boy: d[i] });
  }
  return sira;
}

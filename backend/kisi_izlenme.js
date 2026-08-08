// Bir oyuncunun yapımları + kullanıcının kaçını izlediği — SAF fonksiyonlar.
//
// İSTEK (8 Ağu 2026): "Bir oyuncu profili ziyaret edildiğinde o oyuncunun
// oynadığı kaç dizi/film izlendi onu da oyuncu profilinde puanla yazısının
// altında göstermeli, mesela 10/20 gibi."
//
// ---------------------------------------------------------------------------
// KARAR 1 — "İZLENDİ" NE DEMEK?
//
// Uygulamada bunun ZATEN bir tanımı var: poster kartlarındaki göz rozeti
// (`app/lib/kitaplik_durumu.dart`) `durum IN ('izliyorum','bitirdim','biraktim')`
// olanları izlenmiş sayıyor, `izleyecegim`i saymıyor. Oyuncu sayfasında BAŞKA
// bir kural kullanmak, aynı posterin bir ekranda gözlü bir ekranda çarpılı
// görünmesi demekti. Bu yüzden aynı kural buraya taşındı, üstüne bir OR:
//
//   izlendi = durum IN ('izliyorum','bitirdim','biraktim')
//          OR izlemeler'de en az bir kayıt (dizide en az bir BÖLÜM,
//             filmde filmin kendisi)
//
// İkinci koşulun sebebi: `durumlar` satırı olmadan bölüm işaretlenmiş eski
// kayıtlar var (4 Ağu ölçümü: 1265 film izlemesinin 1229'unun `durumlar`da
// karşılığı yoktu; `filmDurumunuGuncelle` o günden sonra yazılanları düzeltiyor
// ama geçmiş kayıtlar öyle kaldı). Onlar da izlenmiştir.
//
// `izleyecegim` neden sayılmaz: kullanıcı henüz izlemedi — listede çarpı
// görmesi doğru olan tam da bu durum.
//
// ---------------------------------------------------------------------------
// KARAR 2 — PAYDA (kaç yapım?)
//
// TMDB `/person/:id/combined_credits` `cast` dizisi. Süzgeçler:
//   - media_type yalnız 'tv' | 'movie' (başka tür gelirse atılır),
//   - poster_path zorunlu: liste görünümünün SOL sütunu kapak; kapaksız kayıt
//     hem çirkin hem de bunlar TMDB'de neredeyse hep eksik/çöp kayıtlar,
//   - (tur, id) TEKİLLEŞTİRİLİR: bir oyuncu aynı dizide iki rolde oynadıysa
//     TMDB iki ayrı credit döndürür; payda 20 yerine 22 görünürdü.
//
// `crew` bilerek DIŞARIDA: kullanıcının sözü "oynadığı dizi film" — yönetmenlik
// / yapımcılık kredileri oyunculuk değil, ve kişi ekranındaki ızgara da yalnız
// `cast` gösteriyor (kisi.dart).

const IZLENMIS_DURUMLAR = new Set(['izliyorum', 'bitirdim', 'biraktim']);

/** 'tv:1399' biçiminde tekil anahtar. */
export function yapimAnahtari(tur, tmdbId) {
  return `${tur}:${tmdbId}`;
}

/**
 * combined_credits gövdesinden gösterilecek yapım listesini üretir.
 * Sıra: oy sayısına göre azalan (tanınmış işler önce) — kişi ekranındaki
 * ızgarayla aynı sıralama, iki liste birbirini tutsun diye.
 * @returns {{tur:string, tmdb_id:number, ad:string, poster:string|null, yil:string|null}[]}
 */
export function yapimlariCikar(krediler) {
  const cast = Array.isArray(krediler?.cast) ? krediler.cast : [];
  const gorulen = new Set();
  const cikti = [];
  for (const c of cast) {
    const tur = c?.media_type;
    if (tur !== 'tv' && tur !== 'movie') continue;
    if (!c.poster_path) continue;
    const id = Number(c.id);
    if (!Number.isInteger(id) || id <= 0) continue;
    const anahtar = yapimAnahtari(tur, id);
    if (gorulen.has(anahtar)) continue;
    gorulen.add(anahtar);
    const tarih = (tur === 'tv' ? c.first_air_date : c.release_date) || '';
    cikti.push({
      tur,
      tmdb_id: id,
      ad: String(c.name || c.title || '').slice(0, 200),
      poster: c.poster_path || null,
      yil: /^\d{4}/.test(tarih) ? tarih.slice(0, 4) : null,
      _oy: Number(c.vote_count) || 0,
    });
  }
  cikti.sort((a, b) => b._oy - a._oy);
  return cikti.map(({ _oy, ...k }) => k);
}

/**
 * Kullanıcının izlediği (tur,tmdb_id) anahtar kumesi.
 * @param durumSatirlari {tur, tmdb_id, durum}[] — `durumlar` tablosu
 * @param izlemeSatirlari {tur, tmdb_id}[] — `izlemeler` tablosu (tekilleştirilmiş)
 */
export function izlenenAnahtarlar(durumSatirlari = [], izlemeSatirlari = []) {
  const kume = new Set();
  for (const d of durumSatirlari) {
    if (IZLENMIS_DURUMLAR.has(d?.durum)) kume.add(yapimAnahtari(d.tur, d.tmdb_id));
  }
  for (const i of izlemeSatirlari) kume.add(yapimAnahtari(i?.tur, i?.tmdb_id));
  return kume;
}

/**
 * Yapımlara `izlendi` bayrağı ekler, izlenenleri BAŞA alır ve oranı hesaplar.
 *
 * Sıralama kararı: izlenenler üstte. Kullanıcı orana tıklıyor ("10/20"),
 * yani merak ettiği şey "hangi 10'unu izlemişim". 60 satırın içine serpilmiş
 * tiklerin arasında kaybolmasın diye tikliler bloklanıp öne alınır; her blok
 * kendi içinde tanınmışlık (oy) sırasını korur.
 */
export function izlenmeOzeti(yapimlar, izlenen) {
  const isaretli = yapimlar.map((y) => ({
    ...y,
    izlendi: izlenen.has(yapimAnahtari(y.tur, y.tmdb_id)),
  }));
  // Kararlı sıralama: Array#sort V8'de kararlıdır, blok içi sıra bozulmaz.
  isaretli.sort((a, b) => (a.izlendi === b.izlendi ? 0 : a.izlendi ? -1 : 1));
  return {
    izlenen: isaretli.filter((y) => y.izlendi).length,
    toplam: isaretli.length,
    yapimlar: isaretli,
  };
}

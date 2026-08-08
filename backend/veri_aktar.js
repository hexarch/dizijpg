// dizi.jpg — GDPR uyumlu veri dışa/içe aktarma.
// Dışa aktarım: TV Time formatında CSV'ler + kayıpsız geri yükleme için dizijpg.json.
// İçe aktarım: TV Time ZIP'i (TheTVDB→TMDB eşlemeli) veya dizijpg.json.
// Güvenlik: yalnızca sahibinin verisi; zip-bomb/path-traversal/boyut korumaları.
import JSZip from 'jszip';
import { parse } from 'csv-parse/sync';

// ---- CSV üretimi (virgül/tırnak/yeni satır içeren alanları kaçırır) ----
function csvAlan(deger) {
  if (deger == null) return '';
  const s = String(deger);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}
function csvYap(basliklar, satirlar) {
  const cikti = [basliklar.join(',')];
  for (const s of satirlar) cikti.push(basliklar.map((b) => csvAlan(s[b])).join(','));
  return cikti.join('\n') + '\n';
}

// ---------- DIŞA AKTARIM ----------
export async function disaAktar(havuz, userId) {
  const [kullanici, durumlar, izlemeler, puanlar, yorumlar, listeler, listeOgeleri, favoriler] =
    await Promise.all([
      havuz.query('SELECT id, kullanici_adi, email, bio, ulke, olusturma FROM kullanicilar WHERE id=$1', [userId]),
      havuz.query('SELECT tur, tmdb_id, durum, guncelleme FROM durumlar WHERE kullanici_id=$1', [userId]),
      havuz.query('SELECT tur, tmdb_id, sezon, bolum, tarih FROM izlemeler WHERE kullanici_id=$1', [userId]),
      // sezon/bolum (8 Ağu 2026-d): bölüm puanları da KULLANICININ VERİSİDİR,
      // KVKK/GDPR dışa aktarımında eksik kalamaz ve geri yüklemede kaybolamaz.
      havuz.query(
        'SELECT tur, tmdb_id, sezon, bolum, puan, yorum, tarih FROM puanlar WHERE kullanici_id=$1',
        [userId]),
      havuz.query('SELECT id, tur, tmdb_id, sezon, bolum, metin, tarih FROM yorumlar WHERE kullanici_id=$1', [userId]),
      havuz.query('SELECT id, ad, aciklama, herkese_acik, olusturma FROM listeler WHERE kullanici_id=$1', [userId]),
      havuz.query(
        `SELECT o.liste_id, o.tmdb_id, o.tur, o.eklenme FROM liste_ogeleri o
         JOIN listeler l ON l.id=o.liste_id WHERE l.kullanici_id=$1`, [userId]),
      havuz.query('SELECT tur, tmdb_id, tarih FROM favoriler WHERE kullanici_id=$1', [userId]),
    ]);

  if (!kullanici.rows.length) throw Object.assign(new Error('Kullanıcı yok'), { status: 404 });
  const k = kullanici.rows[0];
  const zip = new JSZip();

  // TV Time uyumlu dosyalar
  zip.file('user.csv', csvYap(
    ['id', 'name', 'mail', 'language', 'created_at'],
    [{ id: k.id, name: k.kullanici_adi, mail: k.email || '', language: 'tr', created_at: k.olusturma?.toISOString?.() || '' }],
  ));
  if (k.ulke) {
    zip.file('user_personal_data.csv', csvYap(
      ['name', 'value', 'user_id'],
      [{ name: 'country-code', value: k.ulke, user_id: k.id }],
    ));
  }
  zip.file('followed_tv_show.csv', csvYap(
    ['user_id', 'tv_show_id', 'tv_show_name', 'active', 'archived', 'created_at'],
    durumlar.rows.filter((d) => d.tur === 'tv').map((d) => ({
      user_id: k.id, tv_show_id: d.tmdb_id, tv_show_name: '',
      active: d.durum === 'bitirdim' ? 0 : 1,
      archived: d.durum === 'bitirdim' ? 1 : 0,
      created_at: d.guncelleme?.toISOString?.() || '',
    })),
  ));
  zip.file('seen_episode_latest.csv', csvYap(
    ['user_id', 'tv_show_id', 'episode_season_number', 'episode_number', 'created_at'],
    izlemeler.rows.filter((i) => i.tur === 'tv').map((i) => ({
      user_id: k.id, tv_show_id: i.tmdb_id,
      episode_season_number: i.sezon, episode_number: i.bolum,
      created_at: i.tarih?.toISOString?.() || '',
    })),
  ));
  zip.file('seen_movie.csv', csvYap(
    ['user_id', 'movie_id', 'created_at'],
    izlemeler.rows.filter((i) => i.tur === 'movie').map((i) => ({
      user_id: k.id, movie_id: i.tmdb_id, created_at: i.tarih?.toISOString?.() || '',
    })),
  ));
  zip.file('ratings.csv', csvYap(
    ['user_id', 'type', 'tmdb_id', 'season_number', 'episode_number',
      'rating', 'review', 'created_at'],
    puanlar.rows.map((p) => ({
      user_id: k.id, type: p.tur, tmdb_id: p.tmdb_id,
      // comments.csv ile AYNI sözleşme: boş hücre = içeriğin GENELİ.
      season_number: p.sezon ?? '', episode_number: p.bolum ?? '',
      rating: p.puan,
      review: p.yorum || '', created_at: p.tarih?.toISOString?.() || '',
    })),
  ));
  zip.file('comments.csv', csvYap(
    ['user_id', 'type', 'tmdb_id', 'season_number', 'episode_number', 'comment', 'created_at'],
    yorumlar.rows.map((y) => ({
      user_id: k.id, type: y.tur, tmdb_id: y.tmdb_id,
      season_number: y.sezon ?? '', episode_number: y.bolum ?? '',
      comment: y.metin, created_at: y.tarih?.toISOString?.() || '',
    })),
  ));
  const listeAdlari = Object.fromEntries(listeler.rows.map((l) => [l.id, l.ad]));
  zip.file('lists.csv', csvYap(
    ['list_name', 'is_public', 'type', 'tmdb_id', 'created_at'],
    listeOgeleri.rows.map((o) => ({
      list_name: listeAdlari[o.liste_id] || '', is_public: '', type: o.tur,
      tmdb_id: o.tmdb_id, created_at: o.eklenme?.toISOString?.() || '',
    })),
  ));

  // Kayıpsız geri yükleme için kendi biçimimiz (TMDB kimlikleriyle)
  const native = {
    surum: 1,
    kullanici: { kullanici_adi: k.kullanici_adi, bio: k.bio, ulke: k.ulke },
    durumlar: durumlar.rows,
    izlemeler: izlemeler.rows,
    puanlar: puanlar.rows,
    yorumlar: yorumlar.rows.map(({ id, ...r }) => r),
    favoriler: favoriler.rows,
    listeler: listeler.rows.map((l) => ({
      ad: l.ad, aciklama: l.aciklama, herkese_acik: l.herkese_acik,
      ogeler: listeOgeleri.rows.filter((o) => o.liste_id === l.id)
        .map(({ tmdb_id, tur }) => ({ tmdb_id, tur })),
    })),
  };
  zip.file('dizijpg.json', JSON.stringify(native, null, 2));
  zip.file('README.txt',
    'dizi.jpg veri dışa aktarımı\n\n' +
    'TV Time uyumlu CSV dosyaları ve kayıpsız geri yükleme için dizijpg.json içerir.\n' +
    'İçe aktarımda bu ZIP olduğu gibi yüklenebilir.\n');

  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' });
}

// Yorumu yalnızca aynısı yoksa ekler (yeniden içe aktarımda çiftlemesin).
// Aktarılan filmleri kitaplığa da işler: izleme kaydı olan her filme
// durum='bitirdim' verir. Filmde ara hâl yoktur, izlendiyse bitmiştir.
//
// NEDEN: rozet, kitaplık sekmeleri ve profil sayaçları TEK kaynaktan
// (`durumlar`) okunur. İçe aktarım yalnız `izlemeler`e yazdığı için aktarılan
// filmler hiçbir yerde izlenmiş görünmüyordu (4 Ağu 2026 canlı ölçüm: içe
// aktarım hesaplarında 417+417 filmin durumu YOKTU).
//
// DO NOTHING: kullanıcının elle koyduğu durum (izleyecegim/biraktim) EZİLMEZ.
async function filmDurumlariniEsitle(havuz, userId) {
  const { rowCount } = await havuz.query(
    `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum)
     SELECT i.kullanici_id, 'movie', i.tmdb_id, 'bitirdim'
     FROM izlemeler i
     WHERE i.kullanici_id=$1 AND i.tur='movie'
     ON CONFLICT (kullanici_id, tur, tmdb_id) DO NOTHING`,
    [userId]);
  return rowCount;
}

async function yorumEkleTekil(havuz, userId, tur, tmdbId, sezon, bolum, metin) {
  const mevcut = await havuz.query(
    `SELECT 1 FROM yorumlar WHERE kullanici_id=$1 AND tur=$2 AND tmdb_id=$3
       AND sezon IS NOT DISTINCT FROM $4 AND bolum IS NOT DISTINCT FROM $5 AND metin=$6
     LIMIT 1`,
    [userId, tur, tmdbId, sezon, bolum, metin]);
  if (mevcut.rows.length) return false;
  await havuz.query(
    `INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, sezon, bolum, metin)
     VALUES ($1,$2,$3,$4,$5,$6)`,
    [userId, tur, tmdbId, sezon, bolum, metin]);
  return true;
}

// ---------- İÇE AKTARIM ----------
const IZIN_LI_DOSYALAR = new Set([
  'dizijpg.json', 'user_personal_data.csv', 'followed_tv_show.csv',
  'seen_episode_latest.csv', 'show_seen_episode_latest.csv',
  'watched_on_episode.csv', 'seen_movie.csv',
  'tracking-prod-records-v2.csv', 'tracking-prod-records.csv',
  'comments.csv', 'show_comment.csv', 'episode_comment.csv', 'ratings.csv', 'lists.csv',
]);
const MAX_TOPLAM_ACIK = 200 * 1024 * 1024; // 200MB açılmış boyut (zip-bomb koruması)
const MAX_DOSYA_ACIK = 60 * 1024 * 1024;
const MAX_GIRIS = 300; // en fazla dosya girişi
const MAX_FIND = 1000; // TheTVDB→TMDB eşleme çağrısı üst sınırı (önbellekli)

// tmdbFind(tvdbId) → TMDB tv id | null (TheTVDB eşlemesi).
// tmdbAra(isim)   → TMDB tv id | null (isimle arama; takip listesinde olmayan
//                   ama izlenmiş diziler için yedek). İkisini de server.js sağlar.
// tmdbDetay(tmdbId) → { number_of_episodes } | null. Bitirme tespiti için.
// tmdbAraFilm(isim) → TMDB film id | null (izlenen filmleri eşlemek için).
export async function iceAktar(havuz, userId, zipBuffer, tmdbFind, tmdbAra = null, tmdbDetay = null, tmdbAraFilm = null) {
  let zip;
  try {
    zip = await JSZip.loadAsync(zipBuffer);
  } catch {
    throw Object.assign(new Error('Geçersiz ZIP dosyası'), { status: 400 });
  }

  // Güvenli dosya toplama: yalnızca tanınan dosya adları (yol yok sayılır),
  // dizin/sembolik bağ atlanır, boyut sınırları uygulanır.
  const girisler = Object.values(zip.files);
  if (girisler.length > MAX_GIRIS) {
    throw Object.assign(new Error('ZIP çok fazla dosya içeriyor'), { status: 400 });
  }
  const metinler = {};
  let toplam = 0;
  for (const giris of girisler) {
    if (giris.dir) continue;
    let ad = giris.name.split('/').pop(); // yol kısmı atılır → traversal engellenir
    // TV Time'ın yeni tek dosyalı dışa aktarımı: "tv-time-export (1).csv" gibi
    if (/^tv-time-export.*\.csv$/i.test(ad)) ad = 'tv-time-export.csv';
    else if (!IZIN_LI_DOSYALAR.has(ad)) continue; // token/şifre/ip dosyaları okunmaz
    const veri = await giris.async('nodebuffer');
    if (veri.length > MAX_DOSYA_ACIK) {
      throw Object.assign(new Error(`${ad} çok büyük`), { status: 400 });
    }
    toplam += veri.length;
    if (toplam > MAX_TOPLAM_ACIK) {
      throw Object.assign(new Error('ZIP içeriği çok büyük'), { status: 400 });
    }
    metinler[ad] = veri.toString('utf8');
  }

  const ozet = { durum: 0, izleme: 0, puan: 0, yorum: 0, liste: 0, profil: 0, atlanan: 0 };

  // 1) Kayıpsız kendi biçimimiz varsa onu kullan.
  if (metinler['dizijpg.json']) {
    return iceAktarNative(havuz, userId, metinler['dizijpg.json'], ozet);
  }

  // 1.5) TV Time'ın YENİ tek dosyalı formatı (2026+):
  // type,media_type,tmdb_id,imdb_id,tvdb_id,title,year,season,episode,watched_at,rating,review
  // id alanları çoğunlukla boş gelir → isimle (tr-TR arama) eşlenir.
  if (metinler['tv-time-export.csv']) {
    let satirlar = [];
    try {
      satirlar = parse(metinler['tv-time-export.csv'],
        { columns: true, skip_empty_lines: true, relax_column_count: true });
    } catch {
      throw Object.assign(new Error('CSV okunamadı'), { status: 400 });
    }
    ozet.isim_eslesme = 0;
    const adOnbellek = new Map(); // 'tv:Ad' | 'movie:Ad' → tmdbId|null
    async function coz(tur, isim, tmdbIdAlan) {
      const dogrudan = parseInt(tmdbIdAlan, 10);
      if (Number.isInteger(dogrudan) && dogrudan > 0) return dogrudan;
      const temiz = String(isim || '').replace(/\s*\(\d{4}\)\s*$/, '').trim();
      if (!temiz) return null;
      const anahtar = `${tur}:${temiz}`;
      if (adOnbellek.has(anahtar)) return adOnbellek.get(anahtar);
      if (adOnbellek.size >= MAX_FIND) return null;
      let id = null;
      try {
        id = tur === 'tv'
          ? (tmdbAra ? await tmdbAra(temiz) : null)
          : (tmdbAraFilm ? await tmdbAraFilm(temiz) : null);
      } catch { id = null; }
      if (id) ozet.isim_eslesme += 1;
      adOnbellek.set(anahtar, id);
      return id;
    }

    // Bölümleri dizi başına grupla
    const diziler = new Map(); // title → [{sezon,bolum,tarih}]
    const filmler = new Map(); // title → {tarih, tmdb_id}
    for (const r of satirlar) {
      if ((r.type || 'watch') !== 'watch') continue;
      if (r.media_type === 'episode') {
        const s = parseInt(r.season, 10);
        const b = parseInt(r.episode, 10);
        if (!Number.isInteger(s) || !Number.isInteger(b)) { ozet.atlanan += 1; continue; }
        const liste = diziler.get(r.title) || [];
        liste.push({ s, b, t: r.watched_at || null, tmdb: r.tmdb_id });
        diziler.set(r.title, liste);
      } else if (r.media_type === 'movie') {
        if (!filmler.has(r.title)) {
          filmler.set(r.title, { t: r.watched_at || null, tmdb: r.tmdb_id });
        }
      } else {
        ozet.atlanan += 1;
      }
    }

    // İsim aramalarını 8'erli paralel öbeklerle önden doldur (nginx zaman
    // aşımına takılmamak için; tekil aramalar sıralı olursa dakikalar sürer).
    const hedefler = [
      ...[...diziler.entries()].map(([i, b]) => ['tv', i, b[0].tmdb]),
      ...[...filmler.entries()].map(([i, f]) => ['movie', i, f.tmdb]),
    ];
    for (let i = 0; i < hedefler.length; i += 8) {
      await Promise.all(
        hedefler.slice(i, i + 8).map(([t, isim, id]) => coz(t, isim, id)));
    }

    for (const [isim, bolumler] of diziler) {
      const id = await coz('tv', isim, bolumler[0].tmdb);
      if (!id) { ozet.atlanan += bolumler.length; continue; }
      const { rowCount } = await havuz.query(
        `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
         SELECT $1, 'tv', $2, u.s, u.b, COALESCE(u.t, now())
         FROM unnest($3::int[], $4::int[], $5::timestamptz[]) AS u(s, b, t)
         ON CONFLICT DO NOTHING`,
        [userId, id,
         bolumler.map((x) => x.s), bolumler.map((x) => x.b),
         bolumler.map((x) => x.t)],
      );
      ozet.izleme += rowCount;
      // Durum: tüm bölümler izlendiyse bitirdim, değilse izliyorum
      let durum = 'izliyorum';
      if (tmdbDetay) {
        try {
          const detay = await tmdbDetay(id);
          const toplamBolum = detay?.number_of_episodes || 0;
          const izlenenSayi = (await havuz.query(
            `SELECT count(*)::int AS n FROM izlemeler
             WHERE kullanici_id=$1 AND tur='tv' AND tmdb_id=$2`,
            [userId, id])).rows[0].n;
          if (toplamBolum > 0 && izlenenSayi >= toplamBolum) durum = 'bitirdim';
        } catch { /* durum izliyorum kalır */ }
      }
      await havuz.query(
        `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum)
         VALUES ($1,'tv',$2,$3)
         ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE SET durum=$3`,
        [userId, id, durum]);
      ozet.durum += 1;
    }

    for (const [isim, bilgi] of filmler) {
      const id = await coz('movie', isim, bilgi.tmdb);
      if (!id) { ozet.atlanan += 1; continue; }
      const { rowCount } = await havuz.query(
        `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum, tarih)
         VALUES ($1,'movie',$2,0,0,COALESCE($3,now()))
         ON CONFLICT DO NOTHING`,
        [userId, id, bilgi.t]);
      ozet.izleme += rowCount;
    }
    ozet.durum += await filmDurumlariniEsitle(havuz, userId);
    return ozet;
  }

  // 2) TV Time CSV'leri (en iyi çaba, TheTVDB→TMDB eşlemeli).
  const csv = (ad) => {
    if (!metinler[ad]) return [];
    try {
      return parse(metinler[ad], { columns: true, skip_empty_lines: true, relax_column_count: true });
    } catch { return []; }
  };

  // Ülke
  for (const r of csv('user_personal_data.csv')) {
    if (r.name === 'country-code' && r.value) {
      const kod = ulkeKodundanAd(String(r.value).trim());
      if (kod) {
        await havuz.query('UPDATE kullanicilar SET ulke=COALESCE(ulke,$1) WHERE id=$2', [kod, userId]);
        ozet.profil++;
      }
      break;
    }
  }

  // TheTVDB show id → TMDB tv id önbelleği (istek içi)
  const harita = new Map();
  let findSayisi = 0;
  async function tmdb(tvdbId) {
    const anahtar = String(tvdbId);
    if (harita.has(anahtar)) return harita.get(anahtar);
    if (findSayisi >= MAX_FIND) return null;
    findSayisi++;
    let id = null;
    try { id = await tmdbFind(anahtar); } catch { id = null; }
    harita.set(anahtar, id);
    return id;
  }

  // Takip edilen diziler → durum
  for (const r of csv('followed_tv_show.csv')) {
    const tmdbId = await tmdb(r.tv_show_id);
    if (!tmdbId) { ozet.atlanan++; continue; }
    const durum = String(r.archived) === '1' ? 'bitirdim' : 'izliyorum';
    await havuz.query(
      `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum)
       VALUES ($1,'tv',$2,$3) ON CONFLICT (kullanici_id, tur, tmdb_id) DO NOTHING`,
      [userId, tmdbId, durum]);
    ozet.durum++;
  }

  // İzlenen bölümler → izlemeler. TV Time bunu iki dosyaya böler:
  //  - seen_episode_latest / watched_on_episode: sezon+bölüm + episode_id (tv_show_id YOK)
  //  - show_seen_episode_latest: tv_show_id + episode_id (sezon/bölüm YOK)
  // episode_id üzerinden birleştirip her ikisini tamamlıyoruz.
  const bolumdenDizi = new Map(); // episode_id → tvdb tv_show_id
  for (const r of csv('show_seen_episode_latest.csv')) {
    if (r.episode_id && r.tv_show_id) bolumdenDizi.set(String(r.episode_id), r.tv_show_id);
  }
  const izlemeGorulen = new Set();
  for (const ad of ['seen_episode_latest.csv', 'watched_on_episode.csv']) {
    for (const r of csv(ad)) {
      const sezon = parseInt(r.episode_season_number, 10);
      const bolum = parseInt(r.episode_number, 10);
      const tvdb = r.tv_show_id || bolumdenDizi.get(String(r.episode_id));
      if (!Number.isInteger(sezon) || !Number.isInteger(bolum) || !tvdb) {
        ozet.atlanan++;
        continue;
      }
      const tmdbId = await tmdb(tvdb);
      if (!tmdbId) { ozet.atlanan++; continue; }
      const anahtar = `${tmdbId}:${sezon}:${bolum}`;
      if (izlemeGorulen.has(anahtar)) continue;
      izlemeGorulen.add(anahtar);
      await havuz.query(
        `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
         VALUES ($1,'tv',$2,$3,$4) ON CONFLICT DO NOTHING`,
        [userId, tmdbId, sezon, bolum]);
      ozet.izleme++;
    }
  }

  // TAM bölüm geçmişi: tracking-prod-records(-v2).csv her izlenen bölümü içerir
  // (seen_episode_latest yalnızca en son bölümü tutar). series_id boştur;
  // series_name → TheTVDB id (followed'dan) → TMDB ile eşlenir.
  const isimdenTvdb = new Map();
  for (const r of csv('followed_tv_show.csv')) {
    if (r.tv_show_name && r.tv_show_id) isimdenTvdb.set(r.tv_show_name, r.tv_show_id);
  }
  for (const r of csv('show_seen_episode_latest.csv')) {
    if (r.tv_show_name && r.tv_show_id && !isimdenTvdb.has(r.tv_show_name)) {
      isimdenTvdb.set(r.tv_show_name, r.tv_show_id);
    }
  }
  // İsimle arama önbelleği (takip listesinde olmayan diziler için yedek)
  const isimTmdb = new Map();
  async function isimdenTmdb(isim) {
    if (!isim || !isim.trim() || !tmdbAra) return null;
    // "Dizi (2021)" gibi yıl ekini temizle → daha iyi eşleşme
    const temiz = isim.replace(/\s*\(\d{4}\)\s*$/, '').trim();
    if (isimTmdb.has(temiz)) return isimTmdb.get(temiz);
    if (isimTmdb.size >= MAX_FIND) return null;
    let id = null;
    try { id = await tmdbAra(temiz); } catch { id = null; }
    isimTmdb.set(temiz, id);
    return id;
  }

  ozet.isim_eslesme = 0; // isimle (fuzzy) eşleşen dizi sayısı → kullanıcı doğrulasın
  const isimleGelenler = new Set();
  const filmAdlari = new Set(); // izlenen film adları (tracking'den)
  const izlemeYeni = []; // toplu ekleme için [tmdbId, sezon, bolum]
  for (const ad of ['tracking-prod-records-v2.csv', 'tracking-prod-records.csv']) {
    for (const r of csv(ad)) {
      const sezon = parseInt(r.season_number, 10);
      const bolum = parseInt(r.episode_number, 10);
      if (!Number.isInteger(sezon) || !Number.isInteger(bolum)) {
        // Bölüm değil → film olabilir (movie_name dolu)
        const film = String(r.movie_name || '').trim();
        if (film) filmAdlari.add(film);
        continue;
      }
      const tvdb = isimdenTvdb.get(r.series_name);
      let tmdbId = tvdb ? await tmdb(tvdb) : null;
      if (!tmdbId) {
        // Takip listesinde yok → isimle ara
        tmdbId = await isimdenTmdb(r.series_name);
        if (tmdbId && !isimleGelenler.has(r.series_name)) {
          isimleGelenler.add(r.series_name);
          ozet.isim_eslesme++;
        }
      }
      if (!tmdbId) { ozet.atlanan++; continue; }
      const anahtar = `${tmdbId}:${sezon}:${bolum}`;
      if (izlemeGorulen.has(anahtar)) continue;
      izlemeGorulen.add(anahtar);
      izlemeYeni.push([tmdbId, sezon, bolum]);
    }
  }
  // Toplu ekleme (15binlerce satır olabilir): 500'lük gruplar
  for (let i = 0; i < izlemeYeni.length; i += 500) {
    const grup = izlemeYeni.slice(i, i + 500);
    const degerler = grup
      .map((_, j) => `($1,'tv',$${j * 3 + 2},$${j * 3 + 3},$${j * 3 + 4})`)
      .join(',');
    await havuz.query(
      `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
       VALUES ${degerler} ON CONFLICT DO NOTHING`,
      [userId, ...grup.flat()],
    );
    ozet.izleme += grup.length;
  }

  // İzlenen filmler → izlemeler(movie, tmdb_id, 0, 0). İsimle TMDB araması.
  ozet.film = 0;
  if (tmdbAraFilm) {
    for (const isim of filmAdlari) {
      const temiz = isim.replace(/\s*\(\d{4}\)\s*$/, '').trim();
      let filmId = null;
      try { filmId = await tmdbAraFilm(temiz); } catch { filmId = null; }
      if (!filmId) { ozet.atlanan++; continue; }
      await havuz.query(
        `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
         VALUES ($1,'movie',$2,0,0) ON CONFLICT DO NOTHING`,
        [userId, filmId]);
      ozet.film++;
    }
  }

  // Dizi/bölüm yorumları
  for (const ad of ['show_comment.csv', 'episode_comment.csv', 'comments.csv']) {
    for (const r of csv(ad)) {
      const metin = String(r.comment || r.text || '').trim();
      if (!metin || metin.length > 1000) { ozet.atlanan++; continue; }
      const tvdb = r.tv_show_id || r.tmdb_id;
      if (!tvdb) { ozet.atlanan++; continue; }
      const tmdbId = ad === 'comments.csv' ? parseInt(tvdb, 10) : await tmdb(tvdb);
      if (!tmdbId) { ozet.atlanan++; continue; }
      const sezon = r.episode_season_number != null && r.episode_season_number !== ''
        ? parseInt(r.episode_season_number, 10) : null;
      const bolum = r.episode_number != null && r.episode_number !== ''
        ? parseInt(r.episode_number, 10) : null;
      const eklendi = await yorumEkleTekil(havuz, userId, 'tv', tmdbId,
        Number.isInteger(sezon) ? sezon : null,
        Number.isInteger(bolum) ? bolum : null, metin.slice(0, 1000));
      if (eklendi) ozet.yorum++; else ozet.atlanan++;
    }
  }

  // Bitirme tespiti: bir dizinin izlenen bölüm sayısı TMDB'deki toplam bölüm
  // sayısına eşit/fazlaysa durum='bitirdim' yap (TV Time archived flag'i güvenilmez).
  ozet.bitirilen = 0;
  if (tmdbDetay) {
    const sayim = new Map(); // tmdbId → izlenen benzersiz bölüm sayısı
    for (const k of izlemeGorulen) {
      const id = k.slice(0, k.indexOf(':'));
      sayim.set(id, (sayim.get(id) || 0) + 1);
    }
    for (const [id, adet] of sayim) {
      let toplam = null;
      try { toplam = await tmdbDetay(id); } catch { toplam = null; }
      if (toplam && adet >= toplam) {
        await havuz.query(
          `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum)
           VALUES ($1,'tv',$2,'bitirdim')
           ON CONFLICT (kullanici_id, tur, tmdb_id) DO UPDATE SET durum='bitirdim'`,
          [userId, parseInt(id, 10)]);
        ozet.bitirilen++;
      }
    }
  }

  ozet.durum += await filmDurumlariniEsitle(havuz, userId);
  ozet.tmdb_eslesme = findSayisi;
  return ozet;
}

async function iceAktarNative(havuz, userId, json, ozet) {
  let veri;
  try { veri = JSON.parse(json); } catch {
    throw Object.assign(new Error('Bozuk dizijpg.json'), { status: 400 });
  }
  const tamsayi = (v) => (Number.isInteger(v) ? v : null);
  const turGecerli = (t) => ['tv', 'movie', 'person'].includes(t);

  // Profil
  if (veri.kullanici) {
    const bio = typeof veri.kullanici.bio === 'string' ? veri.kullanici.bio.slice(0, 300) : null;
    const ulke = typeof veri.kullanici.ulke === 'string' ? veri.kullanici.ulke.slice(0, 60) : null;
    if (bio || ulke) {
      await havuz.query(
        'UPDATE kullanicilar SET bio=COALESCE(bio,$1), ulke=COALESCE(ulke,$2) WHERE id=$3',
        [bio, ulke, userId]);
      ozet.profil++;
    }
  }
  for (const d of (veri.durumlar || []).slice(0, 5000)) {
    if (!tamsayi(d.tmdb_id) || !['tv', 'movie'].includes(d.tur)) { ozet.atlanan++; continue; }
    if (!['izleyecegim', 'izliyorum', 'bitirdim', 'biraktim'].includes(d.durum)) { ozet.atlanan++; continue; }
    await havuz.query(
      `INSERT INTO durumlar (kullanici_id, tur, tmdb_id, durum)
       VALUES ($1,$2,$3,$4) ON CONFLICT (kullanici_id, tur, tmdb_id) DO NOTHING`,
      [userId, d.tur, d.tmdb_id, d.durum]);
    ozet.durum++;
  }
  // İzlemeler (100k'ya kadar) TOPLU eklenir: tek tek INSERT = 100k round-trip
  // = DB havuzunu tıkayan DoS. 500'lük çok-satırlı VALUES ile gruplanır.
  const izlemeGecerli = [];
  for (const i of (veri.izlemeler || []).slice(0, 100000)) {
    if (!tamsayi(i.tmdb_id) || !['tv', 'movie'].includes(i.tur)) { ozet.atlanan++; continue; }
    izlemeGecerli.push([i.tur, i.tmdb_id, tamsayi(i.sezon) ?? 0, tamsayi(i.bolum) ?? 0]);
  }
  for (let g = 0; g < izlemeGecerli.length; g += 500) {
    const grup = izlemeGecerli.slice(g, g + 500);
    const parametreler = [userId];
    const degerler = grup.map((r, j) => {
      const b = j * 4;
      parametreler.push(r[0], r[1], r[2], r[3]);
      return `($1,$${b + 2},$${b + 3},$${b + 4},$${b + 5})`;
    });
    await havuz.query(
      `INSERT INTO izlemeler (kullanici_id, tur, tmdb_id, sezon, bolum)
       VALUES ${degerler.join(',')} ON CONFLICT DO NOTHING`,
      parametreler);
    ozet.izleme += grup.length;
  }
  for (const p of (veri.puanlar || []).slice(0, 5000)) {
    if (!tamsayi(p.tmdb_id) || !turGecerli(p.tur)) { ozet.atlanan++; continue; }
    const puan = tamsayi(p.puan);
    if (!puan || puan < 1 || puan > 10) { ozet.atlanan++; continue; }
    const yorum = typeof p.yorum === 'string' ? p.yorum.slice(0, 2000) : null;
    // BÖLÜM HEDEFİ (8 Ağu 2026-d): sezon+bolum ya İKİSİ birden ya hiç; bölüm
    // yalnız 'tv'de olur. Yarım/geçersiz hedef DB'deki CHECK'lere takılıp tüm
    // içe aktarımı düşüreceği için burada içerik GENELİNE indirgenir.
    let sezon = tamsayi(p.sezon);
    let bolum = tamsayi(p.bolum);
    if (sezon == null || bolum == null || sezon < 0 || bolum < 0
        || p.tur !== 'tv') {
      sezon = null;
      bolum = null;
    }
    // ON CONFLICT artık İFADELİ: `puanlar_pkey` yerini `puanlar_tekil`
    // (COALESCE(sezon,-1), COALESCE(bolum,-1)) tekil indeksine bıraktı. Eski
    // sütun listesi yazılırsa PostgreSQL 42P10 verir ve içe aktarım komple
    // düşer — test/bolum_puani.test.js bu satırı denetler.
    await havuz.query(
      `INSERT INTO puanlar (kullanici_id, tur, tmdb_id, sezon, bolum, puan, yorum)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (kullanici_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1))
       DO NOTHING`,
      [userId, p.tur, p.tmdb_id, sezon, bolum, puan, yorum]);
    ozet.puan++;
  }
  for (const y of (veri.yorumlar || []).slice(0, 5000)) {
    if (!tamsayi(y.tmdb_id) || !turGecerli(y.tur)) { ozet.atlanan++; continue; }
    const metin = typeof y.metin === 'string' ? y.metin.trim().slice(0, 1000) : '';
    if (!metin) { ozet.atlanan++; continue; }
    const eklendi = await yorumEkleTekil(
      havuz, userId, y.tur, y.tmdb_id, tamsayi(y.sezon), tamsayi(y.bolum), metin);
    if (eklendi) ozet.yorum++; else ozet.atlanan++;
  }
  for (const f of (veri.favoriler || []).slice(0, 5000)) {
    if (!tamsayi(f.tmdb_id) || !['tv', 'movie'].includes(f.tur)) { ozet.atlanan++; continue; }
    await havuz.query(
      `INSERT INTO favoriler (kullanici_id, tur, tmdb_id) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
      [userId, f.tur, f.tmdb_id]);
  }
  for (const l of (veri.listeler || []).slice(0, 500)) {
    if (typeof l.ad !== 'string' || !l.ad.trim()) { ozet.atlanan++; continue; }
    const { rows } = await havuz.query(
      `INSERT INTO listeler (kullanici_id, ad, aciklama, herkese_acik)
       VALUES ($1,$2,$3,$4) RETURNING id`,
      [userId, l.ad.slice(0, 120), typeof l.aciklama === 'string' ? l.aciklama.slice(0, 500) : '',
        l.herkese_acik !== false]);
    const listeId = rows[0].id;
    for (const o of (l.ogeler || []).slice(0, 5000)) {
      if (!tamsayi(o.tmdb_id) || !['tv', 'movie'].includes(o.tur)) continue;
      await havuz.query(
        `INSERT INTO liste_ogeleri (liste_id, tmdb_id, tur) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
        [listeId, o.tmdb_id, o.tur]);
    }
    ozet.liste++;
  }
  // Düzeltme öncesi alınmış yedeklerde film durumları eksik olabilir.
  ozet.durum += await filmDurumlariniEsitle(havuz, userId);
  return ozet;
}

// TV Time country-code (ISO-2) → dizi.jpg ülke adı. Bulunamazsa null.
const ULKE_KODLARI = {
  tr: 'Türkiye', de: 'Almanya', us: 'Amerika Birleşik Devletleri', gb: 'Birleşik Krallık',
  fr: 'Fransa', nl: 'Hollanda', it: 'İtalya', es: 'İspanya', az: 'Azerbaycan',
  ru: 'Rusya', ua: 'Ukrayna', at: 'Avusturya', be: 'Belçika', ch: 'İsviçre',
  se: 'İsveç', no: 'Norveç', dk: 'Danimarka', fi: 'Finlandiya', pl: 'Polonya',
  gr: 'Yunanistan', bg: 'Bulgaristan', ro: 'Romanya', jp: 'Japonya', kr: 'Güney Kore',
  cn: 'Çin', in: 'Hindistan', br: 'Brezilya', ca: 'Kanada', au: 'Avustralya',
  sa: 'Suudi Arabistan', ae: 'Birleşik Arap Emirlikleri', eg: 'Mısır', ir: 'İran',
  iq: 'Irak', cy: 'Kıbrıs', pt: 'Portekiz', cz: 'Çekya', hu: 'Macaristan',
};
function ulkeKodundanAd(kod) {
  return ULKE_KODLARI[String(kod).toLowerCase()] || null;
}

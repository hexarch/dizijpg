// dizi.jpg — depolama & yedek durumu (admin paneli "Depolama" sekmesi)
//
// Medya diski projenin EN HIZLI büyüyen kalemi (3 Ağu: 5.7 GB) ama panelde
// hiç görünmüyordu. Burada: dizin boyutları, en büyük dosyalar, DB'de artık
// referansı olmayan ÖKSÜZ dosyalar ve gecelik yedeğin durumu.
import fs from 'fs';
import path from 'path';

// Bir dizini tarar: toplam boyut, dosya sayısı, en büyükler, en eski/yeni.
// Alt dizin beklenmiyor (yükleme ucu düz yazıyor) ama varsa özyineler.
export function dizinOzet(dizin, enBuyukAdet = 20) {
  const cikti = {
    dizin, var_mi: false, dosya: 0, boyut: 0, en_buyukler: [], en_eski: null, en_yeni: null,
  };
  let girdiler;
  try { girdiler = fs.readdirSync(dizin, { withFileTypes: true }); } catch { return cikti; }
  cikti.var_mi = true;
  const hepsi = [];
  const yiginlar = [{ dizin, girdiler }];
  while (yiginlar.length) {
    const { dizin: d, girdiler: g } = yiginlar.pop();
    for (const e of g) {
      const yol = path.join(d, e.name);
      if (e.isDirectory()) {
        try { yiginlar.push({ dizin: yol, girdiler: fs.readdirSync(yol, { withFileTypes: true }) }); }
        catch { /* okunamayan alt dizini atla */ }
        continue;
      }
      let st;
      try { st = fs.statSync(yol); } catch { continue; }
      hepsi.push({ ad: e.name, boyut: st.size, mtime: st.mtimeMs });
      cikti.boyut += st.size;
      cikti.dosya += 1;
    }
  }
  hepsi.sort((a, b) => b.boyut - a.boyut);
  cikti.en_buyukler = hepsi.slice(0, enBuyukAdet);
  if (hepsi.length) {
    const zaman = [...hepsi].sort((a, b) => a.mtime - b.mtime);
    cikti.en_eski = zaman[0].mtime;
    cikti.en_yeni = zaman[zaman.length - 1].mtime;
  }
  return cikti;
}

// Uzantıya göre kırılım: videonun mu fotoğrafın mı şiştiği tek bakışta görünsün.
export function turDagilimi(dizin) {
  const gruplar = {};
  let girdiler;
  try { girdiler = fs.readdirSync(dizin, { withFileTypes: true }); } catch { return []; }
  for (const e of girdiler) {
    if (!e.isFile()) continue;
    let st;
    try { st = fs.statSync(path.join(dizin, e.name)); } catch { continue; }
    const uzanti = (path.extname(e.name) || '.yok').toLowerCase();
    gruplar[uzanti] = gruplar[uzanti] || { uzanti, dosya: 0, boyut: 0 };
    gruplar[uzanti].dosya += 1;
    gruplar[uzanti].boyut += st.size;
  }
  return Object.values(gruplar).sort((a, b) => b.boyut - a.boyut);
}

// Diskteki dosyalardan DB'de referansı OLMAYANLAR.
// `referanslar`: kullanılan dosya adları kümesi (yol değil, yalnız ad).
// yasSaat: bu kadar saatten YENİ dosyalar öksüz sayılmaz — yükleme yapılıp
// henüz yoruma iliştirilmemiş dosya yanlışlıkla silinmesin (yarış durumu).
export function oksuzler(dizin, referanslar, yasSaat = 24) {
  const sinir = Date.now() - yasSaat * 3600 * 1000;
  const cikti = { dosya: 0, boyut: 0, ornekler: [], adlar: [] };
  let girdiler;
  try { girdiler = fs.readdirSync(dizin, { withFileTypes: true }); } catch { return cikti; }
  for (const e of girdiler) {
    if (!e.isFile() || referanslar.has(e.name)) continue;
    let st;
    try { st = fs.statSync(path.join(dizin, e.name)); } catch { continue; }
    if (st.mtimeMs > sinir) continue;
    cikti.dosya += 1;
    cikti.boyut += st.size;
    cikti.adlar.push(e.name);
    if (cikti.ornekler.length < 50) {
      cikti.ornekler.push({ ad: e.name, boyut: st.size, mtime: st.mtimeMs });
    }
  }
  return cikti;
}

// Öksüzleri siler. GÜVENLİK: yalnızca `adlar` listesindeki, dizinde DOĞRUDAN
// duran (yol ayıracı içermeyen) ve hâlâ referanssız dosyalar silinir.
export function oksuzSil(dizin, adlar, referanslar, yasSaat = 24) {
  const sinir = Date.now() - yasSaat * 3600 * 1000;
  let silinen = 0;
  let boyut = 0;
  const hatalar = [];
  for (const ad of adlar) {
    if (typeof ad !== 'string' || ad.includes('/') || ad.includes('\\')
        || ad === '.' || ad === '..' || referanslar.has(ad)) {
      hatalar.push(ad);
      continue;
    }
    const yol = path.join(dizin, ad);
    // path.join sonrası dizinin İÇİNDE mi? (ad '..' içeremez ama kemer+askı)
    if (path.dirname(path.resolve(yol)) !== path.resolve(dizin)) { hatalar.push(ad); continue; }
    try {
      const st = fs.statSync(yol);
      if (!st.isFile() || st.mtimeMs > sinir) { hatalar.push(ad); continue; }
      fs.unlinkSync(yol);
      silinen += 1;
      boyut += st.size;
    } catch { hatalar.push(ad); }
  }
  return { silinen, boyut, atlanan: hatalar.length };
}

// Gecelik yedeğin durumu (yedekler dizini salt-okunur bağlanır).
// Sessizce bozulan cron'u panelde görebilmek için: son yedek ne zaman, kaç
// tane var, toplam ne kadar yer tutuyor.
export function yedekDurumu(dizin, gunlukDosya = null) {
  const cikti = { var_mi: false, adet: 0, boyut: 0, son: null, dosyalar: [], gunluk: null };
  let adlar;
  try { adlar = fs.readdirSync(dizin); } catch { return cikti; }
  cikti.var_mi = true;
  const dosyalar = [];
  for (const ad of adlar) {
    if (!/\.(sql|dump)\.gz$/.test(ad)) continue;
    try {
      const st = fs.statSync(path.join(dizin, ad));
      if (!st.isFile()) continue;
      dosyalar.push({ ad, boyut: st.size, mtime: st.mtimeMs });
      cikti.boyut += st.size;
    } catch { /* okunamayanı atla */ }
  }
  dosyalar.sort((a, b) => b.mtime - a.mtime);
  cikti.adet = dosyalar.length;
  cikti.dosyalar = dosyalar.slice(0, 20);
  cikti.son = dosyalar[0] || null;
  if (gunlukDosya) {
    try {
      const ham = fs.readFileSync(gunlukDosya, 'utf8').trimEnd().split('\n');
      cikti.gunluk = ham.slice(-8);
    } catch { /* günlük yoksa boş */ }
  }
  return cikti;
}

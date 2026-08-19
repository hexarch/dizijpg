#!/usr/bin/env node
// dizi.jpg — `flutter build web` ÇIKTISINI hash'ler (dağıtım ritüelinde 3.5. adım).
//
// NEDEN: `main.dart.js` her derlemede değiştiği için nginx'te bilerek
// `no-store` veriliyordu — yoksa kullanıcılar eski derlemede kilitleniyordu.
// Ama bunun bedeli ağır: Cloudflare `cf-cache-status: BYPASS` veriyor, önbelleğe
// almadığı yanıta Brotli de uygulamıyor. Ölçüm (6 Ağu 2026): her ziyaretçi
// 1.685.335 bayt'ı gzip'le ve ORIGIN'den çekiyordu.
//
// ÇÖZÜM: dosya adına içerik hash'i koy. İçerik değişince ad değişir, yani eski
// sürüm servis edilme riski YOK; buna karşılık dosya sonsuza kadar önbelleklenebilir.
// Bu, `no-store`u kaldırmanın TEK güvenli yolu — süreyi uzatmak değil.
//
// 19 Ağu 2026 — ERTELENMİŞ PARÇALAR (`main.dart.js_<n>.part.js`):
// `pro_image_editor` deferred import'a alınınca dart2js ana paketten ayrı bir
// parça dosyası üretmeye başladı (bugün 1 tane, 2,8 MB). Bu dosya hash'lenmezse
// adı sabit kalır; nginx'te hiçbir kurala düşmediği için Cloudflare onu
// varsayılan `.js` davranışıyla önbelleğe alır ve YENİ derlemeden sonra ESKİ
// parçayı servis edebilir. dart2js parçanın içine gömülü kimliği
// (`deferredPartHashes`) ana pakette tuttuğu için uyumsuz parça sessizce
// yüklenmez: görsel düzenleyici canlıda ölür. Bu yüzden parçalar da hash'lenir.
//
// Kullanım:  node araclar/web_hashla.js [build/web dizini]
// Varsayılan dizin: app/build/web

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const kok = process.argv[2]
  || path.join(__dirname, '..', 'app', 'build', 'web');

const ANA = 'main.dart.js';
const ONYUKLEYICI = 'flutter_bootstrap.js';

// Ana paket: hash'siz (taze derleme) ve hash'li (bu betik bir kez koşmuş) hâli.
const ANA_HASHLI = /^main\.[0-9a-f]{12}\.dart\.js$/;
// Parçalar: `main.dart.js_1.part.js` (taze) ve `main.dart.js_1.<hash>.part.js`.
// SAYIYA GÖMÜLME: bugün 1 parça var, yarın 5 olabilir — indeks desenle okunur.
const PARCA_HAM = /^main\.dart\.js_(\d+)\.part\.js$/;
const PARCA_HASHLI = /^main\.dart\.js_(\d+)\.([0-9a-f]{12})\.part\.js$/;

function cik(mesaj) {
  console.error(`web_hashla: ${mesaj}`);
  process.exit(1);
}

function hashla(tampon) {
  return crypto.createHash('sha256').update(tampon).digest('hex').slice(0, 12);
}

if (!fs.existsSync(kok)) cik(`dizin yok: ${kok}`);
const dosyalar = fs.readdirSync(kok).sort();

// --- 1) Ana paketin KAYNAĞINI bul ------------------------------------------
//
// İDEMPOTENT: betik ikinci kez koşarsa `main.dart.js` artık yoktur (birincide
// hash'li ada dönüştü). Eskiden bu durum "önce flutter build web çalıştırın"
// diye hataya düşüyordu; dağıtım ritüelinde betiği iki kez koşmak sık olduğu
// için bu YANLIŞ ALARM'dı. Tek bir hash'li ana paket varsa onu kaynak say.
let anaAd = null;
if (dosyalar.includes(ANA)) {
  anaAd = ANA;
} else {
  const hashliAnalar = dosyalar.filter((a) => ANA_HASHLI.test(a));
  if (hashliAnalar.length === 1) {
    anaAd = hashliAnalar[0];
  } else if (hashliAnalar.length === 0) {
    cik(`${path.join(kok, ANA)} yok — önce flutter build web çalıştırın`);
  } else {
    // Hangisinin güncel olduğu belirsiz; tahmin etmek eski paketi canlıya
    // sokabilir. SESSİZ GEÇME.
    cik(`birden fazla hash'li ana paket var (${hashliAnalar.join(', ')}) — `
      + `hangisinin güncel olduğu belirsiz, build dizinini temizleyip yeniden derleyin`);
  }
}

const onyukleyiciYol = path.join(kok, ONYUKLEYICI);
if (!fs.existsSync(onyukleyiciYol)) cik(`${onyukleyiciYol} yok`);

const anaYol = path.join(kok, anaAd);
// Parça adları ana paketin İÇİNDE düz metin olarak geçtiği için ana paketi
// metin olarak okuyup üzerinde çalışıyoruz (dart2js çıktısı UTF-8).
let anaIcerik = fs.readFileSync(anaYol, 'utf8');

// --- 2) Parçaları indeks indeks topla ---------------------------------------
const parcalar = new Map(); // indeks -> { ham, hashliler: [] }
for (const ad of dosyalar) {
  let e = ad.match(PARCA_HAM);
  if (e) {
    const kayit = parcalar.get(e[1]) || { ham: null, hashliler: [] };
    kayit.ham = ad;
    parcalar.set(e[1], kayit);
    continue;
  }
  e = ad.match(PARCA_HASHLI);
  if (e) {
    const kayit = parcalar.get(e[1]) || { ham: null, hashliler: [] };
    kayit.hashliler.push(ad);
    parcalar.set(e[1], kayit);
  }
}

// --- 3) Parçaları hash'le ve ana paketteki referansları yeniden yaz ----------
//
// SIRALAMA — KRİTİK: referans ana paketin İÇİNDE (`deferredPartUris:[...]`)
// duruyor. Ana paketi önce hash'leyip sonra içine dokunursak, dosyanın adındaki
// hash artık İÇERİĞİYLE UYUŞMAZ; "aynı ad ⇒ aynı içerik" garantisi çöker ve
// `immutable` verdiğimiz Cloudflare bir sonraki derlemede aynı adla ESKİ gövdeyi
// sonsuza kadar tutabilir. Bu yüzden sıra ZORUNLU olarak:
//   (a) parçaları hash'le → (b) ana paket metnindeki parça adlarını güncelle →
//   (c) ana paketin hash'ini ARTIK KESİNLEŞMİŞ içerikten al → (d) yaz.
// Not: `deferredPartHashes` içindeki değer parçanın İÇİNE gömülü kimliktir
// (parça dosyasının sonundaki `$__dart_deferred_initializers__["..."]` anahtarı),
// dosya adından bağımsızdır — yeniden adlandırma onu bozmaz.
const parcaOzet = [];
for (const indeks of [...parcalar.keys()].sort((a, b) => Number(a) - Number(b))) {
  const kayit = parcalar.get(indeks);

  // Bu indekse yapılan HER referans (hash'siz ya da eski hash'li).
  const refDeseni = new RegExp(
    `main\\.dart\\.js_${indeks}\\.(?:[0-9a-f]{12}\\.)?part\\.js`, 'g');
  const refAdet = (anaIcerik.match(refDeseni) || []).length;

  if (refAdet === 0) {
    if (kayit.ham) {
      // Taze derleme parça üretmiş ama ana pakette adı geçmiyor: dart2js çıktı
      // biçimi değişmiş olabilir. SESSİZ GEÇME — parça hash'lenmeden dağıtılırsa
      // Cloudflare bayat gövde servis eder ve düzenleyici canlıda ölür.
      cik(`${kayit.ham} üretilmiş ama ${anaAd} içinde referansı YOK — `
        + `dart2js çıktı biçimi değişmiş olabilir, elle bakın`);
    }
    // Ham kaynağı olmayan + ana pakette hiç anılmayan hash'li parça: önceki
    // derlemeden artakalan. Temizle (birikirse dağıtım her seferinde şişer).
    for (const eski of kayit.hashliler) {
      fs.unlinkSync(path.join(kok, eski));
      console.log(`  eski hash'li parça silindi (referansı kalmamış): ${eski}`);
    }
    continue;
  }

  // Kaynak seçimi: taze `ham` varsa o, yoksa (ikinci çalıştırma) tek hash'li.
  let kaynak = kayit.ham;
  if (!kaynak) {
    if (kayit.hashliler.length !== 1) {
      cik(`main.dart.js_${indeks}.part.js yok ve hash'li karşılığı belirsiz `
        + `(${kayit.hashliler.length} aday: ${kayit.hashliler.join(', ') || 'yok'})`);
    }
    kaynak = kayit.hashliler[0];
  }

  const parcaHash = hashla(fs.readFileSync(path.join(kok, kaynak)));
  const yeniParcaAd = `main.dart.js_${indeks}.${parcaHash}.part.js`;

  anaIcerik = anaIcerik.replace(refDeseni, yeniParcaAd);

  // Aynı indeksin eski hash'li kopyaları birikmesin (ana paketle aynı desen).
  for (const eski of kayit.hashliler) {
    if (eski !== yeniParcaAd && eski !== kaynak) {
      fs.unlinkSync(path.join(kok, eski));
      console.log(`  eski hash'li parça silindi: ${eski}`);
    }
  }
  if (kaynak !== yeniParcaAd) {
    fs.renameSync(path.join(kok, kaynak), path.join(kok, yeniParcaAd));
  }

  parcaOzet.push(`${yeniParcaAd} (${refAdet} referans)`);
}

// Doğrula: ana pakette hash'SİZ parça adı KALMAMALI. Kalırsa nginx'te sabit
// adlı bir `.js` servis edilir ve bayat parça riski geri gelir.
if (/main\.dart\.js_\d+\.part\.js/.test(anaIcerik)) {
  cik(`${anaAd} içinde hâlâ hash'siz parça referansı var`);
}

// --- 4) Ana paketi ARTIK kesinleşmiş içerikten hash'le ----------------------
const hash = hashla(Buffer.from(anaIcerik, 'utf8'));
const yeniAd = `main.${hash}.dart.js`;

// Önce YAZ, sonra eskisini sil: ters sırada betik yarıda kesilirse ana paket
// tamamen kaybolur ve build dizini kurtarılamaz.
fs.writeFileSync(path.join(kok, yeniAd), anaIcerik);
if (anaAd !== yeniAd) fs.unlinkSync(anaYol);

// Önceki çalıştırmalardan kalan hash'li dosyalar birikmesin: build dizini her
// derlemede yeniden üretilmiyor olabilir.
for (const ad of fs.readdirSync(kok)) {
  if (ANA_HASHLI.test(ad) && ad !== yeniAd) {
    fs.unlinkSync(path.join(kok, ad));
    console.log(`  eski hash'li dosya silindi: ${ad}`);
  }
}

// --- 5) flutter_bootstrap.js -----------------------------------------------
// Ad ÜÇ yerde geçiyor (mainJsPath varsayılanı, derleme yapılandırması,
// yükleyici). Hepsi değişmeli — biri kalırsa 404.
// Desendeki `(?!_)`: `main.dart.js_1.part.js` de `main.dart.js` ile başlıyor;
// düz metin değiştirme onu `main.<hash>.dart.js_1.part.js`e çevirip bozardı.
// İDEMPOTENT: ikinci çalıştırmada dosyada zaten hash'li ad vardır, o da eşleşir.
const ONY_DESEN = /main\.(?:[0-9a-f]{12}\.)?dart\.js(?!_)/g;
const onceki = fs.readFileSync(onyukleyiciYol, 'utf8');
const adet = (onceki.match(ONY_DESEN) || []).length;
if (!adet) cik(`${ONYUKLEYICI} içinde "main.dart.js" geçmiyor — Flutter çıktısı değişmiş olabilir`);
fs.writeFileSync(onyukleyiciYol, onceki.replace(ONY_DESEN, yeniAd));

// Doğrula: artık hiçbir yerde hash'siz ad kalmamalı.
const sonra = fs.readFileSync(onyukleyiciYol, 'utf8');
if (/(^|[^.0-9a-f])main\.dart\.js(?!_)/.test(sonra)) {
  cik(`${ONYUKLEYICI} içinde hâlâ hash'siz "main.dart.js" var`);
}

// --- 6) index.html'e ana paket ÖN YÜKLEMESİ ---------------------------------
//
// NEDEN: `main.<hash>.dart.js` yalnız `flutter_bootstrap.js` ÇALIŞTIKTAN sonra
// keşfediliyor. Lighthouse ölçümü (mobil): istek `Low` öncelikle ve ancak
// 496 ms'de başlıyor; 2,07 MB'lık paket o sırada CanvasKit ile bant genişliği
// için yarışıyor. `<head>` içindeki bir preload satırı, ayrıştırıcı HTML'i
// okurken indirmeyi başlatır ve `fetchpriority="high"` ile CanvasKit'in önüne
// geçirir — yani ilk boya, betik hiç çalışmadan önce kazanılmış olur.
//
// Ad hash'li olduğu için bu satır her derlemede DEĞİŞMEK zorunda: elle
// yazılamaz, hash'i üreten yer olan bu betik yazmalı.
//
// Parçalar BİLEREK preload EDİLMEZ: ertelenmiş import'un bütün amacı 2,8 MB'ı
// ilk açılıştan çıkarmak; preload onu geri getirir.
const INDEKS = 'index.html';
const indeksYol = path.join(kok, INDEKS);
if (!fs.existsSync(indeksYol)) cik(`${indeksYol} yok`);

const onyukSatiri =
  `  <link rel="preload" href="${yeniAd}" as="script" fetchpriority="high">`;

// `<base href>` göreli çözüldüğü için yol BAŞINDA `/` OLMADAN yazılır —
// tıpkı yukarıdaki `logo.png` preload'u gibi.
let indeks = fs.readFileSync(indeksYol, 'utf8');

// IDEMPOTENT: betik iki kez koşarsa ikinci satır girmemeli. index.html'i
// normalde `flutter build` yeniden üretiyor ama buna GÜVENME — build dizini
// olduğu gibi dururken tekrar çalıştırmak dağıtım ritüelinde sık oluyor.
// Eski hash'li preload satırlarının hepsi tek satıra indirgenir.
const eskiOnyuk = /[ \t]*<link\b[^>]*\brel=["']preload["'][^>]*\bmain\.[0-9a-f]{12}\.dart\.js[^>]*>[ \t]*\r?\n?/g;
const eskiAdet = (indeks.match(eskiOnyuk) || []).length;
let onyukDurum;
if (eskiAdet) {
  let ilk = true;
  indeks = indeks.replace(eskiOnyuk, () => (ilk ? ((ilk = false), `${onyukSatiri}\n`) : ''));
  onyukDurum = `güncellendi (${eskiAdet} eski satır)`;
} else {
  // `</head>` yoksa Flutter şablonu değişmiş demektir; SESSİZ GEÇME —
  // eksik preload dağıtımın ortasında kimsenin gözüne çarpmaz.
  if (!/<\/head>/i.test(indeks)) {
    cik(`${INDEKS} içinde </head> yok — preload enjekte edilemedi`);
  }
  let eklendi = false;
  indeks = indeks.replace(/<\/head>/i, (esles) =>
    eklendi ? esles : ((eklendi = true), `${onyukSatiri}\n</head>`));
  onyukDurum = 'eklendi';
}

fs.writeFileSync(indeksYol, indeks);

// Doğrula: yazdıktan sonra TAM olarak bir preload satırı olmalı ve içindeki ad
// bu çalıştırmanın hash'iyle eşleşmeli.
const indeksSon = fs.readFileSync(indeksYol, 'utf8');
const sonAdet = (indeksSon.match(eskiOnyuk) || []).length;
if (sonAdet !== 1 || !indeksSon.includes(onyukSatiri.trim())) {
  cik(`${INDEKS} preload doğrulaması başarısız (${sonAdet} satır bulundu, beklenen 1: ${yeniAd})`);
}

console.log(`web_hashla: ${anaAd} -> ${yeniAd} (${adet} referans güncellendi)`);
if (parcaOzet.length) {
  console.log(`web_hashla: ertelenmiş parça: ${parcaOzet.join(', ')}`);
} else {
  console.log('web_hashla: ertelenmiş parça yok');
}
console.log(`web_hashla: ${INDEKS} preload satırı ${onyukDurum}: ${yeniAd}`);

// Bölüm bazlı puanlama testleri — `node --test backend/test/*.test.js`
//
// KORUNAN KARARLAR (8 Ağu 2026-d, istek listesi md. 11):
//
//  1) `puanlar.sezon/bolum` NULL = dizi/film/kişi geneli, dolu = O BÖLÜM
//     (`yorumlar`/`tepkiler` ile aynı kalıp).
//  2) BÖLÜM PUANI DİZİNİN ORTALAMASINA GİRMEZ. `puanlar` üzerindeki HER SQL
//     `sezon`dan söz etmek ZORUNDA — süzgeçsiz eklenen yeni bir sorgu bölüm
//     puanlarını SEO aggregateRating'e, rozet sayaçlarına ve puan uyumuna
//     sessizce karıştırırdı. Aşağıdaki tarayıcı tam da bunu yakalar.
//  3) Tekil anahtar PRIMARY KEY değil `puanlar_tekil` İFADELİ indekstir;
//     ON CONFLICT yazan her yer ifadeli biçimi kullanmak zorunda (eski sütun
//     listesi PostgreSQL 42P10 verir ve içe aktarımı komple düşürür).
//  4) Mevcut (canlıda 265) satır bozulmaz: migrasyon DEFAULT'suz ADD COLUMN
//     kullanır, veri yazmaz, veri silmez.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (seo_gizlilik.test.js ile aynı gerekçe). Saf yardımcı `puanHedef` kaynaktan
// ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const AKTAR = oku('veri_aktar.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-08d.sql');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (seo_gizlilik.test.js'teki kalıp)
// ---------------------------------------------------------------------------
function bildirimCek(kaynak, ad) {
  const m = new RegExp(`^(const|function) ${ad}\\b`, 'm').exec(kaynak);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; } else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return kaynak.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return kaynak.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

const puanHedef = new Function(
  `${bildirimCek(KAYNAK, 'gecerliTmdb')}\n${bildirimCek(KAYNAK, 'puanHedef')}\nreturn puanHedef;`,
)();

// ---------------------------------------------------------------------------
// SQL metin literallerini ayıklayan küçük tarayıcı
// ---------------------------------------------------------------------------
/**
 * Kaynaktaki TÜM metin literalleri (', ", `).
 *
 * Tek geçişli gerçek tarayıcı: yorumları, kaçış dizilerini ve REGEX
 * literallerini atlar. Naif "tırnak ara" yaklaşımı bu dosyada çalışmaz —
 * SQL şablonlarının içindeki `WHERE tur='tv'` tek tırnakları, ayrı geçişte
 * sahte metin sınırları üretip sorguları ortadan ikiye böler.
 */
// `/` bölme mi regex mi: bu karakterlerden ya da bu anahtar kelimelerden
// SONRA gelen `/` daima bir regex literalidir. (`return /[",\n]/.test(s)`
// kalıbı veri_aktar.js'te GERÇEKTEN var ve kelime listesi olmadan tarayıcı
// regex içindeki tırnağı metin başlangıcı sanıp dosyanın yarısını yutuyor.)
const REGEX_ONCESI = /[(,=:[!&|?{};+\-*%~^<>]/;
const REGEX_KELIMELERI = new Set([
  'return', 'typeof', 'case', 'in', 'of', 'do', 'else', 'yield', 'await',
  'new', 'delete', 'void', 'instanceof',
]);

function metinLiteralleri(kaynak) {
  const cikti = [];
  // Açık ŞABLON literalleri yığını. İÇ İÇE ŞABLON server.js'te GERÇEKTEN var
  // (`seoYorumHtml`: `${puan ? ` — ...` : ''}`); yığınsız tarayıcı iç şablonun
  // açılış ters tırnağını KAPANIŞ sanıp dosyanın geri kalanını kaydırıyor.
  const yigin = [];
  let suslu = 0; // açık `{` derinliği (şablonun ifade bloğunu kapatmak için)
  let i = 0;
  let onceki = ''; // son anlamlı karakter
  let kelime = ''; // son tanımlayıcı/anahtar kelime
  while (i < kaynak.length) {
    const ust = yigin.length ? yigin[yigin.length - 1] : null;
    const c = kaynak[i];

    // --- şablonun METİN kısmındayız ---
    if (ust && ust.metinKipi) {
      if (c === '\\') { i += 2; continue; }
      if (c === '`') {
        ust.parcalar.push(kaynak.slice(ust.bas, i));
        // Parçalar boşlukla birleşir: `${...}` ile bölünen tek bir SQL
        // metni tek parça gibi incelensin.
        cikti.push(ust.parcalar.join(' '));
        yigin.pop();
        i++; onceki = '`'; kelime = '';
        continue;
      }
      if (c === '$' && kaynak[i + 1] === '{') {
        ust.parcalar.push(kaynak.slice(ust.bas, i));
        ust.metinKipi = false;
        ust.suslu = suslu;
        suslu++;
        i += 2; onceki = '{'; kelime = '';
        continue;
      }
      i++;
      continue;
    }

    // --- normal kod kipi ---
    if (c === '/' && kaynak[i + 1] === '/') {
      const n = kaynak.indexOf('\n', i);
      i = n < 0 ? kaynak.length : n;
      continue;
    }
    if (c === '/' && kaynak[i + 1] === '*') {
      const n = kaynak.indexOf('*/', i + 2);
      i = n < 0 ? kaynak.length : n + 2;
      continue;
    }
    if (c === '`') {
      yigin.push({ parcalar: [], bas: i + 1, metinKipi: true, suslu: 0 });
      i++;
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < kaynak.length) {
        if (kaynak[j] === '\\') { j += 2; continue; }
        if (kaynak[j] === c) break;
        j++;
      }
      cikti.push(kaynak.slice(i + 1, j));
      i = j + 1; onceki = c; kelime = '';
      continue;
    }
    if (c === '{') { suslu++; i++; onceki = '{'; kelime = ''; continue; }
    if (c === '}') {
      suslu--;
      if (ust && !ust.metinKipi && suslu === ust.suslu) {
        ust.metinKipi = true;
        ust.bas = i + 1;
        i++;
        continue;
      }
      i++; onceki = '}'; kelime = '';
      continue;
    }
    if (/[\w$]/.test(c)) {
      let j = i;
      while (j < kaynak.length && /[\w$]/.test(kaynak[j])) j++;
      kelime = kaynak.slice(i, j);
      onceki = kaynak[j - 1];
      i = j;
      continue;
    }
    if (c === '/' && (REGEX_ONCESI.test(onceki) || REGEX_KELIMELERI.has(kelime))) {
      let j = i + 1;
      let sinif = false;
      while (j < kaynak.length) {
        const d = kaynak[j];
        if (d === '\\') { j += 2; continue; }
        if (d === '[') sinif = true;
        else if (d === ']') sinif = false;
        else if (d === '\n') break;
        else if (d === '/' && !sinif) break;
        j++;
      }
      i = j + 1; onceki = '/'; kelime = '';
      continue;
    }
    if (!/\s/.test(c)) { onceki = c; kelime = ''; }
    i++;
  }
  return cikti;
}

/** `puanlar` tablosuna DOKUNAN SQL parçaları (FROM/INTO/JOIN/UPDATE). */
const puanSorgulari = (kaynak) => metinLiteralleri(kaynak)
  .filter((s) => /\b(FROM|INTO|JOIN|UPDATE)\s+puanlar\b/i.test(s));

// ---------------------------------------------------------------------------
// 1) ŞEMA
// ---------------------------------------------------------------------------
test('ŞEMA: puanlar sezon/bolum alır, kalıp tepkiler ile AYNI', () => {
  const govde = /CREATE TABLE IF NOT EXISTS puanlar \(([\s\S]*?)\n\);/.exec(SEMA);
  assert.ok(govde, 'sema.sql içinde puanlar tablosu bulunamadı');
  assert.match(govde[1], /\bsezon INT\b/, 'sezon sütunu yok');
  assert.match(govde[1], /\bbolum INT\b/, 'bolum sütunu yok');
  // NOT NULL DEFAULT 0 DEĞİL: sezon 0 gerçek bir değerdir (özel bölümler).
  assert.doesNotMatch(govde[1], /sezon INT NOT NULL/,
    'sezon NOT NULL DEFAULT olamaz: sezon 0 (özel bölümler) gerçek bir değer');
  // Tekil anahtar tepkiler_tekil ile aynı ifadeyi kullanmalı.
  assert.match(SEMA, /CREATE UNIQUE INDEX IF NOT EXISTS puanlar_tekil\s*\n?\s*ON puanlar \(kullanici_id, tur, tmdb_id, COALESCE\(sezon,-1\), COALESCE\(bolum,-1\)\)/);
  // Eski PK artık tabloda OLMAMALI (ifadeli tekil indekse dönüştü).
  assert.doesNotMatch(govde[1], /PRIMARY KEY \(kullanici_id, tur, tmdb_id\)/);
});

test('ŞEMA: yarım hedef ve film/kişi bölümü CHECK ile imkânsız', () => {
  assert.match(SEMA, /puanlar_bolum_ciftli CHECK \(\(sezon IS NULL\) = \(bolum IS NULL\)\)/);
  assert.match(SEMA, /puanlar_bolum_yalniz_tv CHECK \(sezon IS NULL OR tur = 'tv'\)/);
});

test('MİGRASYON: -08d mevcut satırları BOZMAZ (veri yazmaz/silmez)', () => {
  // ADD COLUMN ... DEFAULT verilirse PostgreSQL <11'de tablo yeniden yazılır;
  // ayrıca eski satırlara uydurma bir sezon değeri basılmış olurdu.
  // Yorum satırları çıkarılır: gerekçe metinleri komut sanılmasın.
  const komutlar = MIGRASYON.split('\n').filter((s) => !s.trim().startsWith('--')).join('\n');
  assert.match(komutlar, /ALTER TABLE puanlar ADD COLUMN IF NOT EXISTS sezon INT;/);
  assert.match(komutlar, /ALTER TABLE puanlar ADD COLUMN IF NOT EXISTS bolum INT;/);
  assert.doesNotMatch(komutlar, /ADD COLUMN[^\n;]*DEFAULT/i,
    'ADD COLUMN DEFAULT: eski satırlara veri basar');
  for (const yasak of [/\bDELETE\s+FROM\b/i, /\bUPDATE\s+puanlar\b/i,
    /\bINSERT\s+INTO\b/i, /\bDROP\s+TABLE\b/i, /\bTRUNCATE\b/i]) {
    assert.doesNotMatch(komutlar, yasak, `migrasyon veri değiştiriyor: ${yasak}`);
  }
  // PK -> ifadeli tekil indeks.
  assert.match(komutlar, /ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_pkey;/);
  assert.match(komutlar, /CREATE UNIQUE INDEX IF NOT EXISTS puanlar_tekil/);
  // PK düşünce NOT NULL açıkça geri konur.
  for (const s of ['kullanici_id', 'tmdb_id', 'tur']) {
    assert.match(komutlar,
      new RegExp(`ALTER COLUMN ${s}\\s+SET NOT NULL`),
      `${s} NOT NULL güvencesi yok`);
  }
});

// ---------------------------------------------------------------------------
// 2) HEDEF DOĞRULAMA (puanHedef canlı koddan çalıştırılıyor)
// ---------------------------------------------------------------------------
test('HEDEF: dizi geneli (sezon/bolum yok) eskisi gibi kabul', () => {
  assert.deepEqual(puanHedef({ tur: 'tv', tmdb_id: 1399 }),
    { tur: 'tv', tmdb_id: 1399, sezon: null, bolum: null });
  assert.deepEqual(puanHedef({ tur: 'movie', tmdb_id: 550 }),
    { tur: 'movie', tmdb_id: 550, sezon: null, bolum: null });
  assert.deepEqual(puanHedef({ tur: 'person', tmdb_id: 287 }),
    { tur: 'person', tmdb_id: 287, sezon: null, bolum: null });
});

test('HEDEF: bölüm puanı kabul, sezon 0 (özel bölüm) DAHİL', () => {
  assert.deepEqual(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1, bolum: 9 }),
    { tur: 'tv', tmdb_id: 1399, sezon: 1, bolum: 9 });
  assert.deepEqual(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: 0, bolum: 0 }),
    { tur: 'tv', tmdb_id: 1399, sezon: 0, bolum: 0 });
});

test('HEDEF: yarım hedef, film/kişi bölümü ve saçma değerler REDDEDİLİR', () => {
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1 }), null);
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 1399, bolum: 1 }), null);
  assert.equal(puanHedef({ tur: 'movie', tmdb_id: 550, sezon: 1, bolum: 1 }), null);
  assert.equal(puanHedef({ tur: 'person', tmdb_id: 287, sezon: 1, bolum: 1 }), null);
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: -1, bolum: 1 }), null);
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1, bolum: -1 }), null);
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: 1.5, bolum: 1 }), null);
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 1399, sezon: '1', bolum: '1' }), null);
  assert.equal(puanHedef({ tur: 'dizi', tmdb_id: 1399 }), null);
  assert.equal(puanHedef({ tur: 'tv', tmdb_id: 0 }), null);
  assert.equal(puanHedef(null), null);
});

test('HEDEF: `tepkiHedef` ile AYNI sözleşme (ikisi birden ya da hiç)', () => {
  const tepkiHedef = new Function(
    `${bildirimCek(KAYNAK, 'gecerliTmdb')}\n${bildirimCek(KAYNAK, 'tepkiHedef')}\nreturn tepkiHedef;`,
  )();
  for (const g of [
    { tur: 'tv', tmdb_id: 1399 },
    { tur: 'tv', tmdb_id: 1399, sezon: 2, bolum: 3 },
    { tur: 'tv', tmdb_id: 1399, sezon: 2 },
    { tur: 'tv', tmdb_id: 1399, sezon: -5, bolum: 1 },
  ]) {
    assert.deepEqual(puanHedef(g), tepkiHedef(g),
      `hedef sözleşmesi ayrıştı: ${JSON.stringify(g)}`);
  }
});

// ---------------------------------------------------------------------------
// 3) DİZİ GENELİ SORGULARI BÖLÜM PUANIYLA KARIŞMIYOR
// ---------------------------------------------------------------------------
test('KARIŞMA YOK: puanlar üzerindeki HER sorgu sezon hedefini belirtiyor', () => {
  const sorgular = puanSorgulari(KAYNAK);
  // Güvenlik ağı: tarayıcı bozulup 0 sorgu bulursa test sessizce yeşile
  // dönmesin (13 çağrı yeri var, sayı düşerse burada durur).
  assert.ok(sorgular.length >= 10,
    `puanlar sorgusu bulunamadı (tarayıcı bozuk?) — bulunan: ${sorgular.length}`);
  for (const s of sorgular) {
    assert.match(s, /sezon/,
      `sezon süzgeci YOK — bölüm puanı dizi geneline karışır:\n${s.trim().slice(0, 220)}`);
  }
});

test('SEO: aggregateRating ve inceleme vitrini YALNIZ dizi geneli puanı', () => {
  // Sayfada görünen ortalama + JSON-LD ratingValue aynı sorgudan gelir.
  assert.match(KAYNAK,
    /round\(avg\(puan\)::numeric, 1\)::float AS ortalama[\s\S]{0,120}FROM puanlar WHERE tur = \$1 AND tmdb_id = \$2 AND sezon IS NULL/);
  // İndeksleme kararı (ozgunIcerikVar) ve sitemap kapsamı da dizi geneli.
  assert.match(KAYNAK,
    /SELECT 1 FROM puanlar p JOIN kullanicilar k[\s\S]{0,160}p\.sezon IS NULL/);
  assert.match(KAYNAK,
    /SELECT p\.tur, p\.tmdb_id, p\.tarih[\s\S]{0,160}p\.sezon IS NULL/);
});

test('ROZET/UYUM/YIL: sayaçlar BAŞLIK sayar, bölüm sayısıyla şişmez', () => {
  assert.match(KAYNAK,
    /SELECT count\(\*\)::int FROM puanlar\s*\n?\s*WHERE kullanici_id=\$1 AND sezon IS NULL/);
  assert.match(KAYNAK,
    /FROM puanlar\s*\n\s*WHERE kullanici_id=\$1 AND sezon IS NULL AND date_part\('year', tarih\)=\$2/);
  // Puan uyumu JOIN'i İKİ TARAFTA da daraltılmalı (kartezyen çoğaltma yok).
  assert.match(KAYNAK, /a\.sezon IS NULL AND b\.sezon IS NULL/);
});

test('/benim ve /incelemeler dizi GENELİNİ döner (bölümü değil)', () => {
  assert.match(KAYNAK,
    /SELECT puan, yorum FROM puanlar\s*\n\s*WHERE kullanici_id=\$1 AND tur=\$2 AND tmdb_id=\$3 AND sezon IS NULL/);
  assert.match(KAYNAK, /WHERE p\.tur=\$1 AND p\.tmdb_id=\$2 AND p\.sezon IS NULL/);
});

// ---------------------------------------------------------------------------
// 4) YAZMA YOLU
// ---------------------------------------------------------------------------
test('YAZMA: ON CONFLICT ifadeli tekil indeksi hedefliyor (42P10 tuzağı)', () => {
  for (const [ad, kaynak] of [['server.js', KAYNAK], ['veri_aktar.js', AKTAR]]) {
    for (const s of puanSorgulari(kaynak)) {
      if (!/ON CONFLICT/i.test(s)) continue;
      assert.match(s,
        /ON CONFLICT \(kullanici_id, tur, tmdb_id, COALESCE\(sezon,-1\), COALESCE\(bolum,-1\)\)/,
        `${ad}: eski sütun listesi PostgreSQL 42P10 verir:\n${s.trim().slice(0, 220)}`);
    }
  }
});

test('YAZMA: silme de COALESCE anahtarıyla — dizi geneli silinip gitmiyor', () => {
  assert.match(KAYNAK,
    /DELETE FROM puanlar WHERE kullanici_id=\$1 AND tur=\$2 AND tmdb_id=\$3\s*\n\s*AND COALESCE\(sezon,-1\)=\$4 AND COALESCE\(bolum,-1\)=\$5/);
});

test('BÖLÜME PUAN = İZLEDİM, ama puanı silmek izlemeyi KALDIRMAZ', () => {
  const uc = /app\.post\('\/puan'[\s\S]*?\n\}\)\);/.exec(KAYNAK);
  assert.ok(uc, "POST /puan ucu bulunamadı");
  const govde = uc[0];
  // Puan verilince izleme kaydı + dizi durumu otomatiği (toggle ile aynı iki adım)
  assert.match(govde, /INSERT INTO izlemeler \(kullanici_id, tur, tmdb_id, sezon, bolum\)/);
  assert.match(govde, /diziDurumunuGuncelle\(req\.kullanici\.id, tmdb_id\)/);
  // Silme dalı ERKEN döner: izlemeler'e dokunmadan (asimetri bilinçli).
  const silmeDali = govde.slice(govde.indexOf('if (!puan)'), govde.indexOf('INSERT INTO puanlar'));
  assert.doesNotMatch(silmeDali, /izlemeler/i,
    'puan silinince izleme kaydı da siliniyor — izlediğin gerçeği kaybolmamalı');
  // Ve UI sessiz kalmasın diye yan etki yanıtta bildirilir.
  assert.match(govde, /izlendi/);
});

// ---------------------------------------------------------------------------
// 5) KULLANICI VERİSİ (KVKK/GDPR) — bölüm puanı dışa/içe aktarımda kaybolmaz
// ---------------------------------------------------------------------------
test('AKTARIM: bölüm puanları dışa aktarılıyor ve geri yükleniyor', () => {
  assert.match(AKTAR,
    /SELECT tur, tmdb_id, sezon, bolum, puan, yorum, tarih FROM puanlar WHERE kullanici_id=\$1/);
  assert.match(AKTAR, /season_number: p\.sezon \?\? ''/);
  assert.match(AKTAR, /episode_number: p\.bolum \?\? ''/);
  assert.match(AKTAR,
    /INSERT INTO puanlar \(kullanici_id, tur, tmdb_id, sezon, bolum, puan, yorum\)/);
});

// ---------------------------------------------------------------------------
// 6) BÖLÜM PUANI OKUMA UCU
// ---------------------------------------------------------------------------
test('/bolum-puanlari sezon kapsamlı ve girişsiz de çalışıyor', () => {
  const uc = /app\.get\('\/bolum-puanlari\/:tmdbId\/:sezon'[\s\S]*?\n\}\)\);/.exec(KAYNAK);
  assert.ok(uc, '/bolum-puanlari ucu yok');
  // Girişsiz ziyaretçi ortalamayı görebilmeli (yorumlar/tepkiler ile aynı).
  assert.match(uc[0], /girisIsteğeBagli/);
  // Kullanıcıya özel sorgu YALNIZ oturum varken atılır.
  assert.match(uc[0], /req\.kullanici\s*\n?\s*\?/);
  // Girdi doğrulaması (tmdb_id + sezon) atlanmamış.
  assert.match(uc[0], /gecerliTmdb\(tmdbId\)/);
  assert.match(uc[0], /Number\.isInteger\(sezon\)/);
});

test('DOCKERFILE: yeni backend modülü eklenmedi (COPY listesi bozulmadı)', () => {
  // Bölüm puanı server.js içinde çözüldü; yeni dosya EKLENSEYDİ Dockerfile
  // COPY listesine de eklenmesi gerekirdi (konteyner aksi hâlde hiç açılmaz).
  assert.doesNotMatch(KAYNAK, /from '\.\/bolum_puan/,
    'yeni modül eklendiyse Dockerfile COPY listesine de eklenmeli');
});

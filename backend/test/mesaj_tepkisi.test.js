// Özel mesajlara (DM) emoji tepkisi — sunucu tarafı. `node --test test/*.test.js`
//
// KORUNAN KARARLAR (12 Ağu 2026, migrasyon-2026-08-12b.sql · istek md. 43):
//
//  1) YETKİ — EN KRİTİK MADDE. Kullanıcı YALNIZ kendi sohbetindeki mesaja
//     tepki verebilir (gonderen_id=ben OR alici_id=ben). Kontrol düşerse bir
//     saldırgan mesaj id'lerini tarayarak (a) hangi id'lerin VAR olduğunu
//     öğrenir, (b) hiç tanımadığı iki kişinin sohbetine veri sokar.
//     Yetkisizde 404 döner (403 DEĞİL: 403 "bu id'de mesaj var" derdi).
//  2) TEPKİ EMOJİSİ ŞİFRELENMEZ — bilinçli. `mesajlar.metin` AES-256-GCM ile
//     şifreli; emoji 9 elemanlı SABİT ve HERKESE AÇIK bir kümeden tek değer
//     olduğu için şifreleme gerçek koruma vermez ama GROUP BY sayımını
//     imkânsız kılardı. Bu test `sifrele(`/`cozGoster(` sızmadığını denetler.
//  3) OKUMA AYRI UÇTAN DEĞİL: tepkiler `GET /mesajlar/:ad` yanıtıyla gelir
//     (sohbet zaten 5 sn'de bir yokluyor; ikinci uç yükü ikiye katlardı) ve
//     sayfadaki TÜM mesajlar TEK sorguda toplanır — N+1 YOK.
//  4) 9'LU LİSTE: sema.sql CHECK'i, migrasyon CHECK'i ve server.js sabiti
//     BİREBİR aynı olmalı. Ayrışırsa uç 400 yerine 23514 (CHECK ihlali) verir.
//  5) İÇERİK TEPKİLERİ (`tepkiler`, 8 emoji) DEĞİŞMEZ: orada kalp YOKTUR.
//  6) BİLDİRİM YOK (bilinçli kapsam dışı): `bildirimler.tur` CHECK'i
//     genişletilmedi, sohbet 5 sn'de bir tazeleniyor.
//
// Neden kaynak okuma + saf fonksiyon çalıştırma: `server.js` içe aktarıldığı
// anda `app.listen` çağırıyor (kisi_tepkisi.test.js / bolum_puani.test.js ile
// aynı gerekçe). Saf yardımcılar (`mesajTepkiEmojisi`, `mesajTepkiHarita`)
// kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-12b.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metinleri komut sanılmasın
// (geri alma bölümü bilerek DROP TABLE örneği içerir).
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// Beklenen küme — TESTİN KENDİSİ kaynak sayılır. Buradaki liste elle
// değiştirilmeden sema/migrasyon/server üçlüsü değiştirilemez.
const BEKLENEN = ['❤️', '😍', '😂', '😮', '😢', '😱', '🥱', '😭', '😄'];

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (kisi_tepkisi.test.js'teki kalıp)
// ---------------------------------------------------------------------------
function bildirimCek(kaynak, ad) {
  const m = new RegExp(`^(const|function|async function) ${ad}\\b`, 'm').exec(kaynak);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] !== 'const';
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

/** `app.post('/x'` ya da `app.get('/x'` ucunun gövdesi. */
function ucGovdesi(yol, yontem = 'post') {
  const m = new RegExp(
    `app\\.${yontem}\\('${yol.replace(/[/:]/g, (c) => (c === '/' ? '\\/' : c))}'[\\s\\S]*?\\n\\}\\)\\);`,
  ).exec(KAYNAK);
  assert.ok(m, `${yontem.toUpperCase()} ${yol} ucu bulunamadı`);
  return m[0];
}

/** `('a','b',...)` biçimindeki SQL dizi sabitini JS dizisine çevirir. */
function sqlListesi(metin, etiket) {
  const m = /CHECK \(emoji IN \(([^)]*)\)\)/.exec(metin);
  assert.ok(m, `${etiket}: emoji CHECK listesi bulunamadı`);
  return m[1].split(',').map((s) => s.trim().replace(/^'|'$/g, ''));
}

// Saf yardımcılar CANLI koddan çalıştırılıyor.
const mesajTepkiEmojisi = new Function(
  `${bildirimCek(KAYNAK, 'MESAJ_TEPKI_EMOJILERI')}
   ${bildirimCek(KAYNAK, 'mesajTepkiEmojisi')}
   return mesajTepkiEmojisi;`,
)();
const mesajTepkiHarita = new Function(
  `${bildirimCek(KAYNAK, 'mesajTepkiHarita')}\nreturn mesajTepkiHarita;`,
)();
const MESAJ_TEPKI_EMOJILERI = new Function(
  `${bildirimCek(KAYNAK, 'MESAJ_TEPKI_EMOJILERI')}\nreturn MESAJ_TEPKI_EMOJILERI;`,
)();

// ---------------------------------------------------------------------------
// 1) ŞEMA
// ---------------------------------------------------------------------------
test('ŞEMA: mesaj_tepkileri tablosu ve sütunları', () => {
  const g = /CREATE TABLE IF NOT EXISTS mesaj_tepkileri \(([\s\S]*?)\n\);/.exec(SEMA);
  assert.ok(g, 'sema.sql içinde mesaj_tepkileri tablosu yok');
  const govde = g[1];
  assert.match(govde,
    /mesaj_id INT NOT NULL REFERENCES mesajlar\(id\) ON DELETE CASCADE/);
  assert.match(govde,
    /kullanici_id INT NOT NULL REFERENCES kullanicilar\(id\) ON DELETE CASCADE/);
  assert.match(govde, /emoji TEXT NOT NULL/);
  assert.match(govde, /tarih TIMESTAMPTZ DEFAULT now\(\)/);
});

test('ŞEMA: CASCADE ŞART — mesaj/hesap silinince tepki de gider', () => {
  const g = /CREATE TABLE IF NOT EXISTS mesaj_tepkileri \(([\s\S]*?)\n\);/.exec(SEMA)[1];
  // ON DELETE SET NULL / RESTRICT olsaydı: silinmiş mesajın tepkisi öksüz
  // kalır (mesaj_id NOT NULL olduğu için SET NULL zaten patlar) ya da
  // DELETE /mesajlar/:id yabancı anahtar hatasıyla 500 verirdi.
  assert.equal((g.match(/ON DELETE CASCADE/g) || []).length, 2,
    'iki yabancı anahtarın İKİSİ de CASCADE olmalı');
  assert.doesNotMatch(g, /ON DELETE (SET NULL|RESTRICT|NO ACTION)/);
});

test('ŞEMA: kullanıcı başına mesaj başına TEK tepki (tekil indeks)', () => {
  assert.match(SEMA,
    /CREATE UNIQUE INDEX IF NOT EXISTS mesaj_tepkileri_tekil\s*\n?\s*ON mesaj_tepkileri \(mesaj_id, kullanici_id\)/);
  // Sütun SIRASI önemli: POST /mesaj-tepki'in ON CONFLICT çıkarımı buna
  // dayanır, üstelik öncü sütun mesaj_id olduğu için OKUMA sorgusu
  // (WHERE mesaj_id = ANY(...)) ayrı bir indekse ihtiyaç duymaz.
  assert.doesNotMatch(SEMA,
    /CREATE (UNIQUE )?INDEX IF NOT EXISTS \w+\s*\n?\s*ON mesaj_tepkileri \(mesaj_id\)/,
    'gereksiz ikinci (mesaj_id) indeksi — tekil indeksin öncü sütunu zaten o');
});

test('ŞEMA: FK CASCADE için kullanici_id indeksi var', () => {
  // Hesap silme (DELETE /hesabim) kullanici_id üzerinden cascade eder;
  // indekssiz her silme mesaj_tepkileri'nde tam tarama yapardı.
  assert.match(SEMA,
    /CREATE INDEX IF NOT EXISTS mesaj_tepkileri_kullanici\s*\n?\s*ON mesaj_tepkileri \(kullanici_id\)/);
});

// ---------------------------------------------------------------------------
// 2) EMOJİ LİSTESİ — üç yerde BİREBİR aynı
// ---------------------------------------------------------------------------
test('LİSTE: 9 emoji, ilki KALP, sema/migrasyon/server BİREBİR aynı', () => {
  assert.deepEqual(MESAJ_TEPKI_EMOJILERI, BEKLENEN, 'server.js sabiti değişmiş');
  assert.equal(MESAJ_TEPKI_EMOJILERI[0], '❤️', 'ilk emoji KALP olmalı (çift tıklama)');
  assert.equal(new Set(MESAJ_TEPKI_EMOJILERI).size, 9, 'liste tekrar içeriyor');

  const semaListe = sqlListesi(SEMA.slice(SEMA.indexOf('mesaj_tepkileri')), 'sema.sql');
  const migListe = sqlListesi(KOMUTLAR, 'migrasyon');
  assert.deepEqual(semaListe, BEKLENEN, 'sema.sql CHECK listesi ayrışmış');
  assert.deepEqual(migListe, BEKLENEN, 'migrasyon CHECK listesi ayrışmış');
  // Ayrışırsa uç 400 yerine 23514 (CHECK ihlali) -> kullanıcıya 500 gider.
  assert.deepEqual(semaListe, migListe);
});

test('LİSTE: içerik tepkileri (`tepkiler`) BOZULMADI — orada kalp YOK', () => {
  const icerik = new Function(
    `${bildirimCek(KAYNAK, 'TEPKI_EMOJILERI')}\nreturn TEPKI_EMOJILERI;`,
  )();
  assert.equal(icerik.length, 8, 'içerik emoji şeridi 8 hücreye göre çiziliyor');
  assert.ok(!icerik.includes('❤️') && !icerik.includes('❤'),
    'kalp içerik listesine sızmış — favori yıldızıyla karışır');
  // DM listesinin kalp DIŞINDAKİ 8'i içerik listesiyle AYNI KÜME olmalı
  // (sıra bilerek farklı: iki şerit ayrı tasarımlar).
  assert.deepEqual(
    [...MESAJ_TEPKI_EMOJILERI.slice(1)].sort(),
    [...icerik].sort(),
    'DM listesinin 8 emojisi içerik listesiyle aynı küme değil',
  );
  // `tepkiler` tablosunun CHECK'i de 8'de kalmalı.
  const tepkilerBlok = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS tepkiler'));
  assert.equal(sqlListesi(tepkilerBlok, 'tepkiler').length, 8);
});

// ---------------------------------------------------------------------------
// 3) MİGRASYON
// ---------------------------------------------------------------------------
test('MİGRASYON: İDEMPOTENT — tüm CREATE’ler IF NOT EXISTS', () => {
  const yaratmalar = [...KOMUTLAR.matchAll(/CREATE (?:UNIQUE )?(TABLE|INDEX)([^;]*)/g)];
  assert.ok(yaratmalar.length >= 3, `beklenenden az CREATE: ${yaratmalar.length}`);
  for (const [, tur, gerisi] of yaratmalar) {
    assert.match(gerisi, /^ IF NOT EXISTS/,
      `IF NOT EXISTS'siz CREATE ${tur} — ikinci çalıştırma 42P07/42P07 verir`);
  }
});

test('MİGRASYON: mevcut veriyi BOZMAZ (yazma/silme/şema değişimi yok)', () => {
  for (const yasak of [/\bDELETE\s+FROM\b/i, /\bUPDATE\s+\w+\s+SET\b/i,
    /\bINSERT\s+INTO\b/i, /\bDROP\s+TABLE\b/i, /\bTRUNCATE\b/i,
    /\bDROP\s+COLUMN\b/i, /\bALTER\s+TABLE\s+mesajlar\b/i,
    /\bALTER\s+TABLE\s+tepkiler\b/i]) {
    assert.doesNotMatch(KOMUTLAR, yasak, `migrasyon veri/şema kaybettiriyor: ${yasak}`);
  }
});

test('MİGRASYON: tablo tanımı sema.sql ile AYNI', () => {
  const al = (metin) => {
    const g = /CREATE TABLE IF NOT EXISTS mesaj_tepkileri \(([\s\S]*?)\n\);/.exec(metin);
    assert.ok(g, 'tablo tanımı yok');
    // Yorum satırlarını ve boşlukları at: iki dosyada gerekçe metinleri farklı.
    return g[1].split('\n').map((s) => s.replace(/--.*$/, '').trim())
      .filter(Boolean).join(' ').replace(/\s+/g, ' ');
  };
  assert.equal(al(MIGRASYON), al(SEMA),
    'migrasyon ile sema.sql ayrışmış — sıfırdan kurulan DB farklı şema alır');
});

test('MİGRASYON: GERİ ALMA yolu dosyanın başında yazılı', () => {
  const bas = MIGRASYON.slice(0, MIGRASYON.search(/^CREATE TABLE/m));
  assert.match(bas, /GERİ ALMA \(rollback\)/, 'geri alma bölümü yok');
  assert.match(bas, /DROP TABLE IF EXISTS mesaj_tepkileri;/);
  // Şifrelememe kararı migrasyonda gerekçesiyle yazılı olmalı: yarın
  // "bunu neden şifrelemedik" sorusunun cevabı burada durur.
  assert.match(bas, /ŞİFRELENMEZ/);
});

// ---------------------------------------------------------------------------
// 4) EMOJİ DOĞRULAMA (canlı `mesajTepkiEmojisi` çalıştırılıyor)
// ---------------------------------------------------------------------------
test('EMOJİ: listedeki her emoji KANONİK hâliyle kabul edilir', () => {
  for (const e of BEKLENEN) assert.equal(mesajTepkiEmojisi(e), e);
});

test('EMOJİ: VARYASYON SEÇİCİSİZ kalp de kabul, KANONİK hâle çevrilir', () => {
  // Bazı klavyeler/istemciler U+FE0F göndermez. Ham karşılaştırma bu isteğe
  // haksız yere 400 verir ("bazen kalp çalışmıyor") — ya da daha kötüsü, iki
  // ayrı satır/iki ayrı sayaç oluşurdu.
  assert.equal(mesajTepkiEmojisi('❤'), '❤️');
  assert.equal(mesajTepkiEmojisi('❤️'), '❤️');
  assert.equal(mesajTepkiEmojisi('❤️'.normalize('NFD')), '❤️');
});

test('EMOJİ: kümede olmayan / saçma değerler REDDEDİLİR (undefined)', () => {
  for (const kotu of ['🍕', '👍', '', 'a', '❤️❤️', '<script>', '😄😄',
    null, undefined, 5, {}, [], true]) {
    assert.equal(mesajTepkiEmojisi(kotu), undefined,
      `kabul edilmemeliydi: ${JSON.stringify(kotu)}`);
  }
});

// ---------------------------------------------------------------------------
// 5) YANIT BİÇİMİ (canlı `mesajTepkiHarita` çalıştırılıyor)
// ---------------------------------------------------------------------------
test('BİÇİM: GROUP BY satırları mesaj_id -> [{emoji, adet, benim}]', () => {
  const harita = mesajTepkiHarita([
    { mesaj_id: 7, emoji: '❤️', adet: 2, benim: true },
    { mesaj_id: 7, emoji: '😂', adet: 1, benim: false },
    { mesaj_id: 9, emoji: '😢', adet: 1, benim: false },
  ]);
  assert.deepEqual(harita, {
    7: [{ emoji: '❤️', adet: 2, benim: true },
      { emoji: '😂', adet: 1, benim: false }],
    9: [{ emoji: '😢', adet: 1, benim: false }],
  });
});

test('BİÇİM: `benim` HER ZAMAN boolean (null/undefined sızmaz)', () => {
  // İstemci `benim` üzerinde üç durumlu mantık kurmasın: kendi tepkisi
  // vurgulu çizilir, null gelirse Dart tarafında tip hatası olurdu.
  const h = mesajTepkiHarita([
    { mesaj_id: 1, emoji: '😄', adet: 1, benim: null },
    { mesaj_id: 2, emoji: '😄', adet: 1, benim: undefined },
    { mesaj_id: 3, emoji: '😄', adet: 1, benim: 'true' },
  ]);
  for (const id of [1, 2, 3]) assert.equal(h[id][0].benim, false);
});

test('BİÇİM: boş girdi boş harita (tepkisiz sohbet)', () => {
  assert.deepEqual(mesajTepkiHarita([]), {});
});

// ---------------------------------------------------------------------------
// 6) YETKİ — EN KRİTİK TEST
// ---------------------------------------------------------------------------
test('YETKİ: BAŞKASININ sohbetindeki mesaja tepki REDDEDİLİR', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  // Mesaj SORGUSU sahiplik süzgecini İÇERMEK ZORUNDA.
  assert.match(govde,
    /FROM mesajlar\s*\n?\s*WHERE id=\$1 AND \(gonderen_id=\$2 OR alici_id=\$2\)/,
    'sahiplik süzgeci yok — herkes her mesaja tepki verebilir');
  assert.match(govde, /\[mesajId, req\.kullanici\.id\]/,
    'sorguya oturum kullanıcısı geçirilmiyor');
  // Süzgeç boş dönerse İSTEK ÖLÜR: yazma sorguları buna bağlı.
  assert.match(govde, /if \(!m\.rows\.length\) return res\.status\(404\)/,
    'yetkisiz istek 404 ile kesilmiyor');
  // Yetki reddi 404 olmalı: 403 "bu id'de bir mesaj VAR" derdi (varlık kâhini).
  const reddIndeksi = govde.indexOf('!m.rows.length');
  assert.ok(reddIndeksi > 0);
  assert.doesNotMatch(govde.slice(reddIndeksi, reddIndeksi + 160), /status\(403\)/,
    'yetki reddi 403 dönüyor — mesaj varlığı sızar');
  // Yazma yetki kontrolünden SONRA olmalı.
  const yazmaIndeksi = govde.indexOf('INSERT INTO mesaj_tepkileri');
  assert.ok(yazmaIndeksi > reddIndeksi,
    'INSERT yetki kontrolünden ÖNCE — kontrol atlanabilir');
  assert.ok(govde.indexOf('DELETE FROM mesaj_tepkileri') > reddIndeksi,
    'DELETE yetki kontrolünden ÖNCE');
});

test('YETKİ: mesaj_id doğrulanıyor (tip/negatif)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde, /!Number\.isInteger\(mesajId\) \|\| mesajId <= 0/);
  assert.match(govde, /return res\.status\(400\)\.json\(\{ hata: 'Geçersiz mesaj_id' \}\)/);
});

test('YETKİ: engelleme kapısı POST /mesajlar ile AYNI yardımcıdan geçiyor', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde, /await engelliMi\(req\.kullanici\.id, partnerId\)/,
    'engelleme kontrolü yok — engellediğin kişi sana tepki bırakabilir');
  // KALDIRMA serbest kalmalı: engellenmeden önce bırakılmış tepkiyi geri
  // alamamak tuzak olurdu (/arama/bitir ile aynı gerekçe).
  assert.match(govde, /emoji != null && await engelliMi/,
    'engel kontrolü kaldırma (emoji=null) isteğini de kesiyor');
});

test('YETKİ: yasaklı hesap girisZorunlu kapısında durur (muaf DEĞİL)', () => {
  const YASAK = oku('yasak.js');
  const muaf = /export const YASAK_MUAF = Object\.freeze\(\[([\s\S]*?)\]\);/.exec(YASAK);
  assert.ok(muaf, 'YASAK_MUAF bulunamadı');
  assert.ok(!muaf[1].includes('/mesaj-tepki'),
    '/mesaj-tepki yasak muafiyetine eklenmiş — banlı kullanıcı tepki bırakır');
  // Uç `girisZorunlu`dan geçmeli (kapı orada).
  assert.match(ucGovdesi('/mesaj-tepki'), /app\.post\('\/mesaj-tepki', girisZorunlu,/);
});

// ---------------------------------------------------------------------------
// 7) YAZMA SÖZLEŞMESİ — kaldırma + UPSERT
// ---------------------------------------------------------------------------
test('YAZMA: emoji null = KALDIR (POST /tepki ile aynı sözleşme)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde, /const emoji = emojiHam == null \? null : mesajTepkiEmojisi\(emojiHam\)/);
  // `undefined` (kümede yok) 400; `null` (kaldırma) geçerli. İkisi ayrışmazsa
  // geçersiz bir emoji sessizce "tepkiyi kaldır"a dönerdi.
  assert.match(govde, /if \(emoji === undefined\) return res\.status\(400\)/);
  assert.match(govde,
    /DELETE FROM mesaj_tepkileri WHERE mesaj_id=\$1 AND kullanici_id=\$2/);
});

test('YAZMA: ikinci emoji UPSERT ile DEĞİŞTİRİR (ikinci satır açmaz)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde,
    /INSERT INTO mesaj_tepkileri \(mesaj_id, kullanici_id, emoji\)[\s\S]*?ON CONFLICT \(mesaj_id, kullanici_id\) DO UPDATE SET emoji=\$3, tarih=now\(\)/);
  // ON CONFLICT çıkarımı `mesaj_tepkileri_tekil` indeksine dayanır.
  assert.match(SEMA, /CREATE UNIQUE INDEX IF NOT EXISTS mesaj_tepkileri_tekil/);
  assert.match(KOMUTLAR, /CREATE UNIQUE INDEX IF NOT EXISTS mesaj_tepkileri_tekil/);
});

test('YAZMA: emoji DB’ye KANONİK hâliyle yazılır (ham gövde değil)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde, /\[mesajId, req\.kullanici\.id, emoji\]/);
  assert.doesNotMatch(govde, /emojiHam\]/,
    'ham emoji doğrudan DB’ye gidiyor — kanonikleştirme atlanır, CHECK patlar');
});

test('YAZMA: emoji ŞİFRELENMİYOR (bilinçli karar)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.doesNotMatch(govde, /sifrele\(|cozGoster\(/,
    'tepki emojisi şifreleniyor — GROUP BY sayımı imkânsızlaşır (karar 1)');
  assert.doesNotMatch(bildirimCek(KAYNAK, 'mesajTepkileri'), /sifrele\(|cozGoster\(/);
});

test('YAZMA: BİLDİRİM ÜRETİLMEZ (bilinçli kapsam dışı)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.doesNotMatch(govde, /bildirimEkle\(|pushBildirim\(/,
    'tepki bildirim üretiyor — bildirimler.tur CHECK’i genişletilmedi, 23514 gelir');
  // Karar `bildirimler.tur` listesinde de görünmeli: 'tepki' YOK.
  assert.match(SEMA,
    /tur TEXT NOT NULL CHECK \(tur IN \('yanit','begeni','takip','mesaj','etiket'\)\)/);
});

test('HIZ LİMİTİ: uca bağlı ve mesaj limitinden gevşek', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde, /app\.post\('\/mesaj-tepki', girisZorunlu, mesajTepkiLimiti,/,
    'hız limiti uca bağlanmamış');
  const bildirim = bildirimCek(KAYNAK, 'mesajTepkiLimiti');
  const n = Number(/hizLimiti\((\d+),/.exec(bildirim)[1]);
  const mesaj = Number(/hizLimiti\((\d+),/.exec(bildirimCek(KAYNAK, 'mesajLimiti'))[1]);
  // Tepki bir dokunuştur ve gidip gelir (bırak -> kaldır -> yine bırak);
  // mesaj göndermekten sık tetiklenir, ama bildirim üretmez.
  assert.ok(n >= mesaj, `tepki limiti (${n}) mesaj limitinden (${mesaj}) dar`);
  assert.ok(n <= 3000, `tepki limiti (${n}) fiilen sınırsız`);
  // Anahtar KULLANICI olmalı: CGNAT arkasındaki binlerce mobil kullanıcı aynı
  // IP'yi paylaşır, IP anahtarı hepsini birden keserdi.
  assert.match(bildirim, /req\.kullanici\.id/);
  assert.doesNotMatch(bildirim, /req\.ip/);
});

// ---------------------------------------------------------------------------
// 8) OKUMA — GET /mesajlar yanıtı, N+1 YOK
// ---------------------------------------------------------------------------
test('OKUMA: tepkiler GET /mesajlar/:ad yanıtına ekleniyor (ayrı uç YOK)', () => {
  const govde = ucGovdesi('/mesajlar/:kullaniciAdi', 'get');
  assert.match(govde, /await mesajTepkileri\(/,
    'sayfa tepkileri toplanmıyor');
  assert.match(govde, /for \(const r of rows\) r\.tepkiler = tepkiHaritasi\[r\.id\] \|\| \[\];/,
    'tepkisi olmayan mesaj `tepkiler: []` almıyor — istemcide null denetimi gerekir');
  // Yoklama `sonra` ile yalnız yeni id verir: mevcut balonun tepkisi
  // `guncellemeler` penceresinden birleşir. Ayrı GET /mesaj-tepki YOK.
  assert.match(govde, /guncellemeler/, 'yoklama tepki penceresi yok');
  assert.doesNotMatch(KAYNAK, /app\.get\('\/mesaj-tepki/,
    'ayrı tepki okuma ucu eklenmiş — yoklama yükü iki katına çıkar');
});

test('OKUMA: N+1 YOK — sayfadaki tüm mesajlar TEK sorguda, SQL’de GROUP BY', () => {
  const yardimci = bildirimCek(KAYNAK, 'mesajTepkileri');
  assert.match(yardimci, /WHERE mesaj_id = ANY\(\$1::int\[\]\)/,
    'mesaj başına sorgu atılıyor (N+1)');
  assert.match(yardimci, /GROUP BY mesaj_id, emoji/,
    'sayım uygulamada yapılıyor — SQL GROUP BY olmalı');
  assert.match(yardimci, /count\(\*\)::int AS adet/);
  assert.match(yardimci, /bool_or\(kullanici_id = \$2\) AS benim/,
    '`benim` bayrağı ikinci bir sorguyla hesaplanıyor');
  // Yardımcıda TEK sorgu var.
  assert.equal((yardimci.match(/havuz\.query\(/g) || []).length, 1);
  // Kaynakta `mesaj_tepkileri`den SELECT eden BAŞKA yer olmamalı: ikinci bir
  // kopya sessizce N+1'e ya da ayrışan biçime dönüşür.
  assert.equal((KAYNAK.match(/FROM mesaj_tepkileri/g) || []).length, 2,
    'beklenen: 1 SELECT (yardımcı) + 1 DELETE (uç)');
  // Boş sayfada sorgu bile atılmaz.
  assert.match(yardimci, /if \(!mesajIdler\.length\) return \{\};/);
});

test('OKUMA: POST yanıtı GET ile AYNI biçimi kullanır (tek çözümleyici)', () => {
  const govde = ucGovdesi('/mesaj-tepki');
  assert.match(govde, /const harita = await mesajTepkileri\(\[mesajId\], req\.kullanici\.id\)/);
  assert.match(govde,
    /res\.json\(\{ mesaj_id: mesajId, tepkiler: harita\[mesajId\] \|\| \[\] \}\)/,
    'POST yanıtı GET’teki `tepkiler` biçiminden ayrışmış');
});

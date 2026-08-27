// İÇE AKTARIMDA GERÇEK İZLEME TARİHİ (27 Ağu 2026).
//
// ÖLÇÜM (canlı DB, 27 Ağu) — düzeltmeden önce:
//   ozkanpiqubo 15.727 satır /  2 farklı gün
//   melis.izler 14.872 satır /  5 farklı gün
//   dizi.jpg    10.756 satır /  1 farklı gün
//   ocalselda361 7.085 satır /  1 farklı gün  ← BUGÜN aktardı, yine tek gün
//   alcelik     16.754 satır / 25 farklı gün
// Karşılaştırma — tarihi doğru gelen tek hesap:
//   emma.watches 5.969 satır / 885 farklı gün (2020 → 2026)
//
// 26 Ağu'da yalnız `tracking-prod-records-v2.csv` yolu onarılmıştı; geri kalan
// yollar `tarih` sütununu INSERT'e hiç koymuyor, DEFAULT now() damgalanıyordu.
// Aynı gün "izleme tarihleri" özelliği yayına girdiği için sonuç KULLANICIYA
// YANLIŞ BİLGİ göstermekti ("Breaking Bad'i 2019'da izledim" → "16 Tem 2026").
//
// İKİNCİ VE ASIL KUSUR: `ON CONFLICT DO NOTHING`. Yanlış damgalanmış satır
// zaten tabloda olduğu için YENİDEN İÇE AKTARIM onu atlıyordu — yani düzeltme
// geçmişi onarmıyordu, kullanıcının hiçbir kurtuluş yolu yoktu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const AKTAR = fs.readFileSync(path.join(KOK, 'veri_aktar.js'), 'utf8');

/** `veri_aktar.js`ten saf yardımcıyı çekip GERÇEKTEN çalıştırır. */
function bildirim(ad) {
  const m = new RegExp(`^(?:const|function) ${ad}\\b`, 'm').exec(AKTAR);
  assert.ok(m, `veri_aktar.js içinde ${ad} yok`);
  const bas = m.index;
  let derinlik = 0;
  let girdi = false;
  const fonksiyon = AKTAR.slice(bas).startsWith('function');
  for (let i = bas; i < AKTAR.length; i++) {
    const c = AKTAR[i];
    if ('{(['.includes(c)) { derinlik++; girdi = true; }
    else if (')]}'.includes(c)) {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') return AKTAR.slice(bas, i + 1);
    } else if (!fonksiyon && c === ';' && derinlik === 0) return AKTAR.slice(bas, i + 1);
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

const izlemeTarihi = new Function(
  `${bildirim('IZLEME_TARIH_SUTUNLARI')}\n${bildirim('izlemeTarihi')}\nreturn izlemeTarihi;`)();

test('izlemeTarihi bilinen tüm sütun adlarını okur', () => {
  // TV Time formata göre farklı sütun kullanıyor; tek okuma noktası hepsini
  // denemeli, yoksa bir format sessizce now()'a düşer (asıl hatanın kalıbı).
  assert.equal(izlemeTarihi({ created_at: '2025-08-01 21:40:45' }).getFullYear(), 2025);
  assert.equal(izlemeTarihi({ watched_at: '2019-03-04T20:00:00Z' }).getFullYear(), 2019);
  assert.equal(izlemeTarihi({ watched_on: '2021-12-31' }).getFullYear(), 2021);
  assert.equal(izlemeTarihi({ date: '2018-08-10' }).getFullYear(), 2018);
  // Öncelik sırası: created_at ilk sırada.
  assert.equal(
    izlemeTarihi({ created_at: '2019-01-01', watched_at: '2022-01-01' }).getFullYear(), 2019);
});

test('izlemeTarihi bozuk/boş girdide null döner (satır DÜŞMEZ, now()a düşer)', () => {
  for (const r of [{}, null, undefined, { created_at: '' }, { created_at: '   ' },
    { created_at: 'yok' }, { watched_at: 'bozuk-tarih' }, 5, 'x']) {
    assert.doesNotThrow(() => izlemeTarihi(r));
    assert.equal(izlemeTarihi(r), null, `null beklenirdi: ${JSON.stringify(r)}`);
  }
});

test('izlemeler INSERTlerinin HİÇBİRİ tarihsiz veya DO NOTHING değil', () => {
  // Bu iki kalıptan biri geri gelirse hata da geri gelir. Kaynak taranarak
  // kilitleniyor: yeni bir içe aktarım yolu eklenirse bu test onu yakalar.
  const blok = /INSERT INTO izlemeler \([^)]*\)[\s\S]{0,600}?`/g;
  const bloklar = AKTAR.match(blok) || [];
  assert.ok(bloklar.length >= 6, `izleme INSERT sayısı beklenenden az: ${bloklar.length}`);
  for (const b of bloklar) {
    assert.match(b, /tarih/, `tarih sütunu olmayan izleme INSERT'i:\n${b}`);
    assert.doesNotMatch(b, /ON CONFLICT DO NOTHING/,
      `çakışmada onarım yapmayan izleme INSERT'i (geçmiş düzelmez):\n${b}`);
    assert.match(b, /\$\{IZLEME_CAKISMA\}/,
      `ortak çakışma kuralını kullanmayan INSERT:\n${b}`);
  }
});

test('IZLEME_CAKISMA: birincil anahtarla AYNI hedef + LEAST ile onarım', () => {
  const c = bildirim('IZLEME_CAKISMA');
  // Hedef, izlemeler PK'siyle birebir aynı olmalı; ayrışırsa PostgreSQL 42P10.
  assert.match(c, /ON CONFLICT \(kullanici_id, tur, tmdb_id, sezon, bolum\)/);
  // LEAST: içe aktarım damgası (now()) gerçek tarihten HEP sonradır; en erken
  // olanı almak yanlış damgayı onarır ama gerçek tarihi İLERİ KAYDIRMAZ.
  assert.match(c, /DO UPDATE SET tarih = LEAST\(izlemeler\.tarih, EXCLUDED\.tarih\)/);
  assert.doesNotMatch(c, /GREATEST/, 'GREATEST yanlış damgayı kalıcı yapar');
});

test('DO UPDATE kullanan toplu yollar TEKİLLEŞTİRİLMİŞ', () => {
  // PostgreSQL 21000: "ON CONFLICT DO UPDATE command cannot affect row a
  // second time". Aynı deyimde yinelenen satır varsa içe aktarım KOMPLE düşer.
  // DO NOTHING'de bu hata yoktu — yani onarımı eklerken açtığımız yeni risk.
  assert.match(AKTAR, /const izlemeHarita = new Map\(\)/,
    'kendi formatımızın (iceAktarNative) toplu ekleme yolu tekilleştirilmemiş');
  assert.match(AKTAR, /const tekil = new Map\(\)/,
    'unnest yolu (tek dosyalı CSV) tekilleştirilmemiş');
  assert.match(AKTAR, /const benzersiz = \[\.\.\.tekil\.values\(\)\]/);
});

test('kendi dışa aktarımımız geri yüklenince TARİH KORUNUR (yuvarlak yol)', () => {
  // `disaAktar` her izlemeyi created_at ile yazıyordu ama `iceAktarNative`
  // onu HİÇ okumuyordu: kullanıcı kendi yedeğini geri yükleyince tüm geçmişin
  // tarihi yükleme gününe çöküyordu — yedeğin kendisi veri kaybettiriyordu.
  assert.match(AKTAR, /created_at: i\.tarih\?\.toISOString\?\.\(\) \|\| ''/,
    'dışa aktarım izleme tarihini yazmıyor');
  assert.match(AKTAR, /String\(i\.tarih \?\? i\.created_at \?\? ''\)/,
    'içe aktarım kendi formatımızın tarihini okumuyor');
});

test('film satırları da tarih taşıyor (Set → Map değişimi korunuyor)', () => {
  // Eskiden `filmAdlari` bir Set'ti: ad tutuluyor, tarih ATILIYORDU.
  assert.match(AKTAR, /const filmAdlari = new Map\(\)/,
    'film adları hâlâ Set — tarih düşer');
  assert.doesNotMatch(AKTAR, /filmAdlari\.add\(/, 'Set API\'si kalmış');
  assert.match(AKTAR, /for \(const \[isim, tarih\] of filmAdlari\)/);
});

// ===========================================================================
// tarih_kesin — GÜVENİLMEYEN TARİH UÇTA SÜZÜLÜR (27 Ağu 2026-b)
// ===========================================================================
const SUNUCU = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const MIGRASYON = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-27b.sql'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

test('/benim ucu güvenilmeyen tarihi NULL döndürüyor (tek süzgeç noktası)', () => {
  assert.match(SUNUCU, /SELECT sezon, bolum, tarih, tarih_kesin FROM izlemeler/,
    'uç tarih_kesin sütununu okumuyor');
  assert.match(SUNUCU, /tarih: r\.tarih_kesin \? r\.tarih : null/,
    'güvenilmeyen tarih uçta süzülmüyor — istemciye uydurma tarih gider');
  // `son_izleme` de süzülmüş listeden hesaplanmalı; ham satırlardan
  // hesaplanırsa gizlenen tarih ÖZET satırında geri sızar.
  assert.match(SUNUCU, /const sonIzleme = izlenenler\.reduce\(/,
    'son_izleme hâlâ ham satırlardan hesaplanıyor');
});

test('şema ve migrasyon: tarih_kesin varsayılan TRUE', () => {
  // Varsayılan false olsaydı uygulama içinde işaretlenen HER izleme
  // güvenilmez sayılır ve tarih hiç görünmezdi.
  assert.match(SEMA, /tarih_kesin BOOLEAN NOT NULL DEFAULT true/);
  assert.match(MIGRASYON, /ADD COLUMN IF NOT EXISTS tarih_kesin BOOLEAN NOT NULL DEFAULT true/);
});

test('yığın sezgisi: SATIR SAYISI TEK BAŞINA yetmez, FARKLI YAPIM şart', () => {
  // Ölçüm (27 Ağu): ozkanpiqubo 2.454 satır / 3 farklı yapım — bu bir içe
  // aktarım DEĞİL, uzun animeleri uygulamadan işaretlemiş ve o damga
  // DÜRÜST. Yalnız satır sayısına bakan bir eşik onu da yanlış işaretlerdi.
  assert.match(MIGRASYON, /count\(\*\) >= 100 AND count\(DISTINCT tmdb_id\) >= 30/,
    'yığın eşiği farklı yapım sayısını içermiyor');
  assert.match(MIGRASYON, /date_trunc\('minute', tarih\)/,
    'yığın kırılımı dakika değil');
  // Geri doldurma yalnız DÜŞÜRÜR (true → false); tersini yapmaz.
  // YORUM SATIRLARI ELENİR: gerekçe bloğunda geri alma komutu ("UPDATE
  // izlemeler SET tarih_kesin = true") METİN olarak geçiyor; ham dosyada
  // arama yapmak onu ÇALIŞTIRILAN SQL sanıyordu (bu test öyle yakalandı).
  const sql = MIGRASYON.split('\n').filter((l) => !l.trim().startsWith('--')).join('\n');
  assert.match(sql, /SET tarih_kesin = false/);
  assert.doesNotMatch(sql, /SET tarih_kesin = true/);
  // Veri silinmiyor: tarih sütununa dokunulmuyor.
  assert.doesNotMatch(sql, /DELETE FROM izlemeler|SET tarih =/);
});

test('yeniden yükleme bayrağı da ONARIR (OR ile)', () => {
  const c = bildirim('IZLEME_CAKISMA');
  assert.match(c, /tarih_kesin = izlemeler\.tarih_kesin OR EXCLUDED\.tarih_kesin/,
    'yeniden yükleme güvenilirliği geri getirmiyor');
  // Her izleme INSERT'i sütunu taşımalı.
  const bloklar = AKTAR.match(/INSERT INTO izlemeler \([^)]*\)[\s\S]{0,700}?`/g) || [];
  assert.ok(bloklar.length >= 6);
  for (const b of bloklar) {
    assert.match(b, /tarih_kesin/, `tarih_kesin yazmayan izleme INSERT'i:\n${b}`);
  }
  // Bayrak SABİT yazılmamalı: gerçek tarih okunabildiyse true, okunamadıysa
  // false olmalı. Toplu yollarda VALUES listesi ayrı kuruluyor, o yüzden
  // iddia blok bazlı değil DOSYA bazlı (blok penceresi onları görmüyordu).
  const kosullu = (AKTAR.match(/IS NOT NULL/g) || []).length;
  assert.ok(kosullu >= 6,
    `bayrak koşullu yazılan yol sayısı az (${kosullu}) — biri sabit true olabilir`);
  assert.doesNotMatch(AKTAR, /tarih_kesin\)\s*\n?\s*VALUES[^`]*,\s*true\)/,
    'bir yolda tarih_kesin sabit true yazılmış');
});

// ===========================================================================
// PUAN ÖLÇEĞİ — SESSİZ VERİ KAYBI (27 Ağu 2026)
// ===========================================================================
// Kanonik ölçek 26 Ağu'da 1-10 → 1-100 oldu (migrasyon-2026-08-26b.sql) ama
// `iceAktarNative` hâlâ `puan > 10` olanı ELİYORDU. Yani kullanıcı KENDİ
// yedeğini geri yüklediğinde puanlarının neredeyse tamamı sessizce düşüyordu
// (5 yıldız = kanonik 100 > 10 → atlanan). `surum` alanı da ölçek değişiminde
// bump edilmediği için eski/yeni dosya ayırt edilemiyordu.
const puanOlcegiCoz = new Function(
  `${bildirim('puanOlcegiCoz')}\nreturn puanOlcegiCoz;`)();

test('dışa aktarım ölçeği AÇIKÇA yazıyor (sürüm 2)', () => {
  assert.match(AKTAR, /surum: 2,/, 'sürüm bump edilmemiş — eski/yeni ayrılamaz');
  assert.match(AKTAR, /puan_olcek: 100,/, 'dosya ölçeği açıkça yazılmıyor');
  // Kullanıcının GÖRÜNÜM tercihi yazılmamalı: dosyadaki değerler kanoniktir.
  assert.doesNotMatch(AKTAR, /puan_olcek: k\.puan_olcegi/);
});

test('ölçek çözümü: bildirilen değer her şeyin ÖNÜNDE', () => {
  assert.equal(puanOlcegiCoz({ puan_olcek: 100, surum: 1 }, [{ puan: 5 }]), 100);
  assert.equal(puanOlcegiCoz({ puan_olcek: 10, surum: 2 }, [{ puan: 5 }]), 10);
  assert.equal(puanOlcegiCoz({ puan_olcek: 5 }, [{ puan: 3 }]), 5);
  // Aralık dışı/bozuk bildirim YOK SAYILIR, sonraki adıma düşer.
  for (const olcek of [0, 4, 101, -1, 'x', null, 1.5]) {
    assert.equal(puanOlcegiCoz({ puan_olcek: olcek, surum: 2 }, []), 100,
      `bozuk bildirim kabul edildi: ${olcek}`);
  }
});

test('ölçek çözümü: sürüm 2+ kanonik, sürüm 1 DOSYAYA bakar', () => {
  assert.equal(puanOlcegiCoz({ surum: 2 }, [{ puan: 5 }]), 100);
  assert.equal(puanOlcegiCoz({ surum: 3 }, [{ puan: 5 }]), 100);
  // Sürüm 1 + 10'u aşan puan → dosya kanoniktir (eski ölçek 10'u aşamazdı).
  assert.equal(puanOlcegiCoz({ surum: 1 }, [{ puan: 7 }, { puan: 73 }]), 100);
  // Sürüm 1 + hepsi <= 10 → ESKİ dosya sayılır.
  assert.equal(puanOlcegiCoz({ surum: 1 }, [{ puan: 7 }, { puan: 10 }]), 10);
  assert.equal(puanOlcegiCoz({}, [{ puan: 10 }]), 10, 'sürümsüz dosya eski sayılmalı');
  assert.equal(puanOlcegiCoz({}, []), 10, 'boş liste eski varsayılmalı');
});

test('ölçek çözümü bozuk girdide ATMAZ', () => {
  for (const v of [null, undefined, {}, { puanlar: null }, 5, 'x']) {
    assert.doesNotThrow(() => puanOlcegiCoz(v, null));
    const o = puanOlcegiCoz(v, null);
    assert.ok(o >= 5 && o <= 100, `mantıksız ölçek: ${o}`);
  }
});

test('dönüşüm kanonik 1-100e taşıyor ve ELEME ölçeğe göre', () => {
  // Eleme sınırı artık sabit 10 DEĞİL, kaynak ölçek.
  assert.match(AKTAR, /if \(!ham \|\| ham < 1 \|\| ham > kaynakOlcek\)/,
    'eleme hâlâ sabit sınırla yapılıyor — kanonik puanlar düşer');
  assert.doesNotMatch(AKTAR, /puan < 1 \|\| puan > 10/,
    'eski 1-10 kontrolü duruyor');
  // Taşıma formülü + kırpma (puanlar.puan CHECK 1-100).
  assert.match(AKTAR,
    /Math\.min\(100, Math\.max\(1, Math\.round\(ham \* 100 \/ kaynakOlcek\)\)\)/);
  // Dönüşüm sessiz olmasın: özete yazılıyor.
  assert.match(AKTAR, /ozet\.puan_olcek = kaynakOlcek/);
});

test('taşıma matematiği: eski 1-10 dosyası migrasyonla AYNI sonucu vermeli', () => {
  // migrasyon-2026-08-26b.sql mevcut puanları ×10 ile taşımıştı; geri
  // yüklenen eski bir dosya da aynı yere düşmeli, yoksa aynı kullanıcının
  // yedeği ile canlı verisi ayrışır.
  const tasi = (ham, olcek) => Math.min(100, Math.max(1, Math.round(ham * 100 / olcek)));
  for (let p = 1; p <= 10; p++) assert.equal(tasi(p, 10), p * 10);
  // Kanonik dosya AYNEN korunur (kimlik dönüşümü).
  for (const p of [1, 37, 73, 100]) assert.equal(tasi(p, 100), p);
  // 5'lik ölçek: 4 yıldız = 80.
  assert.equal(tasi(4, 5), 80);
  assert.equal(tasi(1, 5), 20);
});

test('yuvarlak yol bozuk tarihi AKLAMAZ (tarih_kesin yedekte taşınır)', () => {
  // Açık: dışa aktarım `tarih_kesin`i taşımasaydı, kendi yedeğimizi geri
  // yüklemek toplu içe aktarım damgasını GERÇEK tarih sanıp bayrağı true
  // yapardı (LEAST aynı değeri korur, OR bayrağı yükseltirdi). Yani bozuk
  // veriyi kendi yedeğimizle aklamış olurduk.
  assert.match(AKTAR, /SELECT tur, tmdb_id, sezon, bolum, tarih, tarih_kesin FROM izlemeler/,
    'dışa aktarım tarih_kesin sütununu taşımıyor');
  assert.match(AKTAR, /const guvenilir = i\.tarih_kesin !== false;/,
    'içe aktarım dosyadaki güvenilmezlik bayrağını yok sayıyor');
  assert.match(AKTAR, /const t = guvenilir && ham && !Number\.isNaN\(Date\.parse\(ham\)\)/,
    'güvenilmez tarih yine de okunuyor');
  // `!== false` bilinçli: bayrağı OLMAYAN dosyalarda (TV Time, eski sürüm)
  // tarih geçerli sayılmalı, yoksa çalışan yolları bozardık.
  assert.doesNotMatch(AKTAR, /i\.tarih_kesin === true/,
    'katı kontrol eski dosyalarda tüm tarihleri düşürür');
});


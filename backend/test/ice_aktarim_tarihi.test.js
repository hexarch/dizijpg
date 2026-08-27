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

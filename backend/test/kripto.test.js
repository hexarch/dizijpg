// Özel mesajların durağan şifrelenmesi — `backend/kripto.js`.
//
// Buradaki her test GERÇEK fonksiyonu çağırır (kaynak metnine regex
// tutturmak yok). Anahtar takımı testin İÇİNDE üretilir ve fonksiyonlara
// parametre olarak geçilir; küresel duruma ve process.env'e bağımlı tek bir
// test yoktur, testler paralel de sıralı da aynı sonucu verir.
import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  ZARF_SURUM, IV_UZUNLUK, ETIKET_UZUNLUK, ANAHTAR_UZUNLUK,
  sifrele, coz, cozGoster, sifreliMi, zarfAyristir, satirCoz,
  anahtarYukle, anahtarUret, baslat, anahtarlariAyarla, anahtarlar,
} from '../kripto.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

/** Testlik anahtar takımı: `{k1: <base64>, k2: <base64>}` -> takım nesnesi. */
function takimKur({ aktif = 'k1', anahtarlar: harita } = {}) {
  const h = harita || { k1: anahtarUret() };
  const env = {
    MESAJ_ANAHTARI: `${aktif}:${h[aktif]}`,
    MESAJ_ANAHTARI_ESKI: Object.entries(h)
      .filter(([k]) => k !== aktif)
      .map(([k, v]) => `${k}:${v}`)
      .join(','),
  };
  return anahtarYukle(env);
}

const K1 = anahtarUret();
const K2 = anahtarUret();
const TAKIM = takimKur({ aktif: 'k1', anahtarlar: { k1: K1 } });

// ------------------------------------------------------------ gidiş-dönüş

test('gidiş-dönüş: şifrelenen metin aynen geri gelir', () => {
  const m = 'Merhaba, bu bir özel mesaj.';
  const zarf = sifrele(m, TAKIM);
  assert.notEqual(zarf, m, 'çıktı düz metnin kendisi olmamalı');
  assert.equal(coz(zarf, TAKIM), m);
});

test('zarf biçimi: v1.<kimlik>.<iv>.<etiket>.<sifreli>, parçalar base64url', () => {
  const zarf = sifrele('deneme', TAKIM);
  const parcalar = zarf.split('.');
  assert.equal(parcalar.length, 5, 'tam 5 parça');
  assert.equal(parcalar[0], ZARF_SURUM);
  assert.equal(parcalar[1], 'k1', 'anahtar kimliği zarfta taşınır');
  // base64url alfabesi: '+', '/', '=' YOK (ayraç '.' ile çakışma da yok)
  for (const p of parcalar.slice(2)) {
    assert.match(p, /^[A-Za-z0-9_-]+$/, `base64url değil: ${p}`);
  }
  const a = zarfAyristir(zarf);
  assert.equal(a.iv.length, IV_UZUNLUK, 'IV 12 bayt');
  assert.equal(a.etiket.length, ETIKET_UZUNLUK, 'GCM etiketi 16 bayt');
  assert.equal(a.baslik, 'v1.k1');
});

test('şifreli metin düz metni İÇERMEZ (gözle bakılınca da sızmıyor)', () => {
  const gizli = 'kredikartinumaram1234';
  const zarf = sifrele(gizli, TAKIM);
  assert.ok(!zarf.includes(gizli));
  assert.ok(!Buffer.from(zarf, 'utf8').includes(Buffer.from(gizli, 'utf8')));
});

// ------------------------------------------------------------ IV rastgeleliği

test('aynı metnin iki şifrelemesi FARKLI çıkar (IV her seferinde yeni)', () => {
  const m = 'aynı metin';
  const a = sifrele(m, TAKIM);
  const b = sifrele(m, TAKIM);
  assert.notEqual(a, b, 'IV sabit olsaydı "iki kişi aynı şeyi yazmış" sızardı');
  assert.notEqual(zarfAyristir(a).iv.toString('hex'),
                  zarfAyristir(b).iv.toString('hex'));
  // ama ikisi de aynı metni verir
  assert.equal(coz(a, TAKIM), m);
  assert.equal(coz(b, TAKIM), m);
});

test('100 şifrelemede IV tekrarı yok (GCM\'de IV tekrarı anahtarı yakar)', () => {
  const gorulen = new Set();
  for (let i = 0; i < 100; i++) {
    gorulen.add(zarfAyristir(sifrele('x', TAKIM)).iv.toString('hex'));
  }
  assert.equal(gorulen.size, 100);
});

// ------------------------------------------------------------ bozulma tespiti

test('şifreli gövdede TEK BİT bozulursa çözme HATA verir (GCM etiketi)', () => {
  const zarf = sifrele('bu mesaj korunuyor', TAKIM);
  const p = zarf.split('.');
  const govde = Buffer.from(p[4], 'base64url');
  govde[0] ^= 0x01;                       // tek bit çevir
  p[4] = govde.toString('base64url');
  const bozuk = p.join('.');
  assert.ok(sifreliMi(bozuk), 'biçim hâlâ geçerli bir zarf');
  assert.throws(() => coz(bozuk, TAKIM), /çözülemedi|etiket/i);
});

test('ETİKETTE tek bit bozulursa çözme HATA verir', () => {
  const zarf = sifrele('bu mesaj korunuyor', TAKIM);
  const p = zarf.split('.');
  const etiket = Buffer.from(p[3], 'base64url');
  etiket[15] ^= 0x80;
  p[3] = etiket.toString('base64url');
  assert.throws(() => coz(p.join('.'), TAKIM), /çözülemedi|etiket/i);
});

test('IV değiştirilirse çözme HATA verir', () => {
  const zarf = sifrele('bu mesaj korunuyor', TAKIM);
  const p = zarf.split('.');
  const iv = Buffer.from(p[2], 'base64url');
  iv[0] ^= 0xff;
  p[2] = iv.toString('base64url');
  assert.throws(() => coz(p.join('.'), TAKIM), /çözülemedi|etiket/i);
});

test('BAŞLIK (sürüm+kimlik) AAD\'de: kimliği k2 diye yeniden etiketleme tutmaz', () => {
  // İki anahtarlı takım: k2 gerçekten YÜKLÜ olsun ki test "anahtar yok"
  // hatasına düşüp yanlış nedenle geçmesin.
  const cift = takimKur({ aktif: 'k2', anahtarlar: { k1: K1, k2: K2 } });
  const zarf = sifrele('gizli', takimKur({ aktif: 'k1', anahtarlar: { k1: K1, k2: K2 } }));
  assert.equal(zarf.split('.')[1], 'k1');
  const sahte = zarf.replace(/^v1\.k1\./, 'v1.k2.');
  assert.ok(sifreliMi(sahte));
  assert.throws(() => coz(sahte, cift), /çözülemedi|etiket/i,
    'AAD başlığı bağladığı için kimlik değiştirmek tespit edilir');
});

test('iki mesajın şifreli gövdeleri takas edilirse (satır kopyalama) IV+etiket ile birlikte taşınmazsa tutmaz', () => {
  const a = sifrele('birinci', TAKIM);
  const b = sifrele('ikinci', TAKIM);
  const pa = a.split('.');
  const pb = b.split('.');
  const melez = [pa[0], pa[1], pa[2], pa[3], pb[4]].join('.');
  assert.throws(() => coz(melez, TAKIM), /çözülemedi|etiket/i);
});

// ------------------------------------------------------- karışık dönem / düz metin

test('düz metin satır AYNEN döner (geri doldurma bitmeden okunan eski mesaj)', () => {
  assert.equal(coz('eski düz metin mesaj', TAKIM), 'eski düz metin mesaj');
  assert.equal(coz('', TAKIM), '');
  assert.equal(sifreliMi('eski düz metin mesaj'), false);
});

test('null ve undefined: sesli/medya mesajında metin NULL olabilir', () => {
  // server.js POST /mesajlar: INSERT ... VALUES (..., temiz || null, ...)
  // yani metinsiz (sesli/medya/içerik kartı) mesajda kolon NULL'dur.
  const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
  assert.ok(SERVER.includes('temiz || null'),
    'POST /mesajlar boş metni NULL yazıyor olmalı — bu testin dayanağı');
  assert.equal(sifrele(null, TAKIM), null);
  assert.equal(sifrele(undefined, TAKIM), null);
  assert.equal(coz(null, TAKIM), null);
  assert.equal(coz(undefined, TAKIM), undefined);
  assert.equal(sifreliMi(null), false);
  assert.equal(sifreliMi(undefined), false);
});

test('boş metin şifrelenmez (48 baytlık zarfın içinde hiçbir şey saklamayız)', () => {
  assert.equal(sifrele('', TAKIM), '');
  assert.equal(sifreliMi(''), false);
});

// ------------------------------------- kullanıcı metni zarfa BENZİYORSA (yanlış pozitif)

test('kullanıcı "v1.k1.…" yazarsa: şifrelenip çözülünce HARFİ HARFİNE geri gelir', () => {
  // Asıl savunma yazma yolunda: sifrele() her şeyi zarfın İÇİNE koyar,
  // coz() bir kez çözer ve sonucu TEKRAR ayrıştırmaz (özyineleme yok).
  const gercekZarf = sifrele('kurban', TAKIM);
  const kotuNiyetli = [
    gercekZarf,                                  // birebir gerçek bir zarf!
    'v1.k1.AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAA.AAAA',
    'v1.k9.' + 'a'.repeat(16) + '.' + 'b'.repeat(22) + '.cccc',
    'v1.k1.a.b.c',
    'v2.k1.x.y.z',
  ];
  for (const m of kotuNiyetli) {
    assert.equal(coz(sifrele(m, TAKIM), TAKIM), m, `bozuldu: ${m.slice(0, 20)}`);
  }
});

test('sifreliMi(): rastgele/insan metni ASLA zarf sayılmaz', () => {
  const duzMetinler = [
    'v1.k1', 'v1.k1.', 'v1.k1.a.b', 'v1.k1.a.b.c.d',
    'v1.k0.aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.cccc',   // k0 geçersiz
    'v1.kk.aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.cccc',   // kimlik kalıbı
    'v0.k1.aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.cccc',   // sürüm
    'v1.k1.aaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.cccc',    // IV 15 karakter
    'v1.k1.aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbb.cccc',    // etiket 21 karakter
    'v1.k1.aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.',       // gövde boş
    'v1.k1.aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.c',      // gövde uzunluğu %4==1
    'v1.k1.aaaaaaaa+aaaaaaa.bbbbbbbbbbbbbbbbbbbbbb.cccc',   // '+' base64url değil
    'v1.k1.aaaaaaaaaaaaaaa=.bbbbbbbbbbbbbbbbbbbbbb.cccc',   // dolgu karakteri
    'yarın 1.k1.çıkıyor', 'v1', 'selam', 'https://dizijpg.com/dizi/1.k1.x.y.z',
  ];
  for (const m of duzMetinler) {
    assert.equal(sifreliMi(m), false, `yanlış pozitif: ${m}`);
    assert.equal(coz(m, TAKIM), m, `düz metin aynen dönmeliydi: ${m}`);
  }
});

test('sifreliMi(): kanonik olmayan base64url zarf sayılmaz', () => {
  // 12 baytı kodlayan 16 karakterlik iki farklı yazım olamaz; ama son
  // karakterin kullanılmayan bitleri değiştirilirse Node yine çözer.
  // Yeniden kodlayıp karşılaştırdığımız için bu gösterim REDDEDİLİR.
  const zarf = sifrele('x', TAKIM);
  const p = zarf.split('.');
  const son = p[2][15];
  const bozukSon = son === 'A' ? 'B' : 'A';
  const kanonikOlmayan = [p[0], p[1], p[2].slice(0, 15) + bozukSon, p[3], p[4]].join('.');
  const yeniden = Buffer.from(p[2].slice(0, 15) + bozukSon, 'base64url')
    .toString('base64url');
  if (yeniden !== p[2].slice(0, 15) + bozukSon) {
    assert.equal(sifreliMi(kanonikOlmayan), false, 'kanonik olmayan gösterim zarf değildir');
  }
});

// ------------------------------------------------------------ anahtar döndürme

test('anahtar döndürme: k1 ile yazılan satır, k2 devredeyken HÂLÂ okunur', () => {
  const eskiTakim = takimKur({ aktif: 'k1', anahtarlar: { k1: K1 } });
  const eskiZarf = sifrele('döndürmeden önce yazıldı', eskiTakim);
  assert.equal(eskiZarf.split('.')[1], 'k1');

  // Döndürme: aktif k2, k1 yalnız OKUMA için tutuluyor.
  const yeniTakim = takimKur({ aktif: 'k2', anahtarlar: { k1: K1, k2: K2 } });
  assert.equal(coz(eskiZarf, yeniTakim), 'döndürmeden önce yazıldı');

  // Yeni yazmalar k2 ile
  const yeniZarf = sifrele('döndürmeden sonra', yeniTakim);
  assert.equal(yeniZarf.split('.')[1], 'k2');
  assert.equal(coz(yeniZarf, yeniTakim), 'döndürmeden sonra');
});

test('eski anahtar .env\'den DÜŞÜRÜLÜRSE o satırlar okunamaz (net hata)', () => {
  const eskiZarf = sifrele('k1 ile yazıldı', takimKur({ aktif: 'k1', anahtarlar: { k1: K1 } }));
  const yalnizK2 = takimKur({ aktif: 'k2', anahtarlar: { k2: K2 } });
  assert.throws(() => coz(eskiZarf, yalnizK2), /anahtar/i);
  // Okuma uçları çökmez, satır null olur (sohbetin tamamı 500 dönmesin).
  const gunlukler = [];
  assert.equal(cozGoster(eskiZarf, yalnizK2, (...a) => gunlukler.push(a.join(' '))), null);
  assert.equal(gunlukler.length, 1, 'olay sessizce yutulmaz, günlüğe düşer');
});

test('aynı kimlikte iki FARKLI anahtar tanımlanırsa açılış reddedilir', () => {
  assert.throws(() => anahtarYukle({
    MESAJ_ANAHTARI: `k1:${K1}`,
    MESAJ_ANAHTARI_ESKI: `k1:${K2}`,
  }), /çakışma/i);
  // Aynı kimlik + AYNI değer sorun değil (kopyala-yapıştır kazası affedilir)
  const t = anahtarYukle({ MESAJ_ANAHTARI: `k1:${K1}`, MESAJ_ANAHTARI_ESKI: `k1:${K1}` });
  assert.equal(t.aktif.kimlik, 'k1');
});

test('MESAJ_ANAHTARI_ESKI kimliksiz yazılamaz', () => {
  assert.throws(() => anahtarYukle({
    MESAJ_ANAHTARI: K1, MESAJ_ANAHTARI_ESKI: K2,
  }), /kN:/);
});

// ------------------------------------------------------------ anahtar yükleme

test('kimliksiz MESAJ_ANAHTARI k1 sayılır (.env\'e sade yapıştırma çalışsın)', () => {
  const t = anahtarYukle({ MESAJ_ANAHTARI: K1 });
  assert.equal(t.aktif.kimlik, 'k1');
  assert.equal(t.acik, true);
  assert.equal(sifrele('x', t).split('.')[1], 'k1');
});

test('anahtar 32 bayt DEĞİLSE net hata (yanlış uzunluk sessizce kabul edilmez)', () => {
  const kisa = crypto.randomBytes(16).toString('base64');
  assert.throws(() => anahtarYukle({ MESAJ_ANAHTARI: kisa }), /32 bayt/);
  assert.throws(() => anahtarYukle({ MESAJ_ANAHTARI: 'bu-base64-degil!!' }), /32 bayt/);
});

test('anahtarUret() 32 baytlık base64 üretir ve her seferinde farklıdır', () => {
  const a = anahtarUret();
  assert.equal(Buffer.from(a, 'base64').length, ANAHTAR_UZUNLUK);
  assert.notEqual(a, anahtarUret());
});

test('base64url yazılmış anahtar da kabul edilir (kopyalama kazası affedilir)', () => {
  const ham = crypto.randomBytes(32);
  const t = anahtarYukle({ MESAJ_ANAHTARI: ham.toString('base64url') });
  assert.ok(t.aktif.anahtar.equals(ham));
});

// -------------------------------------------------- ANAHTAR YOKKEN davranış

test('ANAHTAR YOKSA açılış HATA verir — sessizce düz metne DÜŞMEZ', () => {
  // Karar gerekçesi: sessiz düşüş en tehlikeli sonuçtur. Şifreleme kapanır,
  // hiçbir uç hata vermez, yedek yine düz metin dolar ve kimse fark etmez.
  assert.throws(() => anahtarYukle({}), /MESAJ_ANAHTARI/);
  assert.throws(() => anahtarYukle({ MESAJ_ANAHTARI: '' }), /MESAJ_ANAHTARI/);
  // Hata mesajı NE YAPILACAĞINI söylemeli (gece 3'te log okuyan kişi için)
  try {
    anahtarYukle({});
    assert.fail('hata bekleniyordu');
  } catch (e) {
    assert.match(e.message, /openssl rand -base64 32/);
    assert.match(e.message, /MESAJ_SIFRELEME=kapali/);
  }
});

test('MESAJ_SIFRELEME=kapali AÇIK kaçış: anahtarsız çalışır, metin düz kalır', () => {
  const t = anahtarYukle({ MESAJ_SIFRELEME: 'kapali' });
  assert.equal(t.acik, false);
  assert.equal(t.aktif, null);
  assert.equal(sifrele('düz kalacak', t), 'düz kalacak');
  assert.equal(coz('düz kalacak', t), 'düz kalacak');
  // Kapalıyken bile ESKİ zarflar okunabilmeli mi? Anahtar yok, okunamaz —
  // ama net hata verir, ham zarfı kullanıcıya göstermez.
  assert.throws(() => coz(sifrele('x', TAKIM), t), /anahtar/i);
});

test('takım kurulmadan sifrele() çağrılırsa hata (küresel durum kazası)', () => {
  const onceki = anahtarlar();
  try {
    anahtarlariAyarla(null);
    assert.throws(() => sifrele('x'), /baslat/);
    // baslat() ile kurulunca çalışır
    baslat({ MESAJ_ANAHTARI: K1 });
    assert.equal(coz(sifrele('modül varsayılanıyla')), 'modül varsayılanıyla');
  } finally {
    anahtarlariAyarla(onceki);
  }
});

// ------------------------------------------------------------ metin çeşitleri

test('emoji, RTL, çok dilli ve kontrol karakterli metinler bozulmadan döner', () => {
  const metinler = [
    '👍🏽 harika dizi! 🎬🍿',
    'مرحبا كيف حالك؟',                       // Arapça (RTL)
    'שלום עולם',                             // İbranice (RTL)
    'Merhaba ‮ters yazım‬ sonu',   // RTL override kontrol karakterleri
    'çğıöşü ÇĞİÖŞÜ',
    '日本語のテキストです',
    'satır1\nsatır2\tsekme\r\n',
    'sıfır genişlikli​karakter',
    '  boş bayt  ',
    '.'.repeat(50),                          // ayraçla dolu
    'v'.repeat(1) + '1.k1.' + 'x'.repeat(40),
  ];
  for (const m of metinler) {
    assert.equal(coz(sifrele(m, TAKIM), TAKIM), m, `bozuldu: ${JSON.stringify(m)}`);
  }
});

test('2000 karakterlik emoji mesajı (en kötü durum) bozulmadan döner', () => {
  const m = '😀'.repeat(1000);              // 2000 UTF-16 birimi, 4000 UTF-8 bayt
  const zarf = sifrele(m, TAKIM);
  assert.equal(coz(zarf, TAKIM), m);
  // Şişme ölçümü: bu sayı migrasyonda CHECK kısıtının neden kalktığının
  // gerekçesidir. Kısıt kalsaydı bu INSERT reddedilirdi.
  assert.ok(zarf.length > 2000,
    `en kötü zarf 2000'i aşmalı, ölçülen ${zarf.length}`);
  assert.ok(zarf.length < 12000, `zarf beklenenden uzun: ${zarf.length}`);
});

test('çok uzun metin (100 KB) de çalışır — betik/araç yolları için', () => {
  const m = 'a'.repeat(100_000);
  assert.equal(coz(sifrele(m, TAKIM), TAKIM), m);
});

test('sayı/nesne gibi metin olmayan girdi metne çevrilir, bozulmaz', () => {
  assert.equal(coz(sifrele(42, TAKIM), TAKIM), '42');
  assert.equal(coz(sifrele(true, TAKIM), TAKIM), 'true');
});

// ------------------------------------------------------------ satirCoz yardımcısı

test('satirCoz(): okuma uçlarındaki satırın alanlarını yerinde çözer', () => {
  const satir = {
    id: 7,
    metin: sifrele('asıl mesaj', TAKIM),
    yanit_metin: sifrele('alıntılanan mesaj', TAKIM),
    medya: '/medya/m1-2f2dfa78379e570c.png',
  };
  satirCoz(satir, ['metin', 'yanit_metin'], TAKIM);
  assert.equal(satir.metin, 'asıl mesaj');
  assert.equal(satir.yanit_metin, 'alıntılanan mesaj');
  assert.equal(satir.medya, '/medya/m1-2f2dfa78379e570c.png', 'medya yolu ŞİFRELENMEZ');
});

test('satirCoz(): olmayan alan eklenmez, null alan null kalır', () => {
  const satir = { metin: null };
  satirCoz(satir, ['metin', 'yanit_metin'], TAKIM);
  assert.equal(satir.metin, null);
  assert.ok(!('yanit_metin' in satir), 'tanımsız alan uydurulmaz');
});

// -------------------------------------------------- şema/sözleşme kilitleri

test('sema.sql: 2000 karakterlik CHECK kısıtı DÜŞÜRÜLÜYOR', () => {
  const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
  assert.match(SEMA, /DROP CONSTRAINT IF EXISTS mesajlar_metin_check/,
    'kısıt kalkmazsa uzun mesajın INSERT\'i canlıda 500 verir');
});

test('migrasyon dosyası var ve aynı kısıtı düşürüyor', () => {
  const M = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-07.sql'), 'utf8');
  assert.match(M, /DROP CONSTRAINT IF EXISTS mesajlar_metin_check/);
});

test('mesajlar.metin üzerinde arama/LIKE YOK (şifreli veride arama yapılamaz)', () => {
  // Şifrelemenin bilinen bedeli: şifreli kolonda LIKE/arama çalışmaz.
  // Bu test, ileride biri DM aramaları eklerse KIRMIZIYA döner ve o kişiye
  // "önce arama tasarımını çöz" der.
  const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
  const mesajSorgulari = SERVER.match(/FROM mesajlar[\s\S]{0,600}?(?=`)/g) || [];
  for (const s of mesajSorgulari) {
    assert.ok(!/\bm?\.?metin\s+I?LIKE\b/i.test(s),
      `mesajlar.metin üzerinde LIKE bulundu:\n${s.slice(0, 200)}`);
  }
});

test('bildirimler tablosu mesaj METNİ tutmuyor (bu yüzden şifrelenmiyor)', () => {
  const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
  const tablo = SEMA.match(/CREATE TABLE IF NOT EXISTS bildirimler \(([\s\S]*?)\n\);/);
  assert.ok(tablo, 'bildirimler tablosu bulunamadı');
  assert.ok(!/\bmetin\b/.test(tablo[1]),
    'bildirimler\'e metin kolonu eklendiyse ONU DA ŞİFRELE');
  // Push gövdesindeki metin yalnız FCM\'e gidiyor, DB\'ye yazılmıyor.
  const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
  assert.match(SERVER,
    /INSERT INTO bildirimler \(kullanici_id, tur, aktor_id, yorum_id\)/,
    'bildirim INSERT\'ine yeni kolon eklendiyse bu testi güncelle');
});

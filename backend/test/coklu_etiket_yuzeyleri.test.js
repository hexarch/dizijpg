// ÇOKLU ETİKET HANGİ YÜZEYLERDE DÖNÜYOR — 30 Ağu 2026 KULLANICI BİLDİRİMİ
//
// Birebir: "Dün oyuncu etiketli yorum paylaştım ama profilimdeki yorumlar
// kısmına gittiğimde oyuncunun etiketini göremiyorum aynı şekilde dizinin
// profilinde göremiyorum, mobilde web de aynı sorunlu."
//
// ÖLÇÜM (canlı veritabanı, yorum 5519 — kullanıcı 3):
//   yorumlar.tur/tmdb_id   tv/1438
//   yorum_etiketleri       tv/1438 (sira 0) + person/129101 (sira 1)
// Veri DOĞRUYDU. Kusur yüzeylerdeydi:
//   /akis, /kesfet-akis            etiketler ✓  icerikler ✓  → çiziliyordu
//   /yorumlar/:tur/:tmdbId         etiketler ✓  icerikler ✗  → ad/poster yok,
//                                                              şerit çizilemez
//   /profil/:kullaniciAdi          etiketler ✗  icerikler ✗  → alan hiç yok
//   /gizlenen-yorumlar             etiketler ✗  icerikler ✗
//
// Bu dosya ÜÇ EKSİK YÜZEYİ kilitliyor. Testler kaynak denetimi: uçların hepsi
// canlı DB + TMDB istiyor, ama asıl regresyon riski zaten "yeni bir yorum
// yüzeyi eklenir ve ETİKET ALANI unutulur" biçiminde.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/// Bir uç bildiriminden itibaren N karakter.
function uc(imza, uzunluk = 6000) {
  const i = SERVER.indexOf(imza);
  assert.notEqual(i, -1, `${imza} bulunamadı`);
  return SERVER.slice(i, i + uzunluk);
}

test('İÇERİK SAYFASI: yorum listesi hem etiketleri hem ad/posteri döndürür', () => {
  const g = uc("app.get('/yorumlar/:tur/:tmdbId'", 12000);
  assert.match(g, /\$\{ETIKET_ALANI\}/, 'etiketler alanı düşmüş');
  assert.match(g, /icerikler: await akisIcerikleri\(rows\)/,
    'ad/poster dönmüyor — istemci rozeti çizemez, şerit hiç görünmez');
});

test('PROFİL: yorum sorgusu etiketleri döndürür', () => {
  const g = uc("app.get('/profil/:kullaniciAdi'", 30000);
  assert.match(g, /\$\{ETIKET_ALANI\}/);
});

test('PROFİL: içerik anahtarları ETİKETLERDEN toplanıyor, birincilden değil', () => {
  const g = uc("app.get('/profil/:kullaniciAdi'", 30000);
  assert.match(g, /const icerikler = await akisIcerikleri\(/);
  // OLUMSUZ İDDİA: elle kurulan eski liste yalnız birincil etiketi topluyordu
  // ve ikinci/üçüncü rozet adsız ("?") çizilirdi.
  assert.doesNotMatch(
    g,
    /const anahtarlar = \[\.\.\.new Set\(yorumlar\.rows\.flatMap/,
    'eski birincil-etiket-only anahtar listesi geri gelmiş',
  );
  // Yanıtlarda kart ASIL gönderiyi de çiziyor: onun anahtarı da katılmalı.
  assert.match(g, /yorumlar\.rows\.filter\(\(y\) => y\.ust\)\.map\(\(y\) => y\.ust\)/);
});

test('GİZLENEN YORUMLAR: aynı kart, aynı sözleşme', () => {
  const g = uc("app.get('/gizlenen-yorumlar'", 3000);
  assert.match(g, /\$\{ETIKET_ALANI\}/);
  assert.match(g, /const icerikler = await akisIcerikleri\(rows\)/);
});

test('akisIcerikleri ETİKETSİZ gönderiden anahtar üretmez', () => {
  // `tur` NULL olan gönderi "null:null" anahtarı üretirse TMDB'ye /null/null
  // yolu gider (her istekte boşa giden dış çağrı + kartta hayalet kayıt).
  const g = uc('async function akisIcerikleri(', 900);
  assert.match(g, /if \(r\.tur && r\.tmdb_id != null\)/);
  assert.match(g, /if \(e && e\.tur && e\.tmdb_id != null\)/);
});

test('ETİKET_ALANI sırayı koruyor (birincil = sira 0)', () => {
  const i = SERVER.indexOf('const ETIKET_ALANI');
  const g = SERVER.slice(i, i + 700);
  // İstemci "birinciyi at" kuralını sıraya göre uyguluyor (ProfilYorumKarti,
  // AkisKarti). Sıralama düşerse birincil etiket rozet şeridinde TEKRAR çizilir.
  assert.match(g, /ORDER BY e\.sira, e\.id/);
  assert.match(g, /coalesce\(json_agg/, "etiketsiz gönderide '[]' dönmeli");
});

// AKIŞ + KEŞFET: AI hesabının (`kullanicilar.ai`) gönderileri DIŞARIDA
// (19 Eyl 2026 kullanıcı kararı).
//
// GEREKÇE: `dizi.jpg.ai` (id 51) 2.484 yapım yorumu yazdı. Hepsi akışa
// düşünce akış bir SOSYAL yüzey olmaktan çıkıp robot duvarına dönüyordu.
//
// KAPSAM SINIRI — TESTİN ASIL İŞİ BU: metinler YERİNDE KALMALI. Yapım
// sayfasının yorum listesi, SSR bot sayfası ve sitemap kapsamı
// (`ozgunIcerikVar` → `SEO_YORUM_KOSUL`) AI yorumlarını görmeye DEVAM eder.
// Süzgeç oraya sızarsa site tek hamlede 2.153 indekslenebilir içerik
// sayfası kaybeder — 19 Eyl'de `yasakli` bayrağıyla tam bu yaşandı.
//
// SÜZGEÇ NEDEN `AKIS_GOVDE`DE: `/akis` ve `/kesfet-akis` bu gövdeyi
// PAYLAŞIYOR. Uçlara ayrı ayrı yazılsaydı biri unutulurdu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** Bir şablon sabitinin gövdesi, `--` yorum satırları atılmış hâlde. */
function sablon(ad) {
  const bas = SERVER.indexOf(`const ${ad} = \``);
  assert.notEqual(bas, -1, `${ad} bulunamadı`);
  const son = SERVER.indexOf('`;', bas);
  return SERVER.slice(bas, son)
    .split('\n').filter((s) => !s.trim().startsWith('--')).join('\n');
}

test('AKIS_GOVDE AI hesabını dışlıyor', () => {
  assert.match(sablon('AKIS_GOVDE'), /AND NOT coalesce\(k\.ai, false\)/,
    'akış/Keşfet AI süzgeci kaybolmuş — AI yorumları akışa döner');
});

test('akış ve Keşfet AYNI gövdeyi kullanıyor (süzgeç tek noktada)', () => {
  // Uçların kendi SQL'ini yazmaya başlaması, süzgecin birinde unutulması
  // demektir. `AKIS_GOVDE` kullanımı 1'e düşerse bu test uyarır.
  const say = (SERVER.match(/\$\{AKIS_GOVDE\}/g) || []).length;
  assert.ok(say >= 2, `AKIS_GOVDE yalnız ${say} yerde kullanılıyor`);
});

test('SEO yüzeyi AI yorumlarını GÖRMEYE devam ediyor', () => {
  // `SEO_YORUM_KOSUL` sitemap kapsamını da (`SITEMAP_SORGU`) indeks eşiğini
  // de (`ozgunIcerikVar`) besler. İçine `ai` süzgeci girerse içerik ailesi
  // 2.637 → 484 URL'ye çöker.
  const bas = SERVER.indexOf('const SEO_YORUM_KOSUL =');
  assert.notEqual(bas, -1, 'SEO_YORUM_KOSUL bulunamadı');
  const kosul = SERVER.slice(bas, SERVER.indexOf(';', bas));
  assert.ok(!/\bk\.ai\b/.test(kosul),
    'SEO yorum koşuluna AI süzgeci sızmış — sitemap ve indeks eşiği çöker');
});

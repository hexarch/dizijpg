// GEO — AI CEVAP BOTLARI SSR ALIR, EĞİTİM BOTLARI ALMAZ (27 Ağu 2026).
//
// KORUDUĞU KARAR (GEO-PLANI.md v1.0 §3): üretken arama motorlarının CEVAP
// botları `$og_bot` regex'ine eklendi. Öncesinde ChatGPT Search / Perplexity /
// Claude sayfayı istese SSR değil BOŞ FLUTTER KABUĞU alıyordu.
//
// ÖLÇÜM (27 Ağu, origin'den — Cloudflare atlanarak, çünkü CF bu UA'ları
// 403'lüyor ve istek nginx'e hiç ulaşmıyor):
//   OAI-SearchBot / ChatGPT-User / PerplexityBot / Perplexity-User /
//   Claude-User / Claude-SearchBot / Googlebot → 200 + 16.215 bayt SSR
//   insan (Chrome) → 200 + 12.680 bayt kabuk   ← DEĞİŞMEDİ
//   GPTBot (eğitim) → 200 + 12.680 bayt kabuk  ← İSTENEN
//
// BU DOSYANIN ASIL İŞİ İKİ DOSYAYI HİZALI TUTMAK: `robots.txt` "kim girebilir"
// beyanıdır, nginx regex'i "kime İÇERİK veririz" kararıdır. Ayrışırlarsa ya
// eğitim botuna beyanımıza aykırı içerik veririz ya da cevap botunu davet edip
// eli boş göndeririz.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const PARCA = fs.readFileSync(
  path.join(KOK, 'nginx-geo-20260827.parca.conf'), 'utf8');
const ROBOTS = fs.readFileSync(path.join(KOK, 'robots.txt'), 'utf8');

// Regex satırı: map bloğundaki tek `~*(...)` satırı.
const REGEX_SATIRI = (PARCA.match(/^\s*~\*\([^)]*\)\s*1;/m) || [''])[0];

// Cevap/arama botları — SSR ALMALI (robots.txt `use=reference` izninin karşılığı).
const CEVAP_BOTLARI = ['OAI-SearchBot', 'ChatGPT-User', 'PerplexityBot',
  'Perplexity-User', 'Claude-User', 'Claude-SearchBot'];

// Eğitim botları — SSR ALMAMALI (robots.txt `ai-train=no`, kullanıcı kararı).
const EGITIM_BOTLARI = ['GPTBot', 'ClaudeBot', 'CCBot', 'Bytespider',
  'Amazonbot', 'meta-externalagent', 'Applebot-Extended'];

test('regex satırı bulunuyor ve map bloğunda tek', () => {
  assert.ok(REGEX_SATIRI, 'parça dosyasında ~*(...) satırı yok');
  assert.equal((PARCA.match(/^\s*~\*\([^)]*\)\s*1;/gm) || []).length, 1,
    'birden fazla regex satırı — hangisi canlıya gidecek belirsiz');
  assert.match(PARCA, /map \$http_user_agent \$og_bot \{/);
  assert.match(PARCA, /default 0;/, 'varsayılan 0 değil — herkes SSR alırdı');
});

test('altı AI CEVAP botu da regexte', () => {
  for (const bot of CEVAP_BOTLARI) {
    assert.ok(REGEX_SATIRI.includes(`|${bot}|`) || REGEX_SATIRI.includes(`|${bot})`),
      `cevap botu regexte yok: ${bot}`);
  }
});

test('EĞİTİM botları regexte YOK (beyanla çelişmesin)', () => {
  for (const bot of EGITIM_BOTLARI) {
    // Kelime sınırı şart: `Applebot` regexte VAR (önizleme/Spotlight botu),
    // `Applebot-Extended` (eğitim) olmamalı. Düz `includes` ikisini karıştırır.
    assert.doesNotMatch(REGEX_SATIRI, new RegExp(`\\|${bot}[|)]`),
      `eğitim botuna SSR veriliyor: ${bot}`);
  }
  // Karıştırma tuzağının kendisi: Applebot VAR, Applebot-Extended YOK.
  assert.match(REGEX_SATIRI, /\|Applebot\|/,
    'Applebot (link önizleme) düşmüş — WhatsApp/iMessage önizlemesi bozulur');
});

test('MEVCUT botlar korunuyor (gerileme yok)', () => {
  // 27 Ağu değişikliği yalnız EKLEME olmalı. Biri düşerse link önizlemesi ya
  // da klasik arama sessizce bozulur.
  for (const bot of ['facebookexternalhit', 'Twitterbot', 'WhatsApp', 'Slackbot',
    'TelegramBot', 'LinkedInBot', 'Discordbot', 'redditbot', 'Googlebot',
    'GoogleOther', 'bingbot', 'DuckDuckBot', 'Yandex', 'Google-InspectionTool']) {
    assert.ok(REGEX_SATIRI.includes(bot), `mevcut bot düşmüş: ${bot}`);
  }
});

test('robots.txt ile HİZALI: eğitime kapalı, cevaba açık', () => {
  // Beyan tarafı: her eğitim botunun kendi Disallow bloğu olmalı.
  for (const bot of ['GPTBot', 'ClaudeBot', 'CCBot', 'Bytespider',
    'Amazonbot', 'Applebot-Extended', 'meta-externalagent']) {
    assert.match(ROBOTS, new RegExp(`User-agent: ${bot}\\s*\\nDisallow: /`),
      `robots.txt'te eğitim botu kapatılmamış: ${bot}`);
  }
  // Cevap botları robots.txt'te KAPATILMAMALI — `User-agent: *` altında
  // Allow ile geçerler. Adlarına özel bir Disallow bloğu varsa çelişkidir.
  for (const bot of CEVAP_BOTLARI) {
    assert.doesNotMatch(ROBOTS, new RegExp(`User-agent: ${bot}\\s*\\nDisallow: /`),
      `cevap botu robots.txt'te kapatılmış ama nginx'te SSR alıyor: ${bot}`);
  }
  // Politikanın kendisi yazılı kalmalı.
  assert.match(ROBOTS, /Content-Signal: search=yes,ai-train=no,use=reference/,
    'Content-Signal beyanı kaybolmuş — GEO kararının yazılı dayanağı bu');
  // Google-Extended BİLEREK açık (AI Overviews atfı).
  assert.doesNotMatch(ROBOTS, /User-agent: Google-Extended\s*\nDisallow: \//,
    'Google-Extended kapatılmış — AI Overviews kaynak gösterimi biter');
});

test('parça dosyası uygulama/doğrulama/geri alma yazıyor', () => {
  // 6 Ağu parçalarından beri süren disiplin: elle uygulanan her nginx
  // değişikliği nereye gideceğini, nasıl doğrulanacağını ve nasıl geri
  // alınacağını KENDİ İÇİNDE taşır.
  for (const bas of ['NEREYE', 'UYGULAMA', 'DOGRULAMA', 'GERI ALMA']) {
    assert.ok(PARCA.includes(bas), `parça dosyasında ${bas} bölümü yok`);
  }
  // Doğrulamanın CF'ten geçmediği açıkça yazılı olmalı: dışarıdan curl ile
  // test eden biri 403 görüp "olmadı" sanır.
  assert.match(PARCA, /127\.0\.0\.1/,
    'doğrulama origin üzerinden anlatılmamış — dışarıdan CF 403 verir');
});

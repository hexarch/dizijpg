import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { alan, KAYNAK, KOK } from './yardimci/seo_kaynak.js';

const seoKamuYolu = alan(['seoKamuYolu'], 'seoKamuYolu');
const seoKanonikYol = alan(
  ['seoKamuYolu', 'seoKanonikYol'], 'seoKanonikYol');
const kanonikUrl = alan(
  ['SITE_KOK', 'seoKamuYolu', 'seoKanonikYol', 'kanonikUrl'], 'kanonikUrl');

test('seoKanonikYol sondaki eğik çizgiyi ve baştaki sıfırları düşürür', () => {
  assert.equal(seoKanonikYol('/icerik/tv/1396/'), '/icerik/tv/1396');
  assert.equal(seoKanonikYol('/icerik/tv/01396'), '/icerik/tv/1396');
  assert.equal(seoKanonikYol('/Icerik/TV/01396/'), '/icerik/tv/1396');
  assert.equal(seoKanonikYol('/og/icerik/tv/01396'), '/icerik/tv/1396');
  assert.equal(seoKanonikYol('/dizi/1396/sezon/01/bolum/02'),
    '/dizi/1396/sezon/1/bolum/2');
  assert.equal(seoKamuYolu('/og/icerik/tv/1'), '/icerik/tv/1');
});

test('kanonikUrl UTM ve sıfırlı kimliği tek adrese indirger', () => {
  assert.equal(
    kanonikUrl('https://dizijpg.com/icerik/tv/01396?utm_source=x'),
    'https://dizijpg.com/icerik/tv/1396');
  assert.equal(
    kanonikUrl('https://dizijpg.com/icerik/tv/1396/'),
    'https://dizijpg.com/icerik/tv/1396');
});

test('/og middleware sapma yolda 301 üretir', () => {
  assert.match(KAYNAK, /if \(kamu !== kanon\)/);
  assert.match(KAYNAK, /res\.redirect\(301, SITE_KOK \+ kanon\)/);
  assert.match(KAYNAK, /app\.get\('\/ads\.txt'/);
  assert.match(KAYNAK, /stale-while-revalidate=86400/);
});

test('nginx sapma yolları 301 ile kanoniğe alır ve ads.txt HTML basmaz', () => {
  const dizin = path.join(KOK);
  const aday = fs.readdirSync(dizin)
    .filter((f) => /^nginx-dizijpg\.com-.*\.conf$/.test(f))
    .sort()
    .at(-1);
  assert.ok(aday, 'nginx conf yok');
  const conf = fs.readFileSync(path.join(dizin, aday), 'utf8');
  assert.match(conf, /location = \/ads\.txt/);
  assert.match(conf, /rewrite \^\/\(icerik\|gonderi\|kisi\|dizi\|listeler\|sirket\)\/\(\.\+\)\/\$/);
  assert.match(conf, /rewrite \^\/icerik\/\(tv\|movie\)\/0\+\(\[1-9\]\[0-9\]\*\)\$/);
  assert.match(conf, /location ~\* \^\/\(icerik\|gonderi\|kisi\|dizi\|listeler\|sirket\)\//);
  assert.match(conf, /\[Ii\]\[Cc\]\[Ee\]\[Rr\]\[Ii\]\[Kk\]/,
    'büyük harf /Icerik/ 301 kanoniğe alınmıyor');
  assert.match(conf, /GoogleOther/, 'GoogleOther bot SSR kapısından geçmiyor');
  assert.match(conf, /DuckDuckBot/, 'DuckDuckBot SSR kapısından geçmiyor');
});

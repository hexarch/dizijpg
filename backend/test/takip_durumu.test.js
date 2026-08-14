// Takip listesi satır alanı — `node --test backend/test/*.test.js`
//
// 14 Ağu 2026: `/takipciler`, `/takipedilenler` ve `/kullanici-ara` uçları
// satır başına `takip_ediyorum` (+ `ben_mi`) döndürür. Eski istemci kendi
// takip listesini LIMIT 500 ile çekip satırları o kümeyle karşılaştırıyordu;
// 501. kişiden sonrası yanlışlıkla "Takip Et" görünüyordu. Satır alanı küme
// boyutundan bağımsız doğru. Eski alanlar (kullanici_adi, avatar, bio) durur
// — Play'deki 1.40 istemcisi yeni alanı yok sayar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KAYNAK = fs.readFileSync(
  path.join(path.dirname(path.dirname(fileURLToPath(import.meta.url))), 'server.js'),
  'utf8');

function bolum(bas, son) {
  const i = KAYNAK.indexOf(bas);
  assert.notEqual(i, -1, `kaynakta bulunamadı: ${bas}`);
  const j = KAYNAK.indexOf(son, i + bas.length);
  assert.notEqual(j, -1, `kaynakta bulunamadı: ${son}`);
  return KAYNAK.slice(i, j);
}

test('takipListesi satır başına takip_ediyorum ve ben_mi seçer', () => {
  const b = bolum('async function takipListesi(', "app.get('/takipciler/");
  assert.match(b, /AS takip_ediyorum/);
  assert.match(b, /AS ben_mi/);
  // Karar, görüntüleyenin id'sine bakmalı (liste sahibine değil).
  assert.match(b, /t2\.takip_eden_id = \$2::int/);
  assert.match(b, /t2\.takip_edilen_id = ku\.id/);
});

test('kullanici-ara satır başına takip_ediyorum ve ben_mi seçer', () => {
  const b = bolum("app.get('/kullanici-ara'", "app.post('/veri/disa-aktar'");
  assert.match(b, /AS takip_ediyorum/);
  assert.match(b, /AS ben_mi/);
  assert.match(b, /t\.takip_eden_id = \$3::int/);
});

test('eski liste alanları duruyor (Play 1.40 uyumu)', () => {
  const b = bolum('async function takipListesi(', "app.get('/takipciler/");
  assert.match(b, /ku\.kullanici_adi/);
  assert.match(b, /ku\.avatar/);
  assert.match(b, /ku\.bio/);
});

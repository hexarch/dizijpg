// Tek kullanımlık medya (15 Eyl 2026, migrasyon-2026-09-15b).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'path';
import { fileURLToPath } from 'url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function ucGovdesi(yol, yontem = 'post') {
  const kacir = yol.replace(/[/:\-.]/g, (c) => (c === '/' ? '\\/' : `\\${c}`));
  const m = new RegExp(
    `app\\.${yontem}\\('${kacir}'[\\s\\S]*?\\n\\}\\)\\);`,
  ).exec(SERVER);
  assert.ok(m, `${yontem.toUpperCase()} ${yol} ucu bulunamadı`);
  return m[0];
}

test('POST /mesajlar: bayrak yalnız TEK medyalı, sessiz olmayan mesajda', () => {
  const g = ucGovdesi('/mesajlar');
  assert.match(g, /tek_kullanimlik: tekKullanimlikHam = false/);
  assert.match(g, /if \(tekKullanimlik && \(!ilkMedya \|\| medyalar \|\| sesMi\)\)/);
  assert.match(g, /tek_kullanimlik\)\s*\n\s*VALUES \(\$1,\$2,\$3,\$4,\$5,\$6,\$7,\$8,\$9,\$10,\$11,\$12,\$13,\$14,\$15\)/);
  assert.match(g, /dosyaTur, tekKullanimlik\]/);
});

test('GET /mesajlar: açılınca ya da gönderene medya yolu GİTMEZ', () => {
  const g = ucGovdesi('/mesajlar/:kullaniciAdi', 'get');
  assert.match(g, /m\.tek_kullanimlik, m\.tek_acildi/);
  assert.match(
    g,
    /if \(r\.tek_kullanimlik && \(r\.tek_acildi \|\| r\.gonderen_id === req\.kullanici\.id\)\) \{\s*r\.medya = null;\s*r\.medyalar = null;/,
  );
});

test('POST /mesajlar/:id/tek-acildi: yalnız alıcı, bir kez, dosya silinir', () => {
  const g = ucGovdesi('/mesajlar/:id/tek-acildi');
  assert.match(g, /girisZorunlu/);
  assert.match(g, /WHERE id=\$1 AND alici_id=\$2 AND tek_kullanimlik AND tek_acildi IS NULL/);
  assert.match(g, /fs\.unlink\(path\.join\(MEDYA_DIZIN, ad\)/);
  assert.match(g, /OZEL_MEDYA\.delete\(ad\)/);
  assert.match(g, /yayinla\('ozel_medya_sil', ad\)/);
});

test('/sohbetler önizleme bayrağı taşır; migrasyon + şema kolonları', () => {
  const liste = ucGovdesi('/sohbetler', 'get');
  assert.match(liste, /m\.dosya_ad, m\.tek_kullanimlik,/);
  const mig = fs.readFileSync(path.join(KOK, 'migrasyon-2026-09-15b.sql'), 'utf8');
  assert.match(mig, /ADD COLUMN IF NOT EXISTS tek_kullanimlik BOOLEAN NOT NULL DEFAULT false/);
  assert.match(mig, /ADD COLUMN IF NOT EXISTS tek_acildi TIMESTAMPTZ/);
  const sema = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
  assert.match(sema, /tek_kullanimlik BOOLEAN NOT NULL DEFAULT false/);
  assert.match(sema, /tek_acildi TIMESTAMPTZ/);
});

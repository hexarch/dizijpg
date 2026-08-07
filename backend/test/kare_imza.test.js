// kare_imza.js — algısal tekrar süzgecinin sözleşme testleri.
// Görseller sentetik üretilir (ffmpeg lavfi), böylece test ağa ve /medya
// içeriğine bağlı değildir. ffmpeg yoksa test atlanır.
import { test, before } from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFileSync, spawnSync } from 'child_process';
import { imzaCikar, ayniGorsel, hizaliSkor } from '../kare_imza.js';

const ffmpegVar = spawnSync('ffmpeg', ['-version']).status === 0;
const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'kareimza-'));

// testsrc2 sahnesi: karmaşık ve deterministik. Aynı kareden türetilen
// varyantlar "aynı görsel", farklı kare "farklı görsel" sayılmalı.
const uret = (ad, sure, filtre) => {
  const p = path.join(dizin, ad);
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-f', 'lavfi',
    '-i', `testsrc2=size=640x360:rate=1:duration=1`, '-ss', String(sure),
    ...(filtre ? ['-vf', filtre] : []), '-frames:v', '1', p]);
  return p;
};

let asil, kirpilmis, karartilmis, yazili, farkli;
before(() => {
  if (!ffmpegVar) return;
  asil = uret('asil.jpg', 0, null);
  // %75 merkez kırpım + geri ölçekleme (TMDB'nin ayrı backdrop diye sunduğu tür)
  kirpilmis = uret('kirp.jpg', 0, 'crop=iw*0.75:ih*0.75,scale=640:360');
  // renk derecelendirme farkı
  karartilmis = uret('karart.jpg', 0, 'eq=brightness=-0.18:contrast=1.3');
  // üstüne yazı basılmış varyant
  yazili = uret('yazi.jpg', 0, 'drawbox=x=0:y=260:w=640:h=100:color=black@0.85:t=fill');
  // tamamen başka bir kare
  farkli = uret('farkli.jpg', 0, 'hue=h=180,transpose=1,scale=640:360,vflip');
});

test('aynı görselin kırpımı tekrar sayılır', { skip: !ffmpegVar }, async () => {
  const a = await imzaCikar(asil), b = await imzaCikar(kirpilmis);
  assert.ok(a && b, 'imza çıkarılamadı');
  assert.ok(ayniGorsel(a, b), `kırpım tekrar sayılmadı (skor ${hizaliSkor(a, b).toFixed(3)})`);
});

test('renk derecelendirme farkı tekrar sayılır', { skip: !ffmpegVar }, async () => {
  const a = await imzaCikar(asil), b = await imzaCikar(karartilmis);
  assert.ok(ayniGorsel(a, b), `renk varyantı tekrar sayılmadı (skor ${hizaliSkor(a, b).toFixed(3)})`);
});

test('üstüne yazı basılmış varyant tekrar sayılır', { skip: !ffmpegVar }, async () => {
  const a = await imzaCikar(asil), b = await imzaCikar(yazili);
  assert.ok(ayniGorsel(a, b), `yazılı varyant tekrar sayılmadı (skor ${hizaliSkor(a, b).toFixed(3)})`);
});

test('farklı görsel tekrar SAYILMAZ', { skip: !ffmpegVar }, async () => {
  const a = await imzaCikar(asil), b = await imzaCikar(farkli);
  assert.strictEqual(ayniGorsel(a, b), null,
    `farklı görsel yanlışlıkla elendi (skor ${hizaliSkor(a, b).toFixed(3)})`);
});

test('kare kendisiyle karşılaştırılınca skor 1.0', { skip: !ffmpegVar }, async () => {
  const a = await imzaCikar(asil);
  assert.ok(hizaliSkor(a, a) > 0.999);
});

test('okunamayan dosya null döner, çökmez', async () => {
  const bos = path.join(dizin, 'bozuk.jpg');
  fs.writeFileSync(bos, 'bu bir jpeg değil');
  assert.strictEqual(await imzaCikar(bos), null);
  assert.strictEqual(ayniGorsel(null, null), null); // çağıran taraf eleme yapmaz
});

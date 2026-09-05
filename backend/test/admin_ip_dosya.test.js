// ADMIN_IPLER_DOSYA — admin IP listesinin SICAK kaynağı (5 Eyl 2026).
//
// NEDEN: liste yalnız açılışta env'den okunuyordu; IP her değiştiğinde
// konteyner yeniden yaratılıyor, her yaratma Googlebot'a 502 penceresi
// açıyordu (GSC "Sunucu hatası (5xx)" 37 URL). Artık dosyadan okunuyor.
//
// BU DOSYA BİR GÜVENLİK KİLİDİDİR: dosya BOŞ ise kapı KAPALI kalmalı (env'e
// düşülmemeli); dosya YOK ise env'deki liste geçerli olmalı; değişiklik
// önbellek süresi dolunca görünmeli.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { bildirimCek } from './yardimci/seo_kaynak.js';

const kur = (dosya, env) => new Function('fs', 'ADMIN_IPLER_DOSYA', 'ADMIN_IPLER', `
  ${bildirimCek('adminIpAyristir')}
  ${bildirimCek('adminIpOnbellek')}
  ${bildirimCek('adminIpListesi')}
  return { adminIpAyristir, adminIpListesi };
`)(fs, dosya, env);

test('ayrıştırıcı: satır ve virgül ayraç, yorum ve boşluk temizlenir', () => {
  const { adminIpAyristir } = kur('', '');
  assert.deepEqual(
    adminIpAyristir('1.2.3.4, 2a00::/64\n# yorum\n 5.6.7.8 # ev\n\n'),
    ['1.2.3.4', '2a00::/64', '5.6.7.8'],
  );
  assert.deepEqual(adminIpAyristir(''), []);
  assert.deepEqual(adminIpAyristir(undefined), []);
});

test('dosya yolu boşsa env listesi kullanılır', () => {
  const { adminIpListesi } = kur('', '9.9.9.9,8.8.8.8');
  assert.deepEqual(adminIpListesi(), ['9.9.9.9', '8.8.8.8']);
});

test('dosya YOKSA env listesine düşülür (fail-closed değil, fail-env)', () => {
  const yol = path.join(os.tmpdir(), `dizijpg-admin-ip-yok-${process.pid}.txt`);
  const { adminIpListesi } = kur(yol, '9.9.9.9');
  assert.deepEqual(adminIpListesi(), ['9.9.9.9']);
});

test('dosya VARSA env yok sayılır; BOŞ dosya = kapı kapalı', () => {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'dizijpg-admin-ip-'));
  const yol = path.join(dizin, 'ipler.txt');
  let geriAl = () => {};
  try {
    fs.writeFileSync(yol, '1.1.1.1\n');
    const { adminIpListesi } = kur(yol, '9.9.9.9');
    assert.deepEqual(adminIpListesi(), ['1.1.1.1']);
    fs.writeFileSync(yol, '');
    // Önbellek 2 sn: hemen okunursa eski liste dönebilir; bu istenen davranış.
    // Süre dolunca boş liste — env'e DÜŞMEZ.
    geriAl = saatiIleriAl();
    assert.deepEqual(adminIpListesi(), []);
  } finally {
    geriAl();
    fs.rmSync(dizin, { recursive: true, force: true });
  }
});

test('değişiklik önbellek süresi dolunca görünür (atomik mv dahil)', () => {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'dizijpg-admin-ip-'));
  const yol = path.join(dizin, 'ipler.txt');
  let geriAl = () => {};
  try {
    fs.writeFileSync(yol, '1.1.1.1\n');
    const { adminIpListesi } = kur(yol, '');
    assert.deepEqual(adminIpListesi(), ['1.1.1.1']);
    fs.writeFileSync(`${yol}.gecici`, '2.2.2.2,3.3.3.3\n');
    fs.renameSync(`${yol}.gecici`, yol);
    geriAl = saatiIleriAl();
    assert.deepEqual(adminIpListesi(), ['2.2.2.2', '3.3.3.3']);
  } finally {
    geriAl();
    fs.rmSync(dizin, { recursive: true, force: true });
  }
});

// Önbellek 2 sn zaman damgasıyla çalışır; testte beklemek yerine saati
// ileri alıyoruz (`adminIpListesi` `Date.now()` çağırır). Dönen fonksiyon
// saati geri alır; finally'de ÇAĞRILMALI.
function saatiIleriAl() {
  const gercek = Date.now;
  const kayik = gercek() + 3000;
  Date.now = () => kayik;
  return () => { Date.now = gercek; };
}

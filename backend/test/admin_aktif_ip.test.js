// Admin paneli: çevrimiçi kullanıcıların YANINDAKİ "aktif IP" sayacı
// (14 Eyl 2026 isteği: "çevrimiçi kullanıcılar kısmının yanına aktif ip
// sayısını koy").
//
// Sayaç, çevrimiçi KİŞİ sayısıyla aynı şeyi ölçmez: kişi sayısı hesabın
// son_gorulme damgasından gelir, IP sayısı ham trafikten — girişsiz
// ziyaretçi ve bot da bir IP'dir. Bu test iki şeyi bekçiler:
//   1) sayım doğru (tekilleştirme + 3 dk penceresi),
//   2) bellek-içi halka pencereyi kapsamıyorsa sayı TABAN olarak işaretlenir
//      (alt_sinir) — panel "≥" basar, uydurma sayı göstermeyiz.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { aktifIpOzeti, CEVRIMICI_ESIK_SN } from '../cevrimici.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SIMDI = 1_700_000_000_000;
const sn = (x) => SIMDI - x * 1000;

test('aynı IP bir kez sayılır, pencere dışı istek sayılmaz', () => {
  const ozet = aktifIpOzeti([
    { ip: '1.1.1.1', ts: sn(5) },
    { ip: '1.1.1.1', ts: sn(30) },   // aynı IP → tek
    { ip: '2.2.2.2', ts: sn(179) },  // pencerenin içinde (sınıra yakın)
    { ip: '3.3.3.3', ts: sn(181) },  // 3 dk'yı GEÇMİŞ → sayılmaz
    { ts: sn(2) },                   // IP'siz kayıt → sayılmaz
  ], { simdi: SIMDI });
  assert.equal(ozet.sayi, 2);
  assert.equal(ozet.dakika, CEVRIMICI_ESIK_SN / 60);
  assert.equal(ozet.alt_sinir, false);
});

test('halka penceredan eskiyi görüyorsa sayı KESİN (alt_sinir false)', () => {
  // Halka dolu ama en eski kayıt pencereden daha eski: 3 dk'nın tamamını
  // görüyoruz demektir.
  const halka = Array.from({ length: 400 }, (_, i) => ({ ip: 'a', ts: sn(i) }));
  assert.equal(aktifIpOzeti(halka, { simdi: SIMDI, sinir: 400 }).alt_sinir, false);
});

test('halka dolu ve tamamı pencerenin içindeyse sayı TABANDIR', () => {
  // Yoğun dakika: 400 kaydın en eskisi bile 3 dk'dan yeni → öncesini
  // göremiyoruz, gerçek sayı daha büyük olabilir.
  const halka = Array.from({ length: 400 }, (_, i) => ({ ip: 'ip' + i, ts: sn(i % 60) }));
  const ozet = aktifIpOzeti(halka, { simdi: SIMDI, sinir: 400 });
  assert.equal(ozet.sayi, 400);
  assert.equal(ozet.alt_sinir, true);
});

test('bozuk/boş girdi çökertmez', () => {
  assert.equal(aktifIpOzeti(undefined).sayi, 0);
  assert.equal(aktifIpOzeti([null, { ip: 'x' }, { ts: 'abc' }], { simdi: SIMDI }).sayi, 0);
});

test('uç ve panel bağlı: /admin/hareketler aktif_ip döner, panel basar', () => {
  const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
  const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
  assert.match(SERVER, /aktifIpOzeti\(\(await istekVerisi\(\)\)\.son/);
  assert.match(SERVER, /aktif_ip: aktifIp,/);
  assert.match(ADMIN, /id="cev-ip"/);
  assert.match(ADMIN, /aktif IP/);
  // Taban işareti panelde gerçekten "≥" olarak basılıyor mu?
  assert.match(ADMIN, /alt_sinir\?'≥':''/);
});

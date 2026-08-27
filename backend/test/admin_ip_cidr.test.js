// ADMIN_IPLER artık CIDR kabul ediyor (27 Ağu 2026).
//
// NEDEN: liste bugüne kadar BİREBİR METİN karşılaştırılıyordu. IPv4'te sorun
// değildi; IPv6'da panel pratikte KAPALIYDI. Ölçüm (27 Ağu, yerel Mac):
//   curl https://dizijpg.com/api/admin            → 404 (IPv6 ile bağlanıyor)
//   curl -4 https://dizijpg.com/api/admin         → 200 (IPv4 listede)
// IPv6 privacy extensions (RFC 4941) arayüz kimliğini saatler içinde
// döndürdüğü için tek adres yazmak paneli kısa sürede yeniden kapatırdı;
// bu yüzden /64 öneki gerekiyor.
//
// BU DOSYA BİR GÜVENLİK KİLİDİDİR. Eşleyici gevşerse admin paneli internete
// açılır, o yüzden testlerin çoğu "eşleşMEMELİ" yönünde.
import test from 'node:test';
import assert from 'node:assert/strict';
import net from 'node:net';
import { bildirimCek, KAYNAK } from './yardimci/seo_kaynak.js';

// `alan()` kullanılamıyor: `ipBaytlari` modül düzeyindeki `net` importunu
// kullanıyor ve `new Function` gövdesi import görmez. Bağımlılığı parametre
// olarak veriyoruz — sınanan kod yine CANLI kaynaktan geliyor, kopya değil.
const { ipEslesir, ipBaytlari } = new Function('net', `
  ${bildirimCek('ipBaytlari')}
  ${bildirimCek('ipEslesir')}
  return { ipBaytlari, ipEslesir };
`)(net);

test('öneksiz kural ESKİ davranışı korur: tam eşitlik', () => {
  assert.equal(ipEslesir('188.119.45.48', '188.119.45.48'), true);
  assert.equal(ipEslesir('188.119.45.49', '188.119.45.48'), false);
  // Komşu adres öneksiz kuralda ASLA eşleşmez (yanlışlıkla /24 gibi davranmaz).
  assert.equal(ipEslesir('188.119.45.0', '188.119.45.48'), false);
});

test('IPv6 /64: aynı abonelik prefiksi eşleşir, komşu prefiks EŞLEŞMEZ', () => {
  const kural = '2a00:1d34:5517:c00::/64';
  // 27 Ağu'da ölçülen gerçek adresimiz.
  assert.equal(ipEslesir('2a00:1d34:5517:c00:4d0a:a035:e46e:d2e7', kural), true);
  // Privacy extensions arayüz kimliğini döndürür — kural bunu KAPSAMALI.
  assert.equal(ipEslesir('2a00:1d34:5517:c00:1:2:3:4', kural), true);
  assert.equal(ipEslesir('2a00:1d34:5517:c00::1', kural), true);
  // /64'ün DIŞI: dördüncü grup farklı → komşu abone paneli açamaz.
  assert.equal(ipEslesir('2a00:1d34:5517:c01::1', kural), false);
  assert.equal(ipEslesir('2a00:1d34:5517:bff::1', kural), false);
  assert.equal(ipEslesir('2a01:1d34:5517:c00::1', kural), false);
});

test('AİLE KARIŞMASI eşleşme sayılmaz (IPv4 kuralı IPv6 istemciyi açmaz)', () => {
  assert.equal(ipEslesir('2a00:1d34:5517:c00::1', '85.101.152.180'), false);
  assert.equal(ipEslesir('85.101.152.180', '2a00:1d34:5517:c00::/64'), false);
  assert.equal(ipEslesir('85.101.152.180', '::/0'), false);
});

test('BOZUK kural kapıyı AÇMAZ (fail-closed)', () => {
  for (const kural of [
    '', '/', '/64', 'abc', '2a00::/', '2a00::/x', '2a00::/-1', '2a00::/129',
    '85.101.152.180/33', '85.101.152.180/', '999.1.1.1', null, undefined, 5, {},
  ]) {
    assert.equal(ipEslesir('2a00:1d34:5517:c00:4d0a:a035:e46e:d2e7', kural), false,
      `bozuk kural eşleşti: ${String(kural)}`);
    assert.equal(ipEslesir('85.101.152.180', kural), false,
      `bozuk kural eşleşti: ${String(kural)}`);
  }
});

test('BOZUK/EKSİK istemci IP eşleşmez ve ATMAZ', () => {
  for (const ip of ['', null, undefined, 'yok', '1.2.3', ':::', 5, {}]) {
    assert.doesNotThrow(() => ipEslesir(ip, '2a00:1d34:5517:c00::/64'));
    assert.equal(ipEslesir(ip, '2a00:1d34:5517:c00::/64'), false);
    assert.equal(ipEslesir(ip, '85.101.152.180'), false);
  }
});

test('IPv4 CIDR sınırları bit düzeyinde DOĞRU (bayt sınırı olmayan önek)', () => {
  // /28 → son bayt yalnız üst 4 biti karşılaştırır.
  assert.equal(ipEslesir('10.0.0.15', '10.0.0.0/28'), true);
  assert.equal(ipEslesir('10.0.0.16', '10.0.0.0/28'), false);
  // /31 ve /32 uç değerleri.
  assert.equal(ipEslesir('10.0.0.1', '10.0.0.0/31'), true);
  assert.equal(ipEslesir('10.0.0.2', '10.0.0.0/31'), false);
  assert.equal(ipEslesir('10.0.0.0', '10.0.0.0/32'), true);
  assert.equal(ipEslesir('10.0.0.1', '10.0.0.0/32'), false);
  // /0 her IPv4'ü kapsar — kural olarak TEHLİKELİ ama matematik doğru olmalı.
  assert.equal(ipEslesir('1.2.3.4', '0.0.0.0/0'), true);
});

test('ipBaytlari: gömülü IPv4 ve kısaltma doğru açılıyor', () => {
  assert.equal(ipBaytlari('1.2.3.4').length, 4);
  assert.equal(ipBaytlari('::1').length, 16);
  assert.deepEqual([...ipBaytlari('::1').subarray(14)], [0, 1]);
  // ::ffff:1.2.3.4 → IPv6 16 bayt, son dört bayt IPv4 değeri.
  const esl = ipBaytlari('::ffff:1.2.3.4');
  assert.equal(esl.length, 16);
  assert.deepEqual([...esl.subarray(12)], [1, 2, 3, 4]);
  // Tam yazım ve kısaltma AYNI baytları vermeli.
  assert.deepEqual(
    [...ipBaytlari('2a00:1d34:5517:0c00:0000:0000:0000:0001')],
    [...ipBaytlari('2a00:1d34:5517:c00::1')]);
  assert.equal(ipBaytlari('1.2.3'), null);
  assert.equal(ipBaytlari('2a00::1::2'), null);
});

test('adminKisit listeyi ipEslesir ile geziyor (includes DEĞİL)', () => {
  // Eski `izinli.includes(ip)` geri gelirse CIDR sessizce ölür ve panel
  // IPv6'da yine kapanır — ama testler yeşil kalırdı. Kaynağı kilitliyoruz.
  const f = bildirimCek('adminKisit');
  assert.match(f, /izinli\.some\(\(k\) => ipEslesir\(ip, k\)\)/);
  assert.doesNotMatch(f, /izinli\.includes\(/);
  // Token yolu duruyor mu (IP kapanırsa yedek giriş).
  assert.match(f, /tokenGecerli/);
});

test('gercekIp IPv6 adresi BOZMUYOR (::ffff: soyma yalnız eşlemli adreste)', () => {
  // `gercekIp` içindeki replace('::ffff:', '') IPv4-eşlemli adresi düzleştirmek
  // için var. Gerçek bir IPv6 adresinde bu dizge geçmediği için adres olduğu
  // gibi kalır; aksi halde CIDR eşlemesi sessizce kaçırırdı.
  const gercekIp = new Function(`${bildirimCek('gercekIp')}\nreturn gercekIp;`)();
  const ipv6 = '2a00:1d34:5517:c00:4d0a:a035:e46e:d2e7';
  assert.equal(gercekIp({ headers: { 'x-real-ip': ipv6 } }), ipv6);
  assert.equal(gercekIp({ headers: {}, ip: '::ffff:85.101.152.180' }), '85.101.152.180');
  assert.equal(gercekIp({ headers: {} }), '');
});

test('server.js net modülünü içe aktarıyor', () => {
  assert.match(KAYNAK, /^import net from 'net';$/m,
    'ipBaytlari net.isIPv4/isIPv6 kullanıyor — import yoksa üretimde ReferenceError');
});

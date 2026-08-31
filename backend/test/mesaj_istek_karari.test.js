// MESAJ İSTEĞİ KARARLARI — Kabul et / Reddet / Reddedilenler (Instagram akışı).
//
// İki katman (engelleme.test.js gerekçesiyle aynı):
//  1) DAVRANIŞ — cevrimici.js'in GERÇEK fonksiyonları çağrılır: kabul kararı
//     cevap yazmadan ana listeye taşır, red Reddedilenler'e indirir, cevap
//     yazmak reddi türetilmiş düzeyde geçersiz kılar.
//  2) BAĞLANTI — uç sözleşmesi kaynaktan kilitlenir: SQL istek_karar'ı
//     seçmezse bütün kararlar sessizce yok sayılırdı; bildirim süzgeci
//     düşerse reddedilen kişi push atmaya devam ederdi. Bu testler hangi
//     ucun bozulduğunu adıyla söyler.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { sohbetIstekMi, sohbetleriAyir, istekRozeti } from '../cevrimici.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-23b.sql'), 'utf8');

const s = (o) => ({ okunmamis: 0, takip_ediyorum: false, ben_yazdim: false, ...o });

/** Bir ucun gövdesi: tanımından bir sonraki route tanımına kadar. */
function ucGovdesi(imza) {
  const bas = SERVER.indexOf(imza);
  assert.notEqual(bas, -1, `${imza} bulunamadı`);
  const son = SERVER.indexOf('\napp.', bas + 10);
  return SERVER.slice(bas, son === -1 ? undefined : son);
}

// ------------------------------------------------------------- davranış

test('KABUL kararı cevap yazmadan sohbeti ana listeye taşır', () => {
  assert.equal(sohbetIstekMi(s({ istek_karar: 'kabul' })), false);
  // Karar yoksa eski kural aynen geçerli: istek.
  assert.equal(sohbetIstekMi(s({})), true);
});

test('RED kararı sohbeti İstekler yerine Reddedilenler kovasına indirir', () => {
  const satirlar = [
    s({ partner: 'takipettigim', takip_ediyorum: true }),
    s({ partner: 'bekleyen' }),
    s({ partner: 'reddedilen', istek_karar: 'red' }),
    s({ partner: 'kabuledilen', istek_karar: 'kabul' }),
    s({ partner: 'bekleyen2' }),
  ];
  const { sohbetler, istekler, reddedilenler } = sohbetleriAyir(satirlar);
  assert.deepEqual(sohbetler.map((x) => x.partner), ['takipettigim', 'kabuledilen']);
  assert.deepEqual(istekler.map((x) => x.partner), ['bekleyen', 'bekleyen2']);
  assert.deepEqual(reddedilenler.map((x) => x.partner), ['reddedilen']);
  // Hiçbir sohbet kaybolmadı, hiçbiri iki kovada birden değil.
  assert.equal(
    sohbetler.length + istekler.length + reddedilenler.length, satirlar.length);
});

test('CEVAP YAZMAK reddi türetilmiş düzeyde geçersiz kılar (ana listeye döner)', () => {
  const sohbet = s({ istek_karar: 'red' });
  assert.equal(sohbetleriAyir([sohbet]).reddedilenler.length, 1, 'başta reddedilmiş');
  sohbet.ben_yazdim = true;
  const sonra = sohbetleriAyir([sohbet]);
  assert.equal(sonra.sohbetler.length, 1, 'cevap = kabul');
  assert.equal(sonra.reddedilenler.length, 0);
});

test('TAKİP ETMEK de reddi geçersiz kılar', () => {
  const sohbet = s({ istek_karar: 'red', takip_ediyorum: true });
  assert.equal(sohbetleriAyir([sohbet]).sohbetler.length, 1);
});

test('rozet REDDEDİLENLERİ saymaz (istekRozeti yalnız istekler kovasını alır)', () => {
  const satirlar = [
    s({ partner: 'bekleyen', okunmamis: 2 }),
    s({ partner: 'reddedilen', istek_karar: 'red', okunmamis: 5 }),
  ];
  const { istekler } = sohbetleriAyir(satirlar);
  assert.equal(istekRozeti(istekler), 1, 'reddedilenin 5 okunmamışı rozete girmedi');
});

// ------------------------------------------------------------- şema

test('mesaj_istek_kararlari tablosu sema.sql ve migrasyonda aynı', () => {
  for (const kaynak of [SEMA, MIGRASYON]) {
    assert.match(kaynak, /CREATE TABLE IF NOT EXISTS mesaj_istek_kararlari/);
    assert.match(kaynak, /karar\s+TEXT NOT NULL CHECK \(karar IN \('kabul', 'red'\)\)/);
    assert.match(kaynak, /PRIMARY KEY \(kullanici_id, partner_id\)/);
    assert.match(kaynak, /CHECK \(kullanici_id <> partner_id\)/);
  }
});

// ------------------------------------------------------------- uç sözleşmesi

test('GET /sohbetler istek_karar seçer ve reddedilenler döndürür', () => {
  const govde = ucGovdesi("app.get('/sohbetler'");
  assert.match(govde, /sd\.karar AS istek_karar/, 'SQL kararı seçmiyor');
  assert.match(govde, /LEFT JOIN mesaj_istek_kararlari sd/, 'JOIN yok');
  assert.match(govde, /sd\.kullanici_id=\$1 AND sd\.partner_id=k\.id/,
    'JOIN yanlış yöne bakıyor (karar, LİSTE SAHİBİNİN kararıdır)');
  assert.match(govde, /reddedilenler,/, 'yanıtta reddedilenler yok');
  // Toplam rozet reddedilen göndericileri saymaz.
  assert.match(govde, /rk\.karar='red'/, 'toplam okunmamış red süzgeci yok');
});

test('GET /sohbetler/okunmamis de reddedilenleri saymaz (iki uç aynı süzgeç)', () => {
  const govde = ucGovdesi("app.get('/sohbetler/okunmamis'");
  assert.match(govde, /NOT EXISTS \(SELECT 1 FROM mesaj_istek_kararlari rk/,
    'rozet ucu red süzgecini kaybetti — listede saymadığımız okunmamış rozette görünür');
});

test('POST /mesaj-istekleri/karar: yetki + doğrulama + upsert', () => {
  const govde = ucGovdesi("app.post('/mesaj-istekleri/karar'");
  assert.match(govde, /girisZorunlu/, 'oturumsuz karar verilebiliyor');
  assert.match(govde, /istekKarariLimiti/, 'hız limiti yok');
  // Yetki: satırın sahibi HER ZAMAN istek atan oturumdur — istemciden
  // kullanici_id alınsaydı başkasının kutusuna karar yazılabilirdi.
  assert.match(govde, /VALUES \(\$1,\$2,\$3\)/);
  assert.match(govde, /\[req\.kullanici\.id, partner_id, karar\]/,
    'kullanici_id istemciden geliyor olabilir');
  assert.match(govde, /partner_id === req\.kullanici\.id/, 'kendine karar engeli yok');
  assert.match(govde, /\['kabul', 'red'\]\.includes\(karar\)/, 'karar doğrulanmıyor');
  // Ortada gerçek bir istek olmalı: partner bana yazmış olmalı.
  assert.match(govde, /gonderen_id=\$1 AND alici_id=\$2 LIMIT 1/, 'ISTEK_YOK kontrolü yok');
  assert.match(govde, /ON CONFLICT \(kullanici_id, partner_id\)/, 'upsert değil');
});

test('POST /mesajlar: reddedilen gönderici bildirim üretmez, cevap reddi kaldırır', () => {
  const govde = ucGovdesi("app.post('/mesajlar'");
  // Süzgeç: alıcının bu gönderici hakkında red kararı varsa bildirimEkle atlanır.
  assert.match(govde, /karar='red'/, 'red süzgeci yok');
  assert.match(govde, /\[aliciId, req\.kullanici\.id\]/,
    'süzgeç yanlış yön: ALICININ kararı okunmalı');
  // dm_sessiz (31 Ağu 2026) aynı kapıya ikinci koşul ekledi: sessize alınan
  // gönderici de zil/FCM üretmez. Red kontrolü hâlâ bildirimin ÖNÜNDE olmalı.
  assert.match(govde, /if \(!red\.rows\.length && !sessiz\.rows\.length\) \{\s*\n\s*bildirimEkle/,
    'bildirimEkle red/sessiz kontrolünün arkasında değil');
  // Cevap vermek kabuldür: gönderenin kendi red kararı kabule yükselir.
  assert.match(govde, /SET karar='kabul'/, 'cevap reddi kabule yükseltmiyor');
  assert.match(govde, /WHERE kullanici_id=\$1 AND partner_id=\$2 AND karar='red'/);
});

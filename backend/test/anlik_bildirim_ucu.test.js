// ANLIK BİLDİRİM PENCERESİNİN WEB KAYNAĞI — GET /bildirimler/canli
// (13 Eyl 2026 isteği: "uygulamada gezerken mesaj geldiğinde veya birisi
//  gönderiyi beğendiğinde yukarıda popup ile gözükmeli, aynı Instagram gibi")
//
// Mobilde pencereyi FCM besliyor; TARAYICIDA FCM YOK, tek kaynak bu uç.
// Yoklanan bir uç olduğu için sözleşmesi dar ve kanıtlanması şart:
//
//  1) `son` DAMGASI YOKSA SATIR DÖNMEZ. İlk tur yalnız damga alır — yoksa
//     uygulama açılır açılmaz dünkü bildirimler üst üste pencere açardı.
//  2) DAMGA GÜNCELSE SORGU AÇILMAZ. Turların ezici çoğunluğu boştur; her 20
//     saniyede bir gereksiz JOIN çalıştırmak kullanıcı başına saatte 180 kez
//     boşa DB turu demekti.
//  3) 'mesaj' TÜRÜ SÜZÜLMEZ. `/bildirimler` listesi mesajları bilerek gizler
//     (etkileşim bildirimlerini eziyorlardı); PENCERENİN ASIL AMACI DM'i
//     haber vermek, burada süzmek özelliği baştan öldürürdü.
//  4) MESAJ ÖNİZLEMESİ ÇÖZÜLÜR. Metin DB'de şifreli durur; ham zarf
//     ("v1.k1.…") pencereye düşerse kullanıcı anlamsız bir dizi görür.
//  5) SIRA ESKİDEN YENİYE. Sorgu id DESC (en yenisi kırpılmasın) ama pencere
//     geldiği sırayla çizilmeli — son gelen ekranda kalan olmalı.
//
// YÖNTEM: `server.js` içe aktarılamıyor (yüklenir yüklenmez `app.listen`
// çağırıyor — gizlilik_secenekleri.test.js ile aynı gerekçe). Uç kaydı
// KAYNAKTAN ÇEKİLİP sahte `havuz` ile GERÇEKTEN çalıştırılır.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** `bas` indeksindeki ilk parantez çiftini dengeleyerek bloğu döndürür. */
function blokAl(kaynak, bas, ac, kapa) {
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === ac) { derinlik++; girdi = true; } else if (c === kapa) {
      derinlik--;
      if (girdi && derinlik === 0) return kaynak.slice(bas, i + 1);
    }
  }
  throw new Error('blok kapanmadı');
}

/// Uç kaydının argüman listesi — YOLUN KAPANIŞ TIRNAĞINDAN başlar:
/// `', ara katmanlar, sarici(...)` — son `)` SARICI'yı kapatır, `app.get(`
/// parantezi AÇIK kalır. Çağıran hem `app.get('<yol>` ön ekini hem kapanış
/// parantezini kendisi ekler.
function ucGovdesi(metot, yol) {
  const ara = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot.toUpperCase()} ${yol}`);
  return blokAl(KAYNAK, bas + ara.length - 1, '(', ')');
}

const YOL = '/bildirimler/canli';
const UC = ucGovdesi('get', YOL);

/**
 * Uç kaydını sahte bağımlılıklarla çalıştırıp isteyiciyi döndürür.
 * `sarici` kimliktir: hata sarmalayıcısı bu testin konusu değil.
 */
function isleyiciKur({ havuz, cozGoster = (m) => m, tmdbTopluGetir }) {
  // eslint-disable-next-line no-new-func
  const kur = new Function(
    'app', 'girisZorunlu', 'canliBildirimLimiti', 'sarici',
    'havuz', 'cozGoster', 'tmdbTopluGetir', 'ONBELLEK_TTL_SN',
    `app.get('${YOL}${UC});`,
  );
  let isleyici;
  kur(
    { get: (...parcalar) => { isleyici = parcalar[parcalar.length - 1]; } },
    null, null, (f) => f,
    havuz, cozGoster, tmdbTopluGetir || (async () => new Map()),
    { uzun: 1 },
  );
  assert.equal(typeof isleyici, 'function', 'uç işleyicisi çıkarılamadı');
  return isleyici;
}

/** Sahte havuz: SQL metnine bakarak yanıt verir, çalıştırılanları biriktirir. */
function havuzKur({ enSon = 100, bildirimler = [], mesajlar = [] } = {}) {
  const sorgular = [];
  return {
    sorgular,
    async query(sql, parametreler) {
      sorgular.push({ sql, parametreler });
      if (/max\(id\)/.test(sql)) return { rows: [{ son: enSon }] };
      if (/FROM mesajlar/.test(sql)) return { rows: mesajlar };
      return { rows: bildirimler.map((r) => ({ ...r })) };
    },
  };
}

async function cagir(isleyici, havuz, son) {
  let yanit;
  await isleyici(
    { kullanici: { id: 7 }, query: son === undefined ? {} : { son: String(son) } },
    { json: (o) => { yanit = o; } },
  );
  return yanit;
}

test('1) damga YOKSA satır dönmez — yalnız en büyük id', async () => {
  const havuz = havuzKur({ enSon: 42, bildirimler: [{ id: 42, tur: 'takip' }] });
  const yanit = await cagir(isleyiciKur({ havuz }), havuz, undefined);
  assert.deepEqual(yanit, { son: 42, bildirimler: [] });
  assert.equal(havuz.sorgular.length, 1, 'damga turunda tek sorgu açılmalı');
});

test('2) damga GÜNCELSE ikinci sorgu HİÇ açılmaz', async () => {
  const havuz = havuzKur({ enSon: 42 });
  const yanit = await cagir(isleyiciKur({ havuz }), havuz, 42);
  assert.deepEqual(yanit.bildirimler, []);
  assert.equal(havuz.sorgular.length, 1);
});

test('3) yeni satırlar ESKİDEN YENİYE döner (sorgu id DESC olsa da)', async () => {
  const havuz = havuzKur({
    enSon: 12,
    // Sunucu sorgusu id DESC verir; uç istemciye ters çevirip yollar.
    bildirimler: [
      { id: 12, tur: 'begeni', aktor: 'ayse' },
      { id: 11, tur: 'takip', aktor: 'veli' },
    ],
  });
  const yanit = await cagir(isleyiciKur({ havuz }), havuz, 10);
  assert.deepEqual(yanit.bildirimler.map((r) => r.id), [11, 12]);
  assert.equal(yanit.son, 12);
});

test('4) MESAJ TÜRÜ SÜZÜLMEZ ve önizleme ÇÖZÜLÜR', async () => {
  const havuz = havuzKur({
    enSon: 5,
    bildirimler: [{ id: 5, tur: 'mesaj', aktor: 'veli' }],
    mesajlar: [{ gonderen: 'veli', metin: 'v1.k1.sifreli', medya: null }],
  });
  const yanit = await cagir(
    isleyiciKur({ havuz, cozGoster: (m) => (m === 'v1.k1.sifreli' ? 'selam' : m) }),
    havuz, 4,
  );
  const satir = yanit.bildirimler[0];
  assert.equal(satir.tur, 'mesaj');
  assert.equal(satir.metin, 'selam', 'şifreli zarf çözülmeden pencereye düşmüş');
  // Liste ucundaki "mesajları gizle" süzgeci buraya SIZMAMALI.
  const bildirimSorgusu = havuz.sorgular.find((s) => /FROM bildirimler/.test(s.sql));
  assert.doesNotMatch(bildirimSorgusu.sql, /tur\s*<>\s*'mesaj'/);
});

test('5) medyalı mesajda YOL değil TÜR gider (imzasız yol açılmaz)', async () => {
  const havuz = havuzKur({
    enSon: 6,
    bildirimler: [{ id: 6, tur: 'mesaj', aktor: 'veli' }],
    mesajlar: [{ gonderen: 'veli', metin: null, medya: '/medya/klip.mp4' }],
  });
  const satir = (await cagir(isleyiciKur({ havuz }), havuz, 5)).bildirimler[0];
  assert.equal(satir.medya_tur, 'video');
  assert.equal(satir.medya, undefined, 'medya yolu pencereye sızmamalı');
});

test('6) sözleşme: girişli + hız limitli, en fazla 5 satır', () => {
  assert.match(UC, /girisZorunlu/);
  assert.match(UC, /canliBildirimLimiti/);
  assert.match(UC, /LIMIT 5/);
  // Sayaç kullanıcı BAŞINA (IP başına olsaydı aynı ağdaki iki kişi
  // birbirinin penceresini susturabilirdi).
  assert.match(KAYNAK, /canliBildirimLimiti = hizLimiti\(\d+, \(req\) => `cb:\$\{req\.kullanici\.id\}`\)/);
});

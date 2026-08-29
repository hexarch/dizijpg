// GIF ARŞİVİ — GÖRÜNÜRLÜK KİLİDİ (+18 şartı) · `node --test backend/test`
//
// Kullanıcının sert şartı: "+18 KESİNLİKLE OLMAYACAK ... onaysız GIF hiçbir
// başka kullanıcıya görünmemeli." Bu dosya o şartı test edilebilir bir
// sözleşmeye çeviriyor.
//
// NEDEN KAYNAK GREPLEMİYORUZ: kural `gif.js` içinde SAF fonksiyonlarda duruyor
// (`gifSuzgec`, `kendiGifSuzgeci`), yani gerçekten ÇAĞIRILABİLİR. `server.js`
// içe aktarıldığı anda `app.listen` çağırdığı için uçlar doğrudan çağrılamaz;
// bu yüzden kuralı uçtan ayırıp modüle taşıdık. Uçların o modülü GERÇEKTEN
// kullandığı ayrıca kaynak kilidiyle doğrulanıyor (aşağıdaki son grup) —
// yoksa fonksiyon doğru olur ama uç onu hiç çağırmaz ve test yeşil yalan söyler.
//
// ÜRETİLEN SQL AYRICA CANLIDA KOŞTURULDU (29 Ağu 2026): iki test kullanıcısı
// ve üç durumda kayıtla; sonuçlar rapora yazıldı.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  GIF_DURUMLARI, GIF_KAYNAKLARI, ETIKET_AZAMI, ETIKET_UZUNLUK_AZAMI, SAYFA_BOYU,
  gifSuzgec, kendiGifSuzgeci, gifYoluGecerli, etiketleriTemizle,
  aramaMetniUret, sorguNormalle, sayfaOfseti,
} from '../gif.js';

const KOK = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const PANEL = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');

/**
 * Üretilen WHERE koşulunu JS'te DEĞERLENDİREN küçük bir yorumlayıcı.
 * SQL çalıştırmadan davranışı ölçmenin tek dürüst yolu: koşulu satır satır
 * uygulayıp GERÇEKTEN kimin ne gördüğünü sayıyoruz. Yorumlayıcı bilerek
 * aptal — yalnız bizim ürettiğimiz iki kalıbı tanır; kural değişip başka bir
 * biçim üretirse burada PATLAR (sessizce geçmez).
 */
function satirGorunurMu(kosul, parametreler, satir) {
  if (kosul === 'false') return false;
  const cozumle = (ifade) => {
    const t = ifade.trim().replace(/^\((.*)\)$/s, '$1').trim();
    if (t.includes(' OR ')) return t.split(' OR ').some(cozumle);
    if (t.includes(' AND ')) return t.split(' AND ').every(cozumle);
    let m = /^g\.durum = '([a-z]+)'$/.exec(t);
    if (m) return satir.durum === m[1];
    m = /^g\.durum <> '([a-z]+)'$/.exec(t);
    if (m) return satir.durum !== m[1];
    m = /^g\.yukleyen_id = \$(\d+)$/.exec(t);
    if (m) return satir.yukleyen_id === parametreler[Number(m[1]) - 1];
    throw new Error(`yorumlanamayan koşul parçası: "${t}"`);
  };
  return cozumle(kosul);
}

/** Üç durumun her birinden birer satır; ikisi A'nın, ikisi B'nin. */
const A = 1;      // isteyen
const B = 2;      // başka kullanıcı
const SATIRLAR = [
  { ad: 'A-bekliyor', durum: 'bekliyor', yukleyen_id: A },
  { ad: 'A-onayli', durum: 'onayli', yukleyen_id: A },
  { ad: 'A-reddedildi', durum: 'reddedildi', yukleyen_id: A },
  { ad: 'B-bekliyor', durum: 'bekliyor', yukleyen_id: B },
  { ad: 'B-onayli', durum: 'onayli', yukleyen_id: B },
  { ad: 'B-reddedildi', durum: 'reddedildi', yukleyen_id: B },
];

function gorunenler(suzgec) {
  return SATIRLAR
    .filter((s) => satirGorunurMu(suzgec.kosul, suzgec.parametreler, s))
    .map((s) => s.ad);
}

// ---------------------------------------------------------------------------
test('A kendi BEKLEYENİNİ görür — yüklediğini hemen kullanabilmeli', () => {
  assert.ok(gorunenler(gifSuzgec(A)).includes('A-bekliyor'));
});

test('+18 KİLİDİ: B, A nın BEKLEYENİNİ GÖRMEZ', () => {
  const g = gorunenler(gifSuzgec(B));
  assert.ok(!g.includes('A-bekliyor'),
    'onaysız GIF başka kullanıcının aramasına düştü — +18 şartı ihlal');
});

test('+18 KİLİDİ: MİSAFİR hiçbir bekleyeni görmez', () => {
  const g = gorunenler(gifSuzgec(null));
  assert.deepEqual(g, ['A-onayli', 'B-onayli'],
    'kimliksiz istekte onaylı olmayan kayıt sızdı');
});

test('REDDEDİLEN kimseye görünmez — yükleyenine DE', () => {
  for (const kim of [A, B, null]) {
    const g = gorunenler(gifSuzgec(kim));
    assert.ok(!g.some((x) => x.endsWith('reddedildi')),
      `reddedilen GIF görünüyor (isteyen=${kim})`);
  }
  // "Yüklediklerim" listesinde de düşer — kullanıcının açık isteği.
  assert.ok(!gorunenler(kendiGifSuzgeci(A)).includes('A-reddedildi'));
});

test('ONAYLI herkese görünür (arşivin amacı bu)', () => {
  for (const kim of [A, B, null]) {
    const g = gorunenler(gifSuzgec(kim));
    assert.ok(g.includes('A-onayli') && g.includes('B-onayli'));
  }
});

test('"Yüklediklerim" YALNIZ kendi kayıtlarını verir', () => {
  const g = gorunenler(kendiGifSuzgeci(A));
  assert.deepEqual(g, ['A-bekliyor', 'A-onayli']);
  assert.ok(!g.some((x) => x.startsWith('B-')), 'başkasının GIF i sızdı');
});

test('kimliksiz "Yüklediklerim" HİÇBİR ŞEY vermez (fail-closed)', () => {
  assert.deepEqual(gorunenler(kendiGifSuzgeci(null)), []);
  assert.deepEqual(gorunenler(kendiGifSuzgeci(0)), []);
  assert.deepEqual(gorunenler(kendiGifSuzgeci('1')), [],
    'dizgi id kabul edilirse SQL enjeksiyon yüzeyi açılır');
});

test('VARSAYILAN GÖRÜNMEZ: bilinmeyen bir durum kimseye sızmaz', () => {
  // Yarın 'karantina' eklenirse (AI süzgeci planı) hiçbir dal onu kapsamaz.
  const karantina = { ad: 'A-karantina', durum: 'karantina', yukleyen_id: A };
  for (const kim of [A, B, null]) {
    const s = gifSuzgec(kim);
    assert.equal(satirGorunurMu(s.kosul, s.parametreler, karantina), false);
  }
});

test('parametre numarası kaydırılabilir (sorguya sonradan eklenir)', () => {
  const s = gifSuzgec(A, 3);
  assert.match(s.kosul, /\$3/);
  assert.deepEqual(s.parametreler, [A]);
});

// ---------------------------------------------------------------------------
// SAHİPLİK: yalnız kendi yüklediği dosya kaydedilebilir
test('gifYoluGecerli BAŞKASININ dosyasını reddeder', () => {
  assert.ok(gifYoluGecerli('/medya/m7-0123456789abcdef.gif', 7));
  assert.ok(!gifYoluGecerli('/medya/m8-0123456789abcdef.gif', 7),
    'başka kullanıcının dosyası arşive kaydedilebiliyor');
});

test('gifYoluGecerli GIF DIŞI uzantıyı ve yol kaçışını reddeder', () => {
  assert.ok(!gifYoluGecerli('/medya/m7-0123456789abcdef.mp4', 7));
  assert.ok(!gifYoluGecerli('/medya/m7-0123456789abcdef.gif.mp4', 7));
  assert.ok(!gifYoluGecerli('/medya/../etc/passwd', 7));
  assert.ok(!gifYoluGecerli('/avatarlar/avatar7-1.gif', 7));
  assert.ok(!gifYoluGecerli('/medya/m7-XYZ.gif', 7), 'hex olmayan ad geçti');
  assert.ok(!gifYoluGecerli('/medya/m70-0123456789abcdef.gif', 7),
    'id öneki 7 iken 70 kabul edildi — sınır kaçağı');
  assert.ok(!gifYoluGecerli(null, 7));
});

// ---------------------------------------------------------------------------
// GİRDİ DOĞRULAMASI
test('etiketler kırpılır, küçültülür, tekilleşir, sayı sınırlanır', () => {
  // 'ŞAŞKIN' → 'şaşkin': düz `toLowerCase` 'I'yı 'i' yapar. BİLİNÇLİ bedel —
  // Türkçe kural 'GIF'i 'gıf'a çevirirdi ve "gif" arayan bulamazdı. Arama
  // tarafı AYNI kuralı uyguladığı için iki taraf tutarlı kalır.
  assert.deepEqual(etiketleriTemizle(['  Gülme ', 'gülme', 'ŞAŞKIN']),
    ['gülme', 'şaşkin']);
  assert.equal(etiketleriTemizle(Array.from({ length: 50 }, (_, i) => `e${i}`)).length,
    ETIKET_AZAMI);
  assert.equal(etiketleriTemizle(['x'.repeat(200)])[0].length, ETIKET_UZUNLUK_AZAMI);
  assert.deepEqual(etiketleriTemizle(['a']), [], 'tek harf etiket geçti');
  assert.deepEqual(etiketleriTemizle('dizgi'), []);
  assert.deepEqual(etiketleriTemizle([null, 3, {}]), []);
});

test('GIF etiketi Türkçe küçültmeyle "gıf"a DÖNMEZ', () => {
  // toLocaleLowerCase('tr') olsaydı 'GIF' → 'gıf' olurdu ve "gif" arayan
  // kullanıcı kendi etiketini bulamazdı. Arama tarafı da düz toLowerCase.
  assert.deepEqual(etiketleriTemizle(['GIF']), ['gif']);
  assert.equal(sorguNormalle('GIF'), 'gif');
});

test('arama metni etiketlerden üretilir (trigram indeksi TEXT[] taramaz)', () => {
  assert.equal(aramaMetniUret(['gülme', 'şaşkın']), 'gülme şaşkın');
});

test('sorgu ve sayfa sınırlanır (kaynak tüketimi)', () => {
  assert.equal(sorguNormalle('  ÇOK   boşluklu  ').length > 0, true);
  assert.equal(sorguNormalle('a'.repeat(500)).length, 60);
  assert.equal(sayfaOfseti('1'), 0);
  assert.equal(sayfaOfseti('3'), 2 * SAYFA_BOYU);
  assert.equal(sayfaOfseti('-5'), 0, 'negatif sayfa negatif OFFSET üretti');
  assert.equal(sayfaOfseti('abc'), 0);
  assert.equal(sayfaOfseti('99999'), 200 * SAYFA_BOYU, 'sayfa tavanı yok');
});

test('durum ve kaynak listeleri şemayla AYNI', () => {
  assert.deepEqual(GIF_DURUMLARI, ['bekliyor', 'onayli', 'reddedildi']);
  assert.deepEqual(GIF_KAYNAKLARI, ['kullanici', 'kamu-mali']);
  for (const d of GIF_DURUMLARI) assert.ok(SEMA.includes(`'${d}'`));
});

// ---------------------------------------------------------------------------
// KAYNAK KİLİTLERİ — fonksiyon doğru olsa da uç onu ÇAĞIRMAZSA test yalan söyler
test('okuma uçları gif.js süzgecini GERÇEKTEN çağırır', () => {
  const i = KAYNAK.indexOf('async function gifListele(');
  assert.notEqual(i, -1, 'gifListele kayboldu');
  const govde = KAYNAK.slice(i, KAYNAK.indexOf('\n}\n', i));
  assert.match(govde, /kendiGifSuzgeci\(isteyen, 1\)/);
  assert.match(govde, /gifSuzgec\(isteyen, 1\)/);
  // Süzgeç WHERE'e KOŞULSUZ girmeli — "eğer q varsa" gibi bir dala bağlanamaz.
  assert.match(govde, /WHERE \$\{kosul\}/);
});

test('kayıt ucu sahiplik + varlık kapısından geçer', () => {
  const i = KAYNAK.indexOf("app.post('/gif', girisZorunlu, gifKayitLimiti");
  assert.notEqual(i, -1, 'POST /gif ucu yok ya da hız limiti/auth düştü');
  const govde = KAYNAK.slice(i, i + 2500);
  assert.match(govde, /gifYoluGecerli\(yol, req\.kullanici\.id\)/);
  assert.match(govde, /fs\.existsSync\(path\.join\(MEDYA_DIZIN/);
  assert.match(govde, /medyaYoluNormalle\(yolHam\)/);
  // ON CONFLICT durumu TAZELEMEMELİ: reddedilen kendini onaya geri sokmasın.
  assert.ok(!/DO UPDATE[\s\S]{0,200}durum\s*=/.test(govde),
    'ON CONFLICT durumu geri alıyor — reddedilen GIF yeniden kuyruğa giriyor');
});

test('okuma uçları hız limitli, yazma uçları girisZorunlu', () => {
  assert.match(KAYNAK, /app\.get\('\/gif', girisİsteğeBagli|app\.get\('\/gif', girisIsteğeBagli, gifOkumaLimiti,/);
  assert.match(KAYNAK, /app\.get\('\/gif\/benim', girisZorunlu, gifOkumaLimiti,/);
  assert.match(KAYNAK, /app\.post\('\/gif\/:id\/kullanildi', girisZorunlu, gifOkumaLimiti,/);
  assert.match(KAYNAK, /const gifKayitLimiti = hizLimiti\(30,/);
});

test('kullanım sayacı YALNIZ onaylı satırı artırır', () => {
  assert.match(KAYNAK,
    /UPDATE gifler SET kullanim = kullanim \+ 1 WHERE id=\$1 AND durum='onayli'/);
});

test('admin moderasyon uçları adminKisit ile korunur', () => {
  for (const uc of ['gif-kuyruk', 'gif-karar', 'gif-sil']) {
    assert.match(KAYNAK, new RegExp(`'/admin/${uc}', adminKisit,`),
      `/admin/${uc} adminKisit olmadan açık`);
  }
});

test('öksüz taraması GIF arşivini referans SAYAR (yoksa hepsini siler)', () => {
  const i = KAYNAK.indexOf('async function medyaReferanslari(');
  const govde = KAYNAK.slice(i, KAYNAK.indexOf('\n}\n', i));
  assert.match(govde, /SELECT yol FROM gifler/,
    'gifler dalı yok — /admin/oksuz-sil arşivin tamamını silerdi');
  assert.match(govde, /\.\.\.g\.rows/, 'gifler satırları kümeye eklenmiyor');
});

test('şikayet yolu MEVCUT altyapıya bağlı (yeni tablo uydurulmadı)', () => {
  assert.match(KAYNAK, /SIKAYET_TUR = \['yorum', 'mesaj', 'kullanici', 'liste', 'gif'\]/);
  assert.match(KAYNAK, /SELECT yukleyen_id FROM gifler WHERE id=\$1/,
    'sikayetHedefSahibi gif dalı yok — haklı bulunan şikayet güven skoru düşürmez');
  assert.match(SEMA, /CHECK \(tur IN \('yorum', 'mesaj', 'kullanici', 'liste', 'gif'\)\)/);
});

test('şema: lisans/atıf kamu malı için ZORUNLU, yol TEKİL', () => {
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS gifler/);
  assert.match(SEMA, /yol\s+TEXT\s+NOT NULL UNIQUE/);
  assert.match(SEMA, /gifler_kamu_mali_atif/);
  assert.match(SEMA, /kaynak <> 'kamu-mali' OR \(length\(btrim\(lisans\)\) > 0 AND length\(btrim\(atif\)\) > 0\)/);
});

test('panelde GIF onayı Moderasyon modülünde', () => {
  assert.match(PANEL, /k:'gifler'/, 'panel modül satırı yok');
  assert.match(PANEL, /gif-kuyruk/);
  assert.match(PANEL, /gif-karar/);
});

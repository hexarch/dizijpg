// Sesli/görüntülü arama testleri — `cd backend && node --test test/*.test.js`
//
// KAYNAK: `backend/ARAMA-API-SOZLESMESI.md` (bağlayıcı sözleşme) + `ARAMA-PLANI.md`
//
// İki katman (`yasak.test.js` / `medya_imza.test.js` ile aynı disiplin):
//  1) DAVRANIŞ: `arama.js` SAF olduğu için gerçek fonksiyonlar çağrılır.
//     Yetki zinciri callback aldığı için ÇAĞRI SIRASI da ölçülebiliyor — yani
//     testin doğruladığı sıra, üretimde çalışan sıranın ta kendisi.
//  2) BAĞLANTI: `server.js` / `yasak.js` / `Dockerfile` denetlenir — saf modül
//     doğru olsa bile sunucu onu yanlış bağlarsa davranış testi bunu göremez.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

import {
  CALMA_MS, AZAMI_ARAMA_MS, TURN_TTL_SN, SDP_AZAMI_BAYT, SAKLAMA_GUN,
  SESSIZ_PENCERE_MS, SESSIZ_ESIK, SESSIZ_CEZA_MS, ROLE_BAYT_TAVAN,
  UC_DURUMLAR, KOD, KACIRILAN_DURUMLAR, CEVAPSIZ_DURUMLAR,
  aramaKimlik, turnKimlik, buzSunuculari, ozellikBayraklari,
  sdpGecerliMi, adaylariTemizle, olcumTemizle,
  baslatYetki, yanitYetki, ustveri, gecmisYon,
  AramaDeposu, SessizDepo,
} from '../arama.js';
import { yazmaYasakli, YASAK_MUAF } from '../yasak.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const ARAMA_SRC = fs.readFileSync(path.join(KOK, 'arama.js'), 'utf8');
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
const MIGRASYON = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-08e.sql'), 'utf8');

const SDP = 'v=0\r\no=- 1 1 IN IP4 0.0.0.0\r\ns=-\r\n';

/** Her kontrolü GEÇEN varsayılan kaynak; test yalnız ilgilendiğini bozar. */
function kaynakYap(uzer = {}) {
  const izler = [];
  const k = {
    izler,
    // `kabulSesli`/`kabulGoruntulu` (md. 38) BİLEREK açık: bu yardımcı "her
    // kontrolü GEÇEN" kaynağı temsil ediyor. Gerçek varsayılan KAPALI'dır ve
    // onu ayrı testler ölçüyor (§"kullanıcı başına arama tercihi").
    hedefBul: async (ad) => {
      izler.push('hedefBul');
      return { id: 2, yasakli: false, ad, kabulSesli: true, kabulGoruntulu: true };
    },
    engelliMi: async () => { izler.push('engelliMi'); return false; },
    karsilikliMi: async () => { izler.push('karsilikliMi'); return true; },
    sessizKalanSn: async () => { izler.push('sessizKalanSn'); return 0; },
    mesgulMu: async () => { izler.push('mesgulMu'); return false; },
    ...uzer,
  };
  return k;
}
const girdiYap = (u = {}) => ({
  aramaAcik: true, goruntuluAcik: true, benId: 1,
  kullaniciAdi: 'alcelik', tur: 'ses', sdp: SDP, ...u,
});

// ===========================================================================
// 1. TURN KİMLİK BİLGİSİ — HMAC-SHA1 (coturn `use-auth-secret`)
// ===========================================================================
// *** SIR TESTE GÖMÜLMEZ *** — canlı `TURN_SIR` burada YOKTUR ve olmayacaktır.
// Sahte bir sırla, coturn'ün beklediği formülü BAĞIMSIZ olarak yeniden
// hesaplayıp karşılaştırıyoruz. Formül yanlış olursa coturn kimliği reddeder
// ve arıza SESSİZDİR: kimlik doğrulaması geçmez, arama "bağlanamadı" der.
const SAHTE_SIR = 'test-turn-sirri-asla-canli-degil-0123456789abcdef';

test('TURN kimliği: username = <son_kullanma>:<kullanici_id>', () => {
  const t0 = 1_786_400_000_000;
  const k = turnKimlik(SAHTE_SIR, 42, 43_200, t0);
  assert.equal(k.username, `${Math.floor(t0 / 1000) + 43200}:42`);
  assert.equal(k.gecerlilik_sn, 43_200);
});

test('TURN kimliği: credential = base64(HMAC-SHA1(sır, username)) — BAĞIMSIZ hesap', () => {
  const t0 = 1_786_400_000_000;
  const k = turnKimlik(SAHTE_SIR, 42, 43_200, t0);
  const beklenen = crypto.createHmac('sha1', SAHTE_SIR).update(k.username).digest('base64');
  assert.equal(k.credential, beklenen);
  // base64 SHA1 = 20 bayt -> 28 karakter (sondaki '=' dahil)
  assert.equal(Buffer.from(k.credential, 'base64').length, 20);
});

test('TURN kimliği: FARKLI sır FARKLI credential (sır gerçekten karışıyor)', () => {
  const t0 = 1_786_400_000_000;
  const a = turnKimlik(SAHTE_SIR, 42, 43_200, t0);
  const b = turnKimlik(`${SAHTE_SIR}X`, 42, 43_200, t0);
  assert.equal(a.username, b.username, 'kullanıcı adı sırdan bağımsız olmalı');
  assert.notEqual(a.credential, b.credential);
});

test('TURN kimliği: farklı KULLANICI farklı kimlik (user-quota kişi başına işlesin)', () => {
  const t0 = 1_786_400_000_000;
  assert.notEqual(turnKimlik(SAHTE_SIR, 1, 43_200, t0).credential,
    turnKimlik(SAHTE_SIR, 2, 43_200, t0).credential);
});

test('TURN TTL varsayılanı 12 saat (uzun aramanın ortasında sona ermesin)', () => {
  assert.equal(TURN_TTL_SN, 43_200);
});

test('TURN_SIR YOKSA: çökme yok, YALNIZ STUN döner, credential alanı HİÇ BULUNMAZ', () => {
  const { buz_sunuculari, gecerlilik_sn } = buzSunuculari({ sir: '', kullaniciId: 7 });
  assert.equal(gecerlilik_sn, 0);
  assert.equal(buz_sunuculari.length, 2, 'yalnız iki stun: girdisi');
  for (const s of buz_sunuculari) {
    assert.ok(s.urls.startsWith('stun:'), `TURN girdisi sızdı: ${s.urls}`);
    assert.ok(!('username' in s) && !('credential' in s),
      'sır yokken username/credential alanları HİÇ bulunmamalı');
  }
});

test('buz sunucuları SIRASI bağlayıcı: kendi STUN birincil, Google YEDEK (sonuncu)', () => {
  const { buz_sunuculari: l } = buzSunuculari({ sir: SAHTE_SIR, kullaniciId: 7 });
  assert.equal(l.length, 5);
  assert.equal(l[0].urls, 'stun:turn.dizijpg.com:3478');
  assert.equal(l[1].urls, 'turn:turn.dizijpg.com:3478?transport=udp');
  assert.equal(l[2].urls, 'turn:turn.dizijpg.com:3478?transport=tcp');
  assert.equal(l[3].urls, 'turns:turn.dizijpg.com:5349?transport=tcp');
  assert.equal(l[4].urls, 'stun:stun.l.google.com:19302');
  assert.ok(l.slice(1, 4).every((s) => s.username && s.credential));
});

test('TURN sırrı KODA GÖMÜLMEMİŞ (yalnız process.env.TURN_SIR okunuyor)', () => {
  assert.ok(!/TURN_SIR\s*=\s*['"][^'"]+['"]/.test(ARAMA_SRC),
    'arama.js içine sabit sır yazılmış');
  assert.ok(/process\.env\.TURN_SIR/.test(SERVER), 'server.js TURN_SIR ortamdan okumalı');
  assert.ok(!/const TURN_SIR = ['"][0-9a-f]{16,}/.test(SERVER), 'server.js içine sabit sır yazılmış');
});

// ===========================================================================
// 2. KILL SWITCH — SUNUCU ZORLAR (eski istemci bayrağı yok sayarsa da)
// ===========================================================================
test('kill switch: ayarlar 0 ise arama KAPALI', () => {
  assert.deepEqual(ozellikBayraklari({ arama_acik: '0', arama_goruntulu_acik: '1' }, {}),
    { aramaAcik: false, goruntuluAcik: false });
});

test('kill switch: arama açık + görüntülü kapalı -> yalnız sesli', () => {
  assert.deepEqual(ozellikBayraklari({ arama_acik: '1', arama_goruntulu_acik: '0' }, {}),
    { aramaAcik: true, goruntuluAcik: false });
});

test('kill switch KATMAN 2: ARAMA_GORUNTULU=kapali VERİTABANINI EZER', () => {
  const a = { arama_acik: '1', arama_goruntulu_acik: '1' };
  assert.deepEqual(ozellikBayraklari(a, { ARAMA_GORUNTULU: 'kapali' }),
    { aramaAcik: true, goruntuluAcik: false });
  assert.deepEqual(ozellikBayraklari(a, { ARAMA_KAPALI: 'kapali' }),
    { aramaAcik: false, goruntuluAcik: false });
});

test('kill switch: ayar HİÇ YOKSA kapalı (migrasyon uygulanmadan özellik açılmaz)', () => {
  assert.deepEqual(ozellikBayraklari({}, {}), { aramaAcik: false, goruntuluAcik: false });
});

test('KILL SWITCH SUNUCUDA ZORLANIYOR: istemci ne gönderirse göndersin 503', async () => {
  // Eski bir APK `goruntulu_acik:false` bayrağını yok sayıp yine de görüntülü
  // arama başlatmaya çalışırsa — SUNUCU reddeder. Kill switch'in ANLAMI budur.
  const kapali = await baslatYetki(girdiYap({ aramaAcik: false }), kaynakYap());
  assert.equal(kapali.http, 503);
  assert.equal(kapali.kod, KOD.ARAMA_KAPALI);

  const k = kaynakYap();
  const goruntuluKapali = await baslatYetki(
    girdiYap({ goruntuluAcik: false, tur: 'goruntu' }), k);
  assert.equal(goruntuluKapali.http, 503);
  assert.equal(goruntuluKapali.kod, KOD.GORUNTULU_KAPALI);
  assert.deepEqual(k.izler, [], 'kapalıyken VERİTABANINA HİÇ GİDİLMEMELİ');

  // Sesli, aynı ayarla, GEÇER — görüntülü kapatmak sesliyi öldürmez.
  const sesli = await baslatYetki(girdiYap({ goruntuluAcik: false, tur: 'ses' }), kaynakYap());
  assert.equal(sesli.tamam, true);
});

test('KILL SWITCH `/arama/yanit`ta da zorlanır (çalarken görüntülü kapatılırsa)', async () => {
  const kayit = { arayanId: 1, arananId: 2, tur: 'goruntu', durum: 'caliyor' };
  const r = await yanitYetki(
    { aramaAcik: true, goruntuluAcik: false, benId: 2, kayit, kabul: true, sdp: SDP },
    kaynakYap());
  assert.equal(r.http, 503);
  assert.equal(r.kod, KOD.GORUNTULU_KAPALI);
});

test('BAĞLANTI: /arama/baslat ve /arama/yanit bayrakları GERÇEKTEN okuyor', () => {
  const baslat = SERVER.slice(SERVER.indexOf("app.post('/arama/baslat'"),
    SERVER.indexOf("app.get('/arama/durum/:aramaId'"));
  assert.ok(/aramaBayraklari\(\)/.test(baslat), '/arama/baslat kill switch okumuyor');
  const yanit = SERVER.slice(SERVER.indexOf("app.post('/arama/yanit'"),
    SERVER.indexOf("app.post('/arama/aday'"));
  assert.ok(/aramaBayraklari\(\)/.test(yanit), '/arama/yanit kill switch okumuyor');
  assert.ok(/ozellikBayraklari\(await ayarlariGetir\(\), process\.env\)/.test(SERVER),
    'bayraklar hem ayarlar tablosundan hem ortamdan okunmalı');
});

test('MİGRASYON kill switch bayraklarını KAPALI (0) kuruyor', () => {
  assert.ok(/\('arama_acik',\s*'0'\)/.test(MIGRASYON));
  assert.ok(/\('arama_goruntulu_acik',\s*'0'\)/.test(MIGRASYON));
});

// ===========================================================================
// 3. YETKİ ZİNCİRİ — SIRA BAĞLAYICIDIR (sözleşme §5)
// ===========================================================================
test('KARŞILIKLI TAKİP ŞARTI: takipleşmeyen ARAYAMAZ (403 TAKIP_YOK)', async () => {
  const r = await baslatYetki(girdiYap(), kaynakYap({ karsilikliMi: async () => false }));
  assert.equal(r.tamam, false);
  assert.equal(r.http, 403);
  assert.equal(r.kod, KOD.TAKIP_YOK);
});

test('KARŞILIKLI TAKİP `/arama/yanit`ta TEKRAR kontrol edilir (45 sn penceresi)', async () => {
  // A arama başlattıktan sonra, B cevaplamadan önce takipten çıkabilir.
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', durum: 'caliyor' };
  const r = await yanitYetki(
    { aramaAcik: true, goruntuluAcik: true, benId: 2, kayit, kabul: true, sdp: SDP },
    kaynakYap({ karsilikliMi: async () => false }));
  assert.equal(r.http, 403);
  assert.equal(r.kod, KOD.TAKIP_YOK);
});

test('ENGELLENEN KULLANICI arayamaz — ÇİFT YÖNLÜ (403 ENGELLI)', async () => {
  const r = await baslatYetki(girdiYap(), kaynakYap({ engelliMi: async () => true }));
  assert.equal(r.http, 403);
  assert.equal(r.kod, KOD.ENGELLI);
});

test('ENGELLEME `/arama/yanit`ta da zorlanır', async () => {
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', durum: 'caliyor' };
  const r = await yanitYetki(
    { aramaAcik: true, goruntuluAcik: true, benId: 2, kayit, kabul: true, sdp: SDP },
    kaynakYap({ engelliMi: async () => true }));
  assert.equal(r.http, 403);
  assert.equal(r.kod, KOD.ENGELLI);
});

test('ENGELLEME kontrolü ÇİFT YÖNLÜ sorguya bağlı (engelliMi tek yardımcıda)', () => {
  const govde = SERVER.slice(SERVER.indexOf('async function engelliMi('),
    SERVER.indexOf('async function karsilikliTakipMi('));
  assert.ok(/engelleyen_id=\$1 AND engellenen_id=\$2/.test(govde));
  assert.ok(/engelleyen_id=\$2 AND engellenen_id=\$1/.test(govde));
  // ÜÇÜNCÜ kopya yazılmamalı: `/mesajlar` artık yardımcıyı çağırıyor.
  const kopya = SERVER.match(/SELECT 1 FROM engellemeler\s*\n\s*WHERE \(engelleyen_id/g) || [];
  assert.equal(kopya.length, 1, 'engelleme kontrolü tek yerde olmalı (engelliMi)');
});

test('KULLANICI YOK 404, KENDİNE ARAMA 400', async () => {
  const yok = await baslatYetki(girdiYap(), kaynakYap({ hedefBul: async () => null }));
  assert.equal(yok.http, 404);
  assert.equal(yok.kod, KOD.KULLANICI_YOK);

  const kendi = await baslatYetki(girdiYap(),
    kaynakYap({ hedefBul: async () => ({ id: 1, yasakli: false }) }));
  assert.equal(kendi.http, 400);
  assert.equal(kendi.kod, KOD.KENDINE_ARAMA);
});

test('ARANAN YASAKLI ise arama başlamaz (403 ALICI_YASAKLI)', async () => {
  const r = await baslatYetki(girdiYap(),
    kaynakYap({ hedefBul: async () => ({ id: 2, yasakli: true }) }));
  assert.equal(r.http, 403);
  assert.equal(r.kod, KOD.ALICI_YASAKLI);
});

// ===========================================================================
// 3b. MİSAFİR HESAPLAR (sürüm 4) — kullanıcı kararı 10 Ağu
// ===========================================================================
// "misafir hesaplar aranamasın ve bu ayarları açamasınlar, sebebini de onlara
// söyle."
//
// İKİ YÖN AYRI AYRI KİLİTLENİYOR:
//   (a) misafir ARAYAMAZ  -> 403 MISAFIR_ARAMA_YOK (adım 4)
//   (b) misafir ARANAMAZ  -> 403 ALICI_MISAFIR     (adım 8)
// (a) 10 Ağu'ya kadar HİÇ KONTROL EDİLMİYORDU: `baslatYetki` yalnız hedefe
// bakıyordu, arayanın hesap türüne bakmıyordu. Yani misafir hesaplar gerçek
// kullanıcıların telefonunu çaldırabiliyordu.
// (b) kontrol ediliyordu ama YANLIŞ SEBEPLE: `hedefBul` sorgusundaki
// `AND misafir=false` yüzünden hedef "yok" görünüyor ve 404 KULLANICI_YOK
// dönüyordu — kullanıcı var, sohbet ekranı açık, ekranda "kullanıcı bulunamadı".

test('sürüm 4 (a): MİSAFİR ARAYAMAZ — 403 ve HİÇBİR sorgu atılmaz', async () => {
  const k = kaynakYap();
  const r = await baslatYetki(girdiYap({ benMisafir: true }), k);
  assert.equal(r.tamam, false);
  assert.equal(r.http, 403);
  assert.equal(r.kod, KOD.MISAFIR_ARAMA_YOK);
  // Zincirin EN UCUZ adımı olmalı: hedef hakkında tek satır bile okunmamalı.
  // Yoksa misafir bir hesap `KULLANICI_YOK`/`TAKIP_YOK` farkından kullanıcı
  // adı numaralandırabilirdi.
  assert.deepEqual(k.izler, [], 'misafir arayan için veritabanına gidildi');
});

test('sürüm 4 (a): misafir kontrolü KILL SWITCH SONRASI, doğrulama ÖNCESİ', async () => {
  // Özellik sunucu genelinde kapalıysa hesap türünü tartışmanın anlamı yok.
  const kapali = await baslatYetki(
    girdiYap({ benMisafir: true, aramaAcik: false }), kaynakYap());
  assert.equal(kapali.kod, KOD.ARAMA_KAPALI);
  // Ama bozuk gövde misafiri kurtarmaz: misafirlik önce söylenir.
  const bozuk = await baslatYetki(
    girdiYap({ benMisafir: true, tur: 'video', sdp: 'merhaba' }), kaynakYap());
  assert.equal(bozuk.kod, KOD.MISAFIR_ARAMA_YOK);
});

test('sürüm 4 (a): VARSAYILAN GEÇER — bilinmeyen `benMisafir` aramayı ENGELLEMEZ', async () => {
  // Adım 12'deki tercih okumasının BİLİNÇLİ TERSİ. Orada bilinmeyeni "açık"
  // saymak HERKESİ aranabilir yapardı (sessiz ve geniş zarar). Burada
  // bilinmeyeni "misafir" saymak GERÇEK kullanıcıları susturur — çok daha
  // pahalı. `=== true` yalnız kesin bilgide engeller.
  for (const v of [undefined, null, false, 0, '', 'true']) {
    const r = await baslatYetki(girdiYap({ benMisafir: v }), kaynakYap());
    assert.equal(r.tamam, true, `benMisafir=${JSON.stringify(v)} aramayı engelledi`);
  }
});

test('sürüm 4 (b): MİSAFİR ARANAMAZ — 403 ALICI_MISAFIR, 404 KULLANICI_YOK DEĞİL', async () => {
  const k = kaynakYap({
    hedefBul: async () => ({ id: 2, misafir: true, yasakli: false }),
  });
  const r = await baslatYetki(girdiYap(), k);
  assert.equal(r.http, 403, '404 dönüyor: eski `AND misafir=false` süzgeci geri gelmiş olabilir');
  assert.equal(r.kod, KOD.ALICI_MISAFIR);
  assert.notEqual(r.kod, KOD.KULLANICI_YOK,
    'kullanıcı VAR; "bulunamadı" demek 10 Ağu\'daki hatanın ta kendisiydi');
});

test('sürüm 4 (b): ALICI_MISAFIR, ENGELLİ ve TAKİP_YOK\'tan ÖNCE gelir', async () => {
  // Gerekçe: `TAKIP_YOK` önce dönseydi kullanıcıya YAPILAMAZ bir iş önerirdik
  // — "karşılıklı takipleşin" deyip takipleştikten sonra arama yine olmazdı.
  // Yanlış kurtarma yolu, kurtarma yolu olmamasından kötüdür.
  const k = kaynakYap({
    hedefBul: async () => ({ id: 2, misafir: true, yasakli: false }),
    engelliMi: async () => true,
    karsilikliMi: async () => false,
  });
  const r = await baslatYetki(girdiYap(), k);
  assert.equal(r.kod, KOD.ALICI_MISAFIR);
  assert.deepEqual(k.izler, [],
    'misafir hedefte engelleme/takip sorguları boşuna atılıyor');
});

test('sürüm 4 (b): hedef misafir DEĞİLSE zincir bozulmaz (gerçek kullanıcılar etkilenmez)', async () => {
  for (const v of [undefined, null, false]) {
    const r = await baslatYetki(girdiYap(),
      kaynakYap({
        hedefBul: async () => ({
          id: 2, misafir: v, yasakli: false, kabulSesli: true, kabulGoruntulu: true,
        }),
      }));
    assert.equal(r.tamam, true, `misafir=${JSON.stringify(v)} gerçek kullanıcıyı engelledi`);
  }
});

test('sürüm 4: `hedefBul` sorgusu misafirleri SÜZMÜYOR (regresyon kilidi)', () => {
  const blok = SERVER.slice(SERVER.indexOf("app.post('/arama/baslat'"),
    SERVER.indexOf("app.get('/arama/durum/:aramaId'"));
  const sorgu = blok.slice(blok.indexOf('hedefBul: async'), blok.indexOf('engelliMi:'));
  // Yorumlar ayıklanır: bu dosyadaki AÇIKLAMA metni de "AND misafir=false"
  // ifadesini geçiriyor (kasten — geri eklenmemesi gerektiğini anlatıyor).
  const kod = sorgu.replace(/\/\/.*$/gm, '');
  assert.ok(!/misafir\s*=\s*false/.test(kod),
    '`AND misafir=false` geri gelmiş: misafir hedef yine 404 KULLANICI_YOK verecek');
  assert.match(kod, /WHERE kullanici_adi=\$1`/,
    'hedef sorgusunun WHERE\'ine yeni bir süzgeç eklenmiş');
  assert.match(sorgu, /SELECT id, misafir, yasakli/);
  assert.match(sorgu, /misafir: rows\[0\]\.misafir === true/);
  // Arayanın hesap türü ek sorgu atmadan, `girisZorunlu`nun okuduğu önbellekten.
  assert.match(blok, /benMisafir: req\.misafir === true/);
});

test('GEÇERSİZ tur/sdp 400 — ve VERİTABANINA HİÇ GİDİLMEZ', async () => {
  for (const u of [{ tur: 'video' }, { tur: null }, { sdp: 'merhaba' },
    { sdp: '' }, { kullaniciAdi: '' }, { kullaniciAdi: null },
    { sdp: `v=0${'x'.repeat(SDP_AZAMI_BAYT)}` }]) {
    const k = kaynakYap();
    const r = await baslatYetki(girdiYap(u), k);
    assert.equal(r.http, 400, JSON.stringify(u));
    assert.equal(r.kod, KOD.GECERSIZ_ISTEK);
    assert.deepEqual(k.izler, [], `doğrulama başarısızken sorgu atıldı: ${JSON.stringify(u)}`);
  }
});

test('SIRA BAĞLAYICI: ucuz/sızdırmayan kontroller ÖNCE, sorgular sonra', async () => {
  const k = kaynakYap();
  const r = await baslatYetki(girdiYap(), k);
  assert.equal(r.tamam, true);
  assert.deepEqual(k.izler,
    ['hedefBul', 'engelliMi', 'karsilikliMi', 'sessizKalanSn', 'mesgulMu', 'mesgulMu'],
    'sözleşme §5 sırası bozuldu');
});

test('SIRA: engelli kullanıcıda TAKİP sorgusu HİÇ atılmaz (gereksiz sızıntı yok)', async () => {
  const k = kaynakYap({ engelliMi: async () => true });
  await baslatYetki(girdiYap(), k);
  assert.ok(!k.izler.includes('karsilikliMi'));
  assert.ok(!k.izler.includes('mesgulMu'));
});

// ===========================================================================
// 4. ÇİFT BAZLI SESSİZLEŞTİRME (§9.1) — asıl taciz koruması
// ===========================================================================
test('sessizleştirme: 15 dk içinde 3 cevapsız -> 1 saat arama yok', () => {
  const d = new SessizDepo();
  const t = 1_000_000_000;
  assert.equal(d.kalanSn(1, 2, t), 0);
  d.cevapsizKaydet(1, 2, t);
  d.cevapsizKaydet(1, 2, t + 60_000);
  assert.equal(d.kalanSn(1, 2, t + 60_000), 0, '2 cevapsız henüz ceza değil');
  d.cevapsizKaydet(1, 2, t + 120_000);
  const kalan = d.kalanSn(1, 2, t + 120_000);
  assert.ok(kalan > 3500 && kalan <= 3600, `beklenen ~1 saat, gelen ${kalan}`);
  assert.equal(d.kalanSn(1, 2, t + 120_000 + SESSIZ_CEZA_MS + 1), 0, 'ceza süresi dolmalı');
});

test('sessizleştirme: pencereye YAYILMIŞ 3 cevapsız CEZA DEĞİL', () => {
  const d = new SessizDepo();
  const t = 1_000_000_000;
  d.cevapsizKaydet(1, 2, t);
  d.cevapsizKaydet(1, 2, t + SESSIZ_PENCERE_MS + 1);
  d.cevapsizKaydet(1, 2, t + 2 * (SESSIZ_PENCERE_MS + 1));
  assert.equal(d.kalanSn(1, 2, t + 2 * (SESSIZ_PENCERE_MS + 1)), 0);
});

test('sessizleştirme: bir CEVAPLANDI sayacı SIFIRLAR (arkadaşlar cezalanmasın)', () => {
  const d = new SessizDepo();
  const t = 1_000_000_000;
  for (let i = 0; i < SESSIZ_ESIK; i++) d.cevapsizKaydet(1, 2, t + i * 1000);
  assert.ok(d.kalanSn(1, 2, t) > 0);
  d.sifirla(1, 2);
  assert.equal(d.kalanSn(1, 2, t), 0);
});

test('sessizleştirme YÖNLÜ: A→B cezası B→A aramasını engellemez', () => {
  const d = new SessizDepo();
  const t = 1_000_000_000;
  for (let i = 0; i < SESSIZ_ESIK; i++) d.cevapsizKaydet(1, 2, t + i * 1000);
  assert.ok(d.kalanSn(1, 2, t) > 0);
  assert.equal(d.kalanSn(2, 1, t), 0, 'kurban arayanı geri arayabilmeli');
});

test('sessizleştirme yetki zincirinde 429 + kalan_sn ile dönüyor', async () => {
  const r = await baslatYetki(girdiYap(), kaynakYap({ sessizKalanSn: async () => 1234 }));
  assert.equal(r.http, 429);
  assert.equal(r.kod, KOD.COK_FAZLA_CEVAPSIZ);
  assert.equal(r.kalan_sn, 1234);
});

test('sessizleştirmeye YALNIZ cevapsız durumlar yazılır, cevaplandı yazılmaz', () => {
  assert.deepEqual([...CEVAPSIZ_DURUMLAR].sort(), ['cevapsiz', 'iptal', 'reddedildi']);
  assert.ok(!CEVAPSIZ_DURUMLAR.includes('cevaplandi'));
  assert.ok(!CEVAPSIZ_DURUMLAR.includes('mesgul'), 'meşgul kurbanın suçu değil');
});

// ===========================================================================
// 5. AYNI ANDA TEK ARAMA + MEŞGUL
// ===========================================================================
test('AYNI ANDA TEK ARAMA: arayan zaten aramadaysa 409 ZATEN_ARAMADA', async () => {
  const r = await baslatYetki(girdiYap(),
    kaynakYap({ mesgulMu: async (id) => id === 1 }));
  assert.equal(r.http, 409);
  assert.equal(r.kod, KOD.ZATEN_ARAMADA);
});

test('MEŞGUL: aranan aramadaysa HATA DEĞİL — 200 + durum:mesgul', async () => {
  const r = await baslatYetki(girdiYap(), kaynakYap({ mesgulMu: async (id) => id === 2 }));
  assert.equal(r.tamam, true);
  assert.equal(r.mesgul, true, 'meşgul 400/409 değil, aramanın normal sonucu');
});

test('depo: bir kullanıcı aynı anda EN ÇOK bir aramada (arayan da aranan da)', () => {
  const d = new AramaDeposu();
  assert.equal(d.mesgulMu(1), false);
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  assert.equal(d.mesgulMu(1), true);
  assert.equal(d.mesgulMu(2), true, 'ARANAN da meşgul sayılmalı');
  d.uclastir(k, 'iptal');
  assert.equal(d.mesgulMu(1), false);
  assert.equal(d.mesgulMu(2), false, 'uçlaşınca iki taraf da serbest kalmalı');
});

test('depo: uçlaşma iki tarafı da bırakır, KİLİT KALMAZ', () => {
  const d = new AramaDeposu();
  const k1 = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  d.bitir(k1, 1, 'kullanici', null);
  const k2 = d.olustur({ arayanId: 1, arananId: 3, tur: 'ses', teklifSdp: SDP });
  assert.ok(k2.id !== k1.id);
  assert.equal(d.mesgulMu(2), false);
});

test('arama_id rastgele 128 bit hex (artan tamsayı DEĞİL — numaralandırma yok)', () => {
  const a = aramaKimlik();
  assert.match(a, /^[0-9a-f]{32}$/);
  const kume = new Set(Array.from({ length: 500 }, () => aramaKimlik()));
  assert.equal(kume.size, 500);
});

// ===========================================================================
// 6. DURUM MAKİNESİ + 45 SANİYELİK ÇALMA SINIRI (sunucuda zorlanır)
// ===========================================================================
test('45 sn çalma sınırı SUNUCUDA: süpürme `cevapsiz` yapar ve belleği boşaltır', () => {
  const d = new AramaDeposu();
  const t = 2_000_000_000;
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP }, t);
  assert.equal(k.sonaErme, t + CALMA_MS);
  assert.deepEqual(d.supur(t + CALMA_MS - 1), [], 'erken süpürme olmamalı');
  const c = d.supur(t + CALMA_MS);
  assert.equal(c.length, 1);
  assert.equal(c[0].durum, 'cevapsiz');
  assert.equal(d.getir(k.id), null, 'hayalet kayıt kalmamalı');
  assert.equal(d.mesgulMu(1), false);
});

test('kabul edilen arama süpürülmez; TTL 4 saatlik üst sınıra geçer', () => {
  const d = new AramaDeposu();
  const t = 2_000_000_000;
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP }, t);
  d.kabulEt(k, SDP, t + 5_000);
  assert.equal(k.durum, 'baglaniyor');
  assert.equal(k.sonaErme, t + 5_000 + AZAMI_ARAMA_MS);
  assert.deepEqual(d.supur(t + CALMA_MS + 1), [], '45 sn kuralı kabul sonrası uygulanmamalı');
});

test('4 saatlik üst sınır: `bitir` hiç gelmezse kullanıcı SONSUZA KİLİTLENMEZ', () => {
  const d = new AramaDeposu();
  const t = 2_000_000_000;
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP }, t);
  d.kabulEt(k, SDP, t);
  const c = d.supur(t + AZAMI_ARAMA_MS);
  assert.equal(c.length, 1);
  assert.equal(c[0].durum, 'cevaplandi');
  assert.equal(c[0].satir.saniye, AZAMI_ARAMA_MS / 1000);
  assert.equal(d.mesgulMu(1), false);
  assert.equal(d.mesgulMu(2), false);
});

test('bitir: çalarken ARAYAN kapatırsa `iptal`, ARANAN kapatırsa `reddedildi`', () => {
  const d = new AramaDeposu();
  const k1 = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  assert.equal(d.bitir(k1, 1, 'kullanici', null).durum, 'iptal');
  const k2 = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  assert.equal(d.bitir(k2, 2, 'kullanici', null).durum, 'reddedildi');
});

test('bitir: kabul sonrası `cevaplandi` + süre; `ice_basarisiz` -> `basarisiz`', () => {
  const d = new AramaDeposu();
  const t = 2_000_000_000;
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP }, t);
  d.kabulEt(k, SDP, t);
  const s = d.bitir(k, 1, 'kullanici', null, t + 312_000);
  assert.equal(s.durum, 'cevaplandi');
  assert.equal(s.saniye, 312);

  const k2 = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP }, t);
  d.kabulEt(k2, SDP, t);
  const s2 = d.bitir(k2, 2, 'ice_basarisiz', null, t + 4_000);
  assert.equal(s2.durum, 'basarisiz');
  assert.equal(s2.satir.saniye, null, 'başarısızda süre yazılmaz');
});

test('SDP cevabı BİR KEZ teslim edilir, sonra bellekten SİLİNİR', () => {
  const d = new AramaDeposu();
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  d.kabulEt(k, 'v=0\r\ncevap');
  assert.equal(d.cevapAl(k, 2), null, 'ARANAN kendi cevabını geri almamalı');
  assert.equal(d.cevapAl(k, 1), 'v=0\r\ncevap');
  assert.equal(d.cevapAl(k, 1), null, 'ikinci yoklamada null gelmeli (idempotent)');
});

test('ICE adayları KARŞI tarafın kuyruğuna gider ve okununca SİLİNİR', () => {
  const d = new AramaDeposu();
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  d.adayEkle(k, 1, [{ candidate: 'candidate:1 1 udp', sdpMid: '0', sdpMLineIndex: 0 }]);
  assert.deepEqual(d.adaylariAl(k, 1), [], 'gönderen kendi adayını almamalı');
  assert.equal(d.adaylariAl(k, 2).length, 1);
  assert.deepEqual(d.adaylariAl(k, 2), [], 'teslim edilen aday silinmeli');
});

test('aday doğrulama: en çok 20 aday, aday dizesi ≤512 bayt', () => {
  const iyi = { candidate: 'candidate:1 1 udp 1 1.2.3.4 1 typ host', sdpMid: '0', sdpMLineIndex: 0 };
  assert.equal(adaylariTemizle([iyi]).tamam, true);
  assert.equal(adaylariTemizle(Array(21).fill(iyi)).tamam, false);
  assert.equal(adaylariTemizle([{ candidate: 'x'.repeat(513) }]).tamam, false);
  assert.equal(adaylariTemizle([]).tamam, false);
  assert.equal(adaylariTemizle('candidate:1').tamam, false);
  assert.equal(adaylariTemizle([{ sdpMid: '0' }]).tamam, false);
});

test('yanıt: arayan cevap veremez (403 TARAF_DEGIL); geç kalan yanıt 409', async () => {
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', durum: 'caliyor' };
  const arayan = await yanitYetki(
    { aramaAcik: true, goruntuluAcik: true, benId: 1, kayit, kabul: true, sdp: SDP },
    kaynakYap());
  assert.equal(arayan.http, 403);
  assert.equal(arayan.kod, KOD.TARAF_DEGIL);

  const gec = await yanitYetki({
    aramaAcik: true, goruntuluAcik: true, benId: 2, kabul: true, sdp: SDP,
    kayit: { ...kayit, durum: 'baglaniyor' },
  }, kaynakYap());
  assert.equal(gec.http, 409);
  assert.equal(gec.kod, KOD.DURUM_UYGUN_DEGIL);

  const yok = await yanitYetki(
    { aramaAcik: true, goruntuluAcik: true, benId: 2, kayit: null, kabul: true, sdp: SDP },
    kaynakYap());
  assert.equal(yok.http, 404);
  assert.equal(yok.kod, KOD.ARAMA_YOK);
});

test('yanıt: kabul:true iken SDP zorunlu, kabul:false iken SDP yok sayılır', async () => {
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', durum: 'caliyor' };
  const taban = { aramaAcik: true, goruntuluAcik: true, benId: 2, kayit };
  const sdpsiz = await yanitYetki({ ...taban, kabul: true, sdp: null }, kaynakYap());
  assert.equal(sdpsiz.http, 400);
  assert.equal(sdpsiz.kod, KOD.GECERSIZ_ISTEK);
  const red = await yanitYetki({ ...taban, kabul: false, sdp: null }, kaynakYap());
  assert.equal(red.tamam, true);
});

test('taraf olmayan üçüncü kullanıcı aramayı GÖREMEZ', () => {
  const d = new AramaDeposu();
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'ses', teklifSdp: SDP });
  assert.equal(d.tarafMi(k, 3), false);
  assert.equal(d.tarafMi(k, 1), true);
  assert.equal(d.tarafMi(k, 2), true);
  assert.equal(d.gelenBul(3), null);
  assert.equal(d.gelenBul(2).id, k.id, 'çalan arama YALNIZ arananda görünür');
  assert.equal(d.gelenBul(1), null, 'arayan kendi aramasını "gelen" olarak görmemeli');
});

test('BAĞLANTI: /arama/durum taraf olmayana 404 döner (403 varlık sızdırırdı)', () => {
  const uc = SERVER.slice(SERVER.indexOf("app.get('/arama/durum/:aramaId'"),
    SERVER.indexOf("app.get('/arama/gelen'"));
  assert.ok(/tarafMi\(kayit, req\.kullanici\.id\)/.test(uc));
  assert.ok(/status\(404\)/.test(uc));
  assert.ok(!/status\(403\)/.test(uc), '403 "böyle bir arama var" bilgisini sızdırır');
});

// ===========================================================================
// 7. YASAKLI KULLANICI — `/arama/bitir` MUAF, diğerleri DEĞİL
// ===========================================================================
test('BANLI KULLANICI: /arama/baslat ve /arama/yanit 403 (muaf DEĞİL)', () => {
  assert.equal(yazmaYasakli('POST', '/arama/baslat'), true);
  assert.equal(yazmaYasakli('POST', '/arama/yanit'), true);
  assert.equal(yazmaYasakli('POST', '/arama/aday'), true);
});

test('*** /arama/bitir YASAK_MUAF\'TA *** — yoksa hayalet arama + kilitli kullanıcı', () => {
  assert.ok(YASAK_MUAF.includes('/arama/bitir'),
    'muafiyet silinmiş: banlı kullanıcı aramayı temiz kapatamaz');
  assert.equal(yazmaYasakli('POST', '/arama/bitir'), false);
  // TAM eşleşme (sondaki `/` YOK) — ön ek olsaydı `/arama/bitirme` gibi bir uç
  // sessizce muaf olurdu.
  assert.ok(!YASAK_MUAF.includes('/arama/bitir/'));
  assert.equal(yazmaYasakli('POST', '/arama/bitirme'), true);
  assert.equal(yazmaYasakli('POST', '/arama/bitir/x'), true);
});

test('BANLI KULLANICI okuma uçlarını kullanabilir (GET kapıyı hiç görmez)', () => {
  for (const y of ['/arama/durum/9f2c', '/arama/gelen', '/arama/gecmis',
    '/arama/buz-sunuculari']) {
    assert.equal(yazmaYasakli('GET', y), false, y);
  }
});

test('BAĞLANTI: /arama/bitir kill switch\'e TAKILMIYOR (kapatılan özellikte de kapanabilsin)', () => {
  const uc = SERVER.slice(SERVER.indexOf("app.post('/arama/bitir'"),
    SERVER.indexOf("app.get('/arama/gecmis'"));
  assert.ok(!/aramaBayraklari\(\)/.test(uc),
    '/arama/bitir kill switch okursa devam eden arama kapatılamaz');
});

// ===========================================================================
// 8. ÜSTVERİ — İÇERİK YOK (mimari zorunluluk, politika değil)
// ===========================================================================
const ALAN_LISTESI = [
  'arayan_id', 'aranan_id', 'tur', 'durum', 'baslangic', 'bitis',
  'saniye', 'role_dustu', 'role_bayt', 'sonlandiran_id',
];

test('*** ÜSTVERİ DIŞINDA HİÇBİR İÇERİK ALANI SAKLANMIYOR ***', () => {
  const d = new AramaDeposu();
  const k = d.olustur({ arayanId: 1, arananId: 2, tur: 'goruntu', teklifSdp: SDP });
  d.kabulEt(k, 'v=0\r\nBU-CEVAP-SDP-ASLA-KAYDEDILMEZ');
  d.adayEkle(k, 1, [{ candidate: 'candidate:GIZLI-IP 1 udp 1 9.9.9.9 1 typ host' }]);
  const satir = d.bitir(k, 1, 'kullanici',
    olcumTemizle({ role_dustu: true, bayt_gonderilen: 10, bayt_alinan: 20 })).satir;

  assert.deepEqual(Object.keys(satir).sort(), [...ALAN_LISTESI].sort(),
    'aramalar satırına YENİ BİR ALAN eklenmiş — içerik sızıyor olabilir');
  const metin = JSON.stringify(satir);
  for (const yasakli of ['v=0', 'sdp', 'candidate', '9.9.9.9', 'GIZLI', 'ip', 'cihaz']) {
    assert.ok(!metin.toLowerCase().includes(yasakli.toLowerCase()),
      `üstveride içerik izi: ${yasakli}`);
  }
});

test('üstveri alanları migrasyondaki SÜTUNLARLA birebir aynı', () => {
  for (const alan of ALAN_LISTESI) {
    assert.ok(new RegExp(`\\b${alan}\\b`).test(MIGRASYON), `migrasyonda eksik sütun: ${alan}`);
  }
  // Migrasyon içerik sütunu eklememeli.
  for (const yasak of ['sdp', 'aday', 'ip_adres', 'transkript', 'metin']) {
    assert.ok(!new RegExp(`^\\s+${yasak}\\s`, 'mi').test(MIGRASYON),
      `migrasyonda içerik sütunu: ${yasak}`);
  }
});

test('şema kısıtı: süre YALNIZ `cevaplandi`da dolu olabilir', () => {
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', baslangic: 1 };
  assert.equal(ustveri(kayit, 'cevapsiz', { saniye: 90 }).saniye, null);
  assert.equal(ustveri(kayit, 'reddedildi', { saniye: 90 }).saniye, null);
  assert.equal(ustveri(kayit, 'cevaplandi', { saniye: 90 }).saniye, 90);
});

test('üstveri UÇ OLMAYAN durumu REDDEDER (yarım kayıt tabloya girmesin)', () => {
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', baslangic: 1 };
  assert.throws(() => ustveri(kayit, 'caliyor'), /Uç olmayan durum/);
  assert.throws(() => ustveri(kayit, 'baglaniyor'), /Uç olmayan durum/);
  assert.deepEqual([...UC_DURUMLAR].sort(),
    ['basarisiz', 'cevaplandi', 'cevapsiz', 'iptal', 'mesgul', 'reddedildi']);
});

test('`olcum` istemci beyanı TEMİZLENİR (negatif / saçma / 50 GB üstü yutulur)', () => {
  assert.deepEqual(olcumTemizle(null), { roleDustu: null, roleBayt: null });
  assert.deepEqual(olcumTemizle({ role_dustu: 'evet' }), { roleDustu: null, roleBayt: null });
  assert.deepEqual(olcumTemizle({ role_dustu: false, bayt_gonderilen: -5 }),
    { roleDustu: false, roleBayt: null });
  assert.equal(olcumTemizle({ bayt_gonderilen: 1e20, bayt_alinan: 1e20 }).roleBayt, null);
  assert.equal(olcumTemizle({ bayt_gonderilen: 10, bayt_alinan: 20 }).roleBayt, 30);
  assert.ok(olcumTemizle({ bayt_gonderilen: ROLE_BAYT_TAVAN, bayt_alinan: ROLE_BAYT_TAVAN })
    .roleBayt <= ROLE_BAYT_TAVAN);
});

test('role_dustu NULL kalabilir: "röleye düşmedi" ile "hiç bağlanmadı" AYNI DEĞİL', () => {
  // NOT NULL DEFAULT false olsaydı oran hesabı sessizce bozulurdu.
  const kayit = { arayanId: 1, arananId: 2, tur: 'ses', baslangic: 1 };
  assert.equal(ustveri(kayit, 'cevapsiz').role_dustu, null);
  assert.equal(ustveri(kayit, 'cevaplandi', { olcum: { roleDustu: false } }).role_dustu, false);
});

test('geçmiş yönü SUNUCU tarafında hesaplanır (istemci arayan_id görmez)', () => {
  assert.equal(gecmisYon({ arayan_id: 1 }, 1), 'giden');
  assert.equal(gecmisYon({ arayan_id: 2 }, 1), 'gelen');
  const uc = SERVER.slice(SERVER.indexOf("app.get('/arama/gecmis'"),
    SERVER.indexOf('// ---------- admin panel'));
  assert.ok(/gecmisYon\(r, benId\)/.test(uc));
  assert.ok(!/arayan_id: /.test(uc), 'yanıt gövdesine arayan_id sızmış');
});

// ===========================================================================
// 9. 90 GÜN BUDAMA
// ===========================================================================
test('SAKLAMA 90 GÜN (KVKK ölçülülük + yorum_goruntuleyen emsali)', () => {
  assert.equal(SAKLAMA_GUN, 90);
});

test('BUDAMA `tablolariBuda()` içinde — ek zamanlayıcı YOK', () => {
  const govde = SERVER.slice(SERVER.indexOf('async function tablolariBuda()'),
    SERVER.indexOf('setInterval(tablolariBuda'));
  assert.ok(/DELETE FROM aramalar WHERE baslangic < now\(\) - interval '\$\{ARAMA_SAKLAMA_GUN\} days'/
    .test(govde), 'aramalar budaması tablolariBuda listesinde yok');
  assert.ok(/DELETE FROM yorum_goruntuleyen WHERE tarih < now\(\) - interval '90 days'/.test(govde),
    'emsal 90 günlük budama kaybolmuş');
  assert.ok(/setInterval\(tablolariBuda, 24 \* 60 \* 60 \* 1000\)/.test(SERVER));
});

test('TRAFİK EŞİK UYARISI: eşik varsayılan 200 GB, OTOMATİK KAPATMA YOK', () => {
  const govde = SERVER.slice(SERVER.indexOf('async function aramaTrafigiKontrol()'),
    SERVER.indexOf('setInterval(tablolariBuda'));
  assert.ok(/ARAMA_TRAFIK_ESIK_GB \?\? '200'/.test(govde));
  assert.ok(/date_trunc\('month', now\(\)\)/.test(govde), 'içinde bulunulan ay hesaplanmalı');
  assert.ok(/ARAMA TRAFİK UYARISI/.test(govde));
  assert.ok(/'arama_trafik_uyari'/.test(govde));
  // Eşiğe çarpınca özelliği KENDİLİĞİNDEN kapatmak, bir ölçüm hatasının tüm
  // kullanıcılara kesinti yaşatması demektir. Karar insana ait.
  assert.ok(!/arama_acik.*'0'|UPDATE ayarlar SET deger='0'/.test(govde),
    'eşik uyarısı özelliği otomatik kapatıyor — bilinçli karara aykırı');
  // ÖLÇÜLEN ŞEY: çağrı `tablolariBuda`nın GÖVDESİNDE mi? Eskiden bu, "iki ad
  // 900 karakter içinde geçiyor mu" diye yazılıydı; 17 Ağu 2026'da gövdeye
  // `medyaKullanimiYenidenHesapla()` eklenince mesafe aşıldı ve test KOD
  // DOĞRUYKEN kırmızıya döndü. Yakınlık hiçbir zaman gereklilik değildi.
  const budaGovde = SERVER.slice(
    SERVER.indexOf('async function tablolariBuda()'),
    SERVER.indexOf('async function aramaTrafigiKontrol()'));
  assert.ok(budaGovde.includes('aramaTrafigiKontrol()'),
    'eşik kontrolü günlük budama işine bağlanmamış (ek zamanlayıcı istemiyoruz)');
});

// ===========================================================================
// 10. BİLDİRİM / FCM SÖZLEŞMESİ
// ===========================================================================
test('PUSH_SABLON 16 dilin HEPSİNDE `arama` ve `kacirilan_arama` taşıyor', () => {
  const blok = SERVER.slice(SERVER.indexOf('const PUSH_SABLON = {'),
    SERVER.indexOf('// Alıcının cihazlarına anlık push'));
  const diller = blok.match(/^ {2}([a-z]{2}): \{/gm) || [];
  assert.equal(diller.length, 16, `16 dil bekleniyordu, ${diller.length} bulundu`);
  // Şablon eksikse `pushBildirim` govde boş diye SESSİZCE return eder (satır
  // "if (!govde) return;") — yani gelen arama bildirimi HİÇ GİTMEZ.
  assert.equal((blok.match(/ arama: '/g) || []).length, 16);
  assert.equal((blok.match(/ kacirilan_arama: '/g) || []).length, 16);
  for (const d of diller) {
    const kod = d.trim().slice(0, 2);
    const satir = blok.split('\n').find((s) => s.startsWith(`  ${kod}: {`));
    assert.ok(satir.includes('{ad}'), `${kod} şablonunda {ad} yer tutucusu yok`);
  }
});

test('gelen arama push\'u DATA-ONLY ve ttl ÇALMA SÜRESİ kadar (45 sn)', () => {
  const dal = SERVER.slice(SERVER.indexOf("if (tur === 'arama') {"),
    SERVER.indexOf("} else if (tur === 'mesaj') {"));
  assert.ok(/android: \{ priority: 'high', ttl: CALMA_MS \}/.test(dal),
    'ttl yoksa FCM varsayılanı 4 HAFTA: telefon iki gün sonra çalar');
  assert.ok(!/notification:/.test(dal), 'arama push\'u data-only olmalı');
  assert.ok(/arama_id:/.test(dal) && /arama_turu:/.test(dal) && /sona_erme:/.test(dal));
  assert.equal(CALMA_MS, 45_000);
});

test('`bildir_arama` YALNIZ kaçırılan aramayı kapatır, telefonun çalmasını DEĞİL', () => {
  const harita = SERVER.slice(SERVER.indexOf('const BILDIRIM_TERCIH_KOLON = {'),
    SERVER.indexOf('async function bildirimEkle('));
  assert.ok(/kacirilan_arama: 'bildir_arama'/.test(harita));
  assert.ok(!/^\s+arama: 'bildir_arama'/m.test(harita),
    'aramanın kendisi bildirim tercihine bağlanmış — çalan telefon onay kutusu değildir');
  // Gelen arama push'u `bildirimEkle` değil doğrudan `pushBildirim` ile gider.
  const baslat = SERVER.slice(SERVER.indexOf("app.post('/arama/baslat'"),
    SERVER.indexOf("app.get('/arama/durum/:aramaId'"));
  assert.ok(/pushBildirim\(karar\.hedef\.id, 'arama'/.test(baslat));
  assert.ok(!/bildirimEkle\([^)]*'arama'/.test(baslat));
});

test('kaçırılan arama bildirimi: cevapsiz / iptal / mesgul', () => {
  assert.deepEqual([...KACIRILAN_DURUMLAR].sort(), ['cevapsiz', 'iptal', 'mesgul']);
  assert.ok(!KACIRILAN_DURUMLAR.includes('reddedildi'),
    'reddeden zaten gördü; ona "kaçırdın" demek yanlış');
  assert.ok(/bildirimEkle\(satir\.aranan_id, 'kacirilan_arama', satir\.arayan_id\)/.test(SERVER));
});

test('MİGRASYON bildirim türünü ve tercih sütununu ekliyor', () => {
  assert.ok(/CHECK \(tur IN \('yanit','begeni','takip','mesaj','etiket','kacirilan_arama'\)\)/
    .test(MIGRASYON), 'kısıt genişletilmezse bildirimEkle hatayı SESSİZCE yutar');
  assert.ok(/ADD COLUMN IF NOT EXISTS bildir_arama BOOLEAN NOT NULL DEFAULT true/.test(MIGRASYON));
});

// ===========================================================================
// 11. HIZ LİMİTLERİ — `aramaLimiti` gölgelenmesi
// ===========================================================================
test('*** `aramaLimiti` GÖLGELENMEDİ *** — yeni limiterler ayrı adlarda', () => {
  assert.equal((SERVER.match(/const aramaLimiti = /g) || []).length, 1);
  assert.ok(/const aramaLimiti = hizLimiti\(120, \(req\) => `s:\$\{req\.ip\}`\)/.test(SERVER),
    'search limiti bozulmuş');
  assert.ok(/const gorusmeLimiti = hizLimiti\(30, \(req\) => `gr:\$\{req\.kullanici\.id\}`\)/.test(SERVER));
  assert.ok(/const gorusmeDurumLimiti = hizLimiti\(5000, \(req\) => `gd:\$\{req\.kullanici\.id\}`\)/.test(SERVER));
  assert.ok(/const buzLimiti = hizLimiti\(60, \(req\) => `bz:\$\{req\.kullanici\.id\}`\)/.test(SERVER));
});

test('limiter anahtarı kullanici.id — req.ip DEĞİL (CGNAT tüm operatörü keserdi)', () => {
  for (const ad of ['gorusmeLimiti', 'gorusmeDurumLimiti', 'buzLimiti']) {
    const satir = SERVER.split('\n').find((s) => s.includes(`const ${ad} = hizLimiti(`));
    assert.ok(satir.includes('req.kullanici.id'), `${ad} kullanıcı kimliğiyle anahtarlanmalı`);
    assert.ok(!satir.includes('req.ip'), `${ad} IP ile anahtarlanmış — CGNAT tuzağı`);
  }
});

test('her arama ucu doğru ara katmanlarla bağlı', () => {
  const beklenen = {
    "app.get('/arama/buz-sunuculari'": 'girisZorunlu, buzLimiti',
    "app.post('/arama/baslat'": 'girisZorunlu, gorusmeLimiti',
    "app.get('/arama/durum/:aramaId'": 'girisZorunlu, gorusmeDurumLimiti',
    "app.get('/arama/gelen'": 'girisZorunlu, gorusmeDurumLimiti',
    "app.post('/arama/yanit'": 'girisZorunlu, gorusmeDurumLimiti',
    "app.post('/arama/aday'": 'girisZorunlu, gorusmeDurumLimiti',
    "app.post('/arama/bitir'": 'girisZorunlu, gorusmeDurumLimiti',
    "app.get('/arama/gecmis'": 'girisZorunlu, gorusmeDurumLimiti',
  };
  for (const [uc, ara] of Object.entries(beklenen)) {
    const i = SERVER.indexOf(uc);
    assert.ok(i > 0, `uç yok: ${uc}`);
    assert.ok(SERVER.slice(i, i + 160).includes(ara), `${uc} -> ${ara} bekleniyordu`);
  }
});

// ===========================================================================
// 12. BAĞLANTI DENETİMLERİ
// ===========================================================================
test('arama.js Dockerfile COPY listesinde (yoksa konteyner HİÇ AÇILMAZ)', () => {
  const copy = DOCKERFILE.split('\n').find((s) => s.startsWith('COPY server.js'));
  assert.ok(copy, 'COPY server.js satırı bulunamadı');
  assert.ok(/(^|\s)arama\.js(\s|$)/.test(copy),
    'arama.js imaja girmiyor: "Cannot find module ./arama.js" ile restart döngüsü');
});

test('arama.js SAF: içe aktarma yan etkisi yok (env/pg/express okumuyor)', () => {
  // Yorumlar ayıklanır (yasak.test.js ile aynı disiplin): gerekçe metinlerinde
  // `process.env` GEÇEBİLİR, önemli olan KODUN onu okumaması.
  const kod = ARAMA_SRC.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /require\(|from ['"]pg['"]|from ['"]express['"]/);
  assert.doesNotMatch(kod, /process\.env/,
    'saf modül ortamı doğrudan okuyor — kill switch testte enjekte edilemez hale gelir');
  // Yalnız node:crypto import edilebilir (kimlik + HMAC); başka bağımlılık yok.
  const importlar = kod.match(/^import .*$/gm) || [];
  assert.deepEqual(importlar, ["import crypto from 'node:crypto';"]);
  // Modül seviyesinde zamanlayıcı olmamalı (test süreci asılı kalmasın).
  assert.doesNotMatch(kod, /^setInterval|^setTimeout/m);
});

test('/proc/net/dev OKUNMUYOR (konteyner içinden veth okur, yanlış sayı üretir)', () => {
  // Yorumlar ayıklanır: TUZAĞI ANLATAN gerekçe metni geçebilir, önemli olan
  // KODUN o dosyayı okumaması (yanlış sayı, doğru sanılır).
  const kodsuz = (s) => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kodsuz(SERVER), /proc\/net\/dev/);
  assert.doesNotMatch(kodsuz(ARAMA_SRC), /proc\/net\/dev/);
});

test('SDP/ICE hiçbir yere YAZILMIYOR (INSERT/console yalnız üstveri taşır)', () => {
  const blok = SERVER.slice(SERVER.indexOf('// SESLİ / GÖRÜNTÜLÜ ARAMA'),
    SERVER.indexOf('// ---------- admin panel'));
  const yazmalar = blok.match(/havuz\.query\([\s\S]{0,400}?\)/g) || [];
  for (const y of yazmalar) {
    if (!/INSERT|UPDATE/.test(y)) continue;
    for (const yasak of ['sdp', 'aday', 'candidate', 'teklif', 'cevapSdp']) {
      assert.ok(!y.toLowerCase().includes(yasak.toLowerCase()),
        `veritabanı yazmasında içerik alanı: ${yasak}`);
    }
  }
  assert.ok(!/console\.(log|error|warn)\([^)]*sdp/i.test(blok), 'SDP günlüğe basılıyor');
});

test('sözleşmedeki 17 hata kodunun HEPSİ tanımlı ve çevrilmez sabit', () => {
  const bekleniyor = ['ARAMA_KAPALI', 'GORUNTULU_KAPALI', 'GECERSIZ_ISTEK',
    // Sürüm 4 — misafir hesaplar. İKİ AYRI kod, tek kod DEĞİL: biri arayana
    // "hesap oluştur" dedirtir, öteki aranan hakkındadır ve arayanın
    // yapabileceği bir şey yoktur. Tek kodla istemci yanlış öneri basardı.
    'MISAFIR_ARAMA_YOK', 'ALICI_MISAFIR',
    'KULLANICI_YOK',
    'KENDINE_ARAMA', 'ENGELLI', 'TAKIP_YOK', 'ALICI_YASAKLI',
    // md. 38 — kullanıcı başına tercih. SUNUCU GENELİ kill switch kodlarından
    // (`ARAMA_KAPALI`/`GORUNTULU_KAPALI`) AYRI olmak zorunda: istemci "aradığın
    // kişide kapalı" ile "özellik şu an kapalı"yı karıştırırsa kullanıcı
    // uygulamayı bozuk sanır.
    'ALICI_SESLI_KAPALI', 'ALICI_GORUNTULU_KAPALI',
    'COK_FAZLA_CEVAPSIZ',
    'ZATEN_ARAMADA', 'DURUM_UYGUN_DEGIL', 'TARAF_DEGIL', 'ARAMA_YOK'];
  for (const k of bekleniyor) assert.equal(KOD[k], k, `hata kodu eksik/yanlış: ${k}`);
  assert.equal(Object.keys(KOD).length, bekleniyor.length, 'sözleşmede olmayan kod eklenmiş');
  assert.equal(Object.isFrozen(KOD), true);
});

test('SDP tavanı 64 KB (sınırsız SDP bellek şişirme yolu)', () => {
  assert.equal(SDP_AZAMI_BAYT, 65_536);
  assert.equal(sdpGecerliMi(SDP), true);
  assert.equal(sdpGecerliMi('o=- 1 1 IN IP4'), false, '"v=0" ile başlamalı');
  assert.equal(sdpGecerliMi(`v=0${'x'.repeat(SDP_AZAMI_BAYT)}`), false);
  assert.equal(sdpGecerliMi(null), false);
  assert.equal(sdpGecerliMi(123), false);
});

// ===========================================================================
// 13. KULLANICI BAŞINA ARAMA TERCİHİ (istek listesi md. 38)
// ===========================================================================
// Kullanıcının kendi sözleri (10 Ağu): "sesli ve görüntülü aramalar devre dışı
// bırakma özelliği olmalı ve bu özellik OTOMATİK OLARAK KAPALI olmalı ...
// aranan otomatik olarak çağrıyı reddedecek ve arayanın ekranında şunu
// diyecek: 'aradığınız kişide sesli arama özelliği devre dışı'".
//
// Üç şeyi birden kilitliyoruz:
//   (a) varsayılan KAPALI ve VARSAYILAN-RET okunuyor,
//   (b) tür bazlı DOĞRU kod dönüyor (sesli/görüntülü karışmıyor),
//   (c) *** bu red, arayanı SESSİZLEŞTİRME sayacına sokmuyor ***.
// (c) sessiz bozulur ve kimse fark etmez: özelliği kapatan kişi, kendisini
// arayan masum kullanıcıyı 1 saat susturmuş olur.

/** Aranan tarafın tercihini ayarlayan `hedefBul`. */
const hedefTercih = (sesli, goruntulu) => async () =>
  ({ id: 2, yasakli: false, kabulSesli: sesli, kabulGoruntulu: goruntulu });

test('md.38 VARSAYILAN KAPALI: tercih hiç yollanmazsa arama BAŞLAMAZ', async () => {
  // Sütunu okumayı unutan bir sorgu ya da migrasyonsuz bir veritabanı tam
  // olarak bu şekli üretir. VARSAYILAN-RET olmasaydı özelliğin yokluğu
  // "herkes aranabilir" diye SESSİZCE yorumlanırdı.
  const bos = async () => ({ id: 2, yasakli: false });
  const s = await baslatYetki(girdiYap({ tur: 'ses' }), kaynakYap({ hedefBul: bos }));
  assert.equal(s.http, 403);
  assert.equal(s.kod, KOD.ALICI_SESLI_KAPALI);

  const g = await baslatYetki(girdiYap({ tur: 'goruntu' }), kaynakYap({ hedefBul: bos }));
  assert.equal(g.http, 403);
  assert.equal(g.kod, KOD.ALICI_GORUNTULU_KAPALI);
});

test('md.38 TÜR BAZLI: sesli açık + görüntülü kapalı -> yalnız görüntülü reddedilir', async () => {
  const kaynak = () => kaynakYap({ hedefBul: hedefTercih(true, false) });
  const s = await baslatYetki(girdiYap({ tur: 'ses' }), kaynak());
  assert.equal(s.tamam, true, 'sesli açıkken sesli arama engellendi');

  const g = await baslatYetki(girdiYap({ tur: 'goruntu' }), kaynak());
  assert.equal(g.kod, KOD.ALICI_GORUNTULU_KAPALI);
  // Kullanıcı "sesli arama devre dışı" görmemeli — yanlış sebep, yanlış eylem.
  assert.notEqual(g.kod, KOD.ALICI_SESLI_KAPALI);
});

test('md.38 TÜR BAZLI: görüntülü açık + sesli kapalı -> yalnız sesli reddedilir', async () => {
  const kaynak = () => kaynakYap({ hedefBul: hedefTercih(false, true) });
  const g = await baslatYetki(girdiYap({ tur: 'goruntu' }), kaynak());
  assert.equal(g.tamam, true, 'görüntülü açıkken görüntülü arama engellendi');

  const s = await baslatYetki(girdiYap({ tur: 'ses' }), kaynak());
  assert.equal(s.kod, KOD.ALICI_SESLI_KAPALI);
  assert.notEqual(s.kod, KOD.ALICI_GORUNTULU_KAPALI);
});

test('*** md.38 KAPALI REDDİ SESSİZLEŞTİRME SAYACINA GİRMEZ ***', async () => {
  // Sözleşme §9.1: 15 dk'da 3 cevapsız -> o kişiye 1 saat arama yasağı.
  // Kapalı olduğu için reddedilen arama bu sayaca GİRMEMELİ.
  const depo = new SessizDepo();
  const kaynak = kaynakYap({
    hedefBul: hedefTercih(false, false),
    sessizKalanSn: async (a, b) => depo.kalanSn(a, b),
  });

  // Eşiğin (3) çok üstünde deneme:
  for (let i = 0; i < 10; i++) {
    const r = await baslatYetki(girdiYap(), kaynak);
    assert.equal(r.kod, KOD.ALICI_SESLI_KAPALI);
  }
  assert.equal(depo.kalanSn(1, 2), 0,
    'kapalı reddi ceza doğurdu: özelliği kapatan kişi arayanı susturmuş olur');

  // ZİNCİRİN KENDİSİ KANIT: tercih kontrolü sessizleştirme sorgusundan ÖNCE
  // dönüyor, yani ceza yolu HİÇ AÇILMIYOR (kayıt oluşmuyor -> uçlaşma yok ->
  // `cevapsizKaydet` çağrılmıyor).
  assert.ok(!kaynak.izler.includes('sessizKalanSn'),
    'kapalı kullanıcıda sessizleştirme yoluna girildi');
  assert.ok(!kaynak.izler.includes('mesgulMu'),
    'kapalı kullanıcıda kayıt oluşturma yoluna yaklaşıldı');

  // Ve karşı taraf tercihini AÇTIĞI AN arama mümkün — gecikmiş ceza yok.
  const acik = kaynakYap({ sessizKalanSn: async (a, b) => depo.kalanSn(a, b) });
  assert.equal((await baslatYetki(girdiYap(), acik)).tamam, true);
});

test('md.38 sessizleştirme sayacı YALNIZ uçlaşan kayıttan besleniyor', () => {
  // Yapısal güvence: `cevapsizKaydet` server.js'te TEK yerde çağrılıyor ve
  // orası `aramaUclandi` — yani ancak GERÇEKTEN oluşmuş bir arama kaydı
  // uçlaştığında. `/arama/baslat` erken dönüşleri oraya hiç uğramaz.
  const cagrilar = SERVER.match(/sessizDepo\.cevapsizKaydet\(/g) || [];
  assert.equal(cagrilar.length, 1,
    'cevapsizKaydet birden fazla yerden çağrılıyor: muafiyet sessizce delinebilir');
  const uclandi = SERVER.slice(SERVER.indexOf('function aramaUclandi'));
  assert.ok(uclandi.slice(0, uclandi.indexOf('\n}\n')).includes('sessizDepo.cevapsizKaydet('),
    'cevapsizKaydet aramaUclandi dışına taşınmış');
});

test('md.38 ÜÇ KATMAN AYRI AYRI DOĞRU KODU VERİYOR (yanlış sebep = "uygulama bozuk")', async () => {
  // 1) Sunucu geneli bayrak
  const k1 = await baslatYetki(girdiYap({ aramaAcik: false }), kaynakYap());
  assert.equal(k1.http, 503);
  assert.equal(k1.kod, KOD.ARAMA_KAPALI);

  const k1g = await baslatYetki(
    girdiYap({ goruntuluAcik: false, tur: 'goruntu' }), kaynakYap());
  assert.equal(k1g.http, 503);
  assert.equal(k1g.kod, KOD.GORUNTULU_KAPALI);

  // 2) Kullanıcının kendi tercihi
  const k2 = await baslatYetki(girdiYap(), kaynakYap({ hedefBul: hedefTercih(false, false) }));
  assert.equal(k2.http, 403);
  assert.equal(k2.kod, KOD.ALICI_SESLI_KAPALI);

  // 3) Karşılıklı takip
  const k3 = await baslatYetki(girdiYap(), kaynakYap({ karsilikliMi: async () => false }));
  assert.equal(k3.http, 403);
  assert.equal(k3.kod, KOD.TAKIP_YOK);

  // Dördü de FARKLI kod: istemci hangi katmanın engellediğini ayırt edebiliyor.
  const kodlar = [k1.kod, k1g.kod, k2.kod, k3.kod];
  assert.equal(new Set(kodlar).size, 4, `kodlar çakışıyor: ${kodlar}`);
});

test('md.38 ÖNCELİK SIRASI: sunucu bayrağı > takip/engel > kendi tercihi > sessizleştirme', async () => {
  const kapaliHedef = { hedefBul: hedefTercih(false, false) };

  // Sunucu bayrağı kapalıysa tercih hiç okunmaz (503 önce gelir):
  const a = await baslatYetki(girdiYap({ aramaAcik: false }), kaynakYap(kapaliHedef));
  assert.equal(a.kod, KOD.ARAMA_KAPALI);

  // Karşılıklı takip yoksa tercih SIZDIRILMAZ: "bu kişide arama kapalı" demek
  // başkasının ayarını ifşa etmektir; yalnız karşılıklı takipleştiğin biri
  // hakkında öğrenilebilir.
  const b = await baslatYetki(girdiYap(),
    kaynakYap({ ...kapaliHedef, karsilikliMi: async () => false }));
  assert.equal(b.kod, KOD.TAKIP_YOK);

  // Engellemede de sızmaz.
  const c = await baslatYetki(girdiYap(),
    kaynakYap({ ...kapaliHedef, engelliMi: async () => true }));
  assert.equal(c.kod, KOD.ENGELLI);

  // Yasaklı hesapta da sızmaz — genel "şu anda aranamıyor" yeterli.
  const d = await baslatYetki(girdiYap(),
    kaynakYap({ hedefBul: async () => ({ id: 2, yasakli: true, kabulSesli: false }) }));
  assert.equal(d.kod, KOD.ALICI_YASAKLI);

  // Sessizleştirme cezası VARKEN bile kalıcı sebep (kapalı) önce söylenir.
  const e = await baslatYetki(girdiYap(),
    kaynakYap({ ...kapaliHedef, sessizKalanSn: async () => 3600 }));
  assert.equal(e.kod, KOD.ALICI_SESLI_KAPALI);
});

test('md.38 zincir sırası: tercih kontrolü YASAKLI ile SESSİZLEŞTİRME arasında', async () => {
  const k = kaynakYap({ hedefBul: hedefTercih(false, false) });
  await baslatYetki(girdiYap(), k);
  // (`hedefBul` üzerine yazıldığı için ize düşmüyor; ölçtüğümüz ondan SONRAKİ
  //  zincir.) Engel ve takip kontrolleri ÖNCE koşmuş, sessizleştirme ve
  //  meşgul sorguları HİÇ atılmamış olmalı.
  assert.deepEqual(k.izler, ['engelliMi', 'karsilikliMi'],
    'tercih kontrolü sözleşme §5 sırasının dışına kaymış');
});

// ---------------------------------------------------------------------------
// 13b. BAĞLANTI — sütunlar gerçekten okunuyor mu, migrasyon doğru mu
// ---------------------------------------------------------------------------
const MIG_38 = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-10.sql'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

test('md.38 migrasyon: iki sütun da NOT NULL DEFAULT false (varsayılan KAPALI)', () => {
  for (const s of ['sesli_arama_acik', 'goruntulu_arama_acik']) {
    const re = new RegExp(`ADD COLUMN IF NOT EXISTS ${s} BOOLEAN NOT NULL DEFAULT false`);
    assert.match(MIG_38, re, `migrasyonda eksik/yanlış sütun: ${s}`);
    assert.match(SEMA, re, `sema.sql'e işlenmemiş sütun: ${s}`);
  }
  // DEFAULT true yazılırsa kullanıcı kararı SESSİZCE tersine döner.
  assert.doesNotMatch(MIG_38, /(sesli|goruntulu)_arama_acik BOOLEAN NOT NULL DEFAULT true/);
});

test('md.38 /arama/baslat tercihi AYNI sorguda okuyor (ek tur yok)', () => {
  const blok = SERVER.slice(SERVER.indexOf("app.post('/arama/baslat'"),
    SERVER.indexOf("app.get('/arama/durum/:aramaId'"));
  assert.ok(/hedefBul[\s\S]{0,600}sesli_arama_acik[\s\S]{0,80}goruntulu_arama_acik/.test(blok),
    'hedefBul sorgusu tercih sütunlarını seçmiyor -> varsayılan-ret herkesi keser');
  assert.match(blok, /kabulSesli:\s*rows\[0\]\.sesli_arama_acik === true/);
  assert.match(blok, /kabulGoruntulu:\s*rows\[0\]\.goruntulu_arama_acik === true/);
});

test('md.38 tercih okuma/yazma ucu: /gizlilik-tercihleri iki alanı da tanıyor', () => {
  const blok = SERVER.slice(SERVER.indexOf('const GIZLILIK_ALANLARI'),
    SERVER.indexOf("app.post('/gizle'"));
  assert.match(blok, /ARAMA_TERCIH_ALANLARI = \['sesli_arama_acik', 'goruntulu_arama_acik'\]/);
  assert.match(blok, /TERCIH_ALANLARI = \[\.\.\.GIZLILIK_ALANLARI, \.\.\.ARAMA_TERCIH_ALANLARI\]/);
  // GET'in SELECT'i, POST'un döngüsü ve UPDATE'in RETURNING'i ÜÇÜ DE geniş
  // listeyi kullanmalı; biri dar listede (`GIZLILIK_ALANLARI`) kalırsa tercih
  // ya okunamaz ya yazılamaz ve arıza SESSİZDİR — anahtar açık görünür, sunucu
  // kapalı bilir.
  assert.equal((blok.match(/TERCIH_ALANLARI\.join\(', '\)/g) || []).length, 2,
    'SELECT ve RETURNING geniş listeyi kullanmıyor');
  assert.ok(!/GIZLILIK_ALANLARI\.join/.test(blok),
    'sorgulardan biri dar listede kalmış: yeni tercih okunmaz/yazılmaz');
  // Sürüm 4: POST döngüsü artık sabit listeyi değil, HESAP TÜRÜNE göre
  // hesaplanan listeyi geziyor (`yazilabilirTercihler`). Döngü yine geniş
  // listeye dayanmalı — misafir olmayan kullanıcıda TERCIH_ALANLARI dönüyor.
  assert.match(blok, /for \(const a of izinli\)/);
  assert.match(blok, /const izinli = yazilabilirTercihler\(req\.misafir === true\)/);
  assert.match(blok, /misafirMi\s*\?\s*GIZLILIK_ALANLARI\s*:\s*TERCIH_ALANLARI/,
    'misafir dar listeye, kayıtlı kullanıcı geniş listeye düşmeli');
});

// --- sürüm 4: misafir hesaplar arama tercihlerini AÇAMAZ ------------------
// Kullanıcı kararı (10 Ağu): "misafir hesaplar aranamasın ve bu ayarları
// açamasınlar, sebebini de onlara söyle."
//
// Canlıda `misafir_9427a460` hesabında İKİSİ DE `t` idi — uç misafiri hiç
// süzmüyordu. Zorlama `/arama/baslat`ta olsa bile açık kalan bayrak yalan
// söyler: kullanıcı "açtım" sanır, arama yine olmaz.
test('sürüm 4 misafir /gizlilik-tercihleri: arama alanları REDDEDİLİYOR, ötekiler değil', () => {
  const blok = SERVER.slice(SERVER.indexOf('function yazilabilirTercihler'),
    SERVER.indexOf("app.post('/gizle'"));
  // Misafire verilen liste ARAMA alanlarını içermiyor.
  assert.ok(/misafirMi\s*\?\s*GIZLILIK_ALANLARI/.test(blok));
  // ...ama ÖTEKİ gizlilik tercihleri (izlenenler_gizli vb.) etkilenmiyor:
  // misafire dönen liste tam olarak GIZLILIK_ALANLARI, boş liste değil.
  assert.ok(!/misafirMi\s*\?\s*\[\]/.test(blok),
    'misafirin TÜM gizlilik tercihleri kapatılmış — istenen bu değil');
  // SESSİZ yok sayma YASAK: sebebi söyleyen 403 dönmeli.
  assert.match(blok, /kod: 'MISAFIR_ARAMA_YOK'/);
  assert.match(blok, /res\.status\(403\)/);
});

test('sürüm 4 misafir bayrağı JWT\'de DEĞİL (90 günlük token bayat kalırdı)', () => {
  const jwtBlok = SERVER.slice(SERVER.indexOf('return jwt.sign('),
    SERVER.indexOf('const sifreSurumOnbellek'));
  assert.ok(!/misafir/.test(jwtBlok),
    'misafir bayrağı JWT yüküne konmuş: hesabını bağlayan kullanıcı 90 gün misafir sayılır');
  // Canlı kaynak: her istekte okunan `kullaniciDurumu` önbelleği (30 sn TTL).
  const durumBlok = SERVER.slice(SERVER.indexOf('async function kullaniciDurumu'),
    SERVER.indexOf('async function sifreSurumuGecerli'));
  assert.match(durumBlok, /yasak_sebep, misafir/);
  assert.match(durumBlok, /misafir: rows\[0\]\.misafir === true/);
  // `/auth/bagla` önbelleği DÜŞÜRMELİ, yoksa yeni bağlanan hesap 30 sn boyunca
  // "misafir hesaplar arama yapamaz" yer.
  const baglaBlok = SERVER.slice(SERVER.indexOf("app.post('/auth/bagla'"),
    SERVER.indexOf("app.post('/auth/giris'"));
  assert.match(baglaBlok, /sifreSurumOnbellekSil\(req\.kullanici\.id\)/);
});

test('md.38 istemci kendi tercihini buz-sunuculari ile alıyor (düğmeyi pasif çizmek için)', () => {
  const blok = SERVER.slice(SERVER.indexOf("app.get('/arama/buz-sunuculari'"),
    SERVER.indexOf("app.post('/arama/baslat'"));
  // Sürüm 4: misafirde İKİSİ DE zorla false. Migrasyon veriyi temizliyor ama
  // bu satır ondan bağımsız garanti — bayat bir bayrak düğmeyi aktif çizerse
  // kullanıcı kesin başarısız olacak bir eyleme yönlendirilir.
  assert.match(blok, /kendi_sesli_acik:\s*!req\.misafir && rows\[0\]\?\.sesli_arama_acik === true/);
  assert.match(blok, /kendi_goruntulu_acik:\s*!req\.misafir && rows\[0\]\?\.goruntulu_arama_acik === true/);
  // İstemci kendi anahtarını KİLİTLİ çizip sebebini yazabilsin diye.
  assert.match(blok, /misafir: req\.misafir === true/);
  // Sunucu geneli bayraklar AYRI kalmalı — istemci ikisini karıştırırsa
  // kullanıcıya yanlış sebep gösterir.
  assert.match(blok, /arama_acik: aramaAcik/);
  assert.match(blok, /goruntulu_acik: goruntuluAcik/);
});

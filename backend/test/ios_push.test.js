// iOS PUSH — PLATFORMA GÖRE PAKET (13 Eyl 2026)
//
// Kullanıcı birebir: *"apple'de bildirimler gitmiyor mesela apple kullanan
// birisini takip edince takip ettiğimin bildirimi gitmiyor ama android'de
// gidiyor"*.
//
// ÖLÇÜM: `SELECT platform, count(*) FROM cihaz_tokenlari` → **714 android,
// 0 ios**. Yani iOS cihazlar jeton kaydetmiyordu (istemci tarafı, push.dart)
// ve kaydetseler bile iki tür bildirim iOS'ta GÖRÜNMEZDİ:
//
//   'mesaj' ve 'arama' paketleri BİLEREK veri-mesajıdır (Android'de avatarlı
//   MessagingStyle + Cevapla/Reddet + tam ekran arama kurulabilsin diye).
//   iOS `notification` alanı olmayan bir push'u KULLANICIYA GÖSTERMEZ.
//
// Bu dosya, `pushBildirim`i sahte `admin`/`havuz` ile GERÇEKTEN çalıştırıp
// şunu kilitler: aynı bildirim için Android'e veri-mesajı, iOS'a GÖRÜNÜR
// bildirim gider; Android'in özel davranışı BOZULMAZ.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

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

/** `async function <ad>` bildiriminin TAM metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^(async function|function|const) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} yok`);
  if (m[1] === 'const') {
    let derinlik = 0;
    for (let i = m.index; i < KAYNAK.length; i++) {
      const c = KAYNAK[i];
      if ('{(['.includes(c)) derinlik++;
      else if ('})]'.includes(c)) derinlik--;
      else if (c === ';' && derinlik === 0) return KAYNAK.slice(m.index, i + 1);
    }
    assert.fail(`${ad} bitmedi`);
  }
  return blokAl(KAYNAK, m.index, '{', '}');
}

/**
 * `pushBildirim`i sahte bağımlılıklarla kurar.
 * @returns {{cagir: Function, gonderilenler: Array, silinenler: Array}}
 */
function pushKur({ tokenSatirlari, basarisiz = new Set() }) {
  const gonderilenler = [];
  const silinenler = [];
  const havuz = {
    async query(sql, p) {
      // DELETE ÖNCE bakılır: silme sorgusu da "FROM cihaz_tokenlari" içerir,
      // sıra ters olsa silme jeton listesi sanılır (bu tuzağa düşüldü).
      if (/^\s*DELETE/.test(sql)) { silinenler.push(...p[0]); return { rows: [] }; }
      if (/FROM cihaz_tokenlari/.test(sql)) return { rows: tokenSatirlari };
      if (/FROM kullanicilar/.test(sql)) return { rows: [{ kullanici_adi: 'ayse', avatar: '/a.png' }] };
      return { rows: [] };
    },
  };
  const admin = {
    messaging: () => ({
      async sendEachForMulticast(paket) {
        gonderilenler.push(paket);
        return {
          responses: paket.tokens.map((t) => (basarisiz.has(t)
            ? { success: false, error: { code: 'messaging/not-registered' } }
            : { success: true })),
        };
      },
    }),
  };
  // eslint-disable-next-line no-new-func
  const yap = new Function(
    'fcmHazir', 'havuz', 'admin', 'PUSH_SABLON', 'sbEtiketi', 'CALMA_MS',
    `${bildirimCek('pushBildirim')}\nreturn pushBildirim;`,
  );
  const cagir = yap(
    true, havuz, admin,
    { tr: { takip: '{ad} seni takip etmeye başladı', mesaj: '{ad} sana mesaj gönderdi', arama: '{ad} seni arıyor' } },
    (dil, s, b) => `S${s}B${b}`,
    45000,
  );
  return { cagir, gonderilenler, silinenler };
}

const ANDROID = { token: 'a1', dil: 'tr', platform: 'android' };
const IOS = { token: 'i1', dil: 'tr', platform: 'ios' };

test('TAKİP — iOS cihaza GÖRÜNÜR bildirim gider (kullanıcının bildirdiği hata)', async () => {
  const { cagir, gonderilenler } = pushKur({ tokenSatirlari: [IOS] });
  await cagir(9, 'takip', 3);
  assert.equal(gonderilenler.length, 1);
  const paket = gonderilenler[0];
  assert.deepEqual(paket.tokens, ['i1']);
  assert.ok(paket.notification, 'iOS paketinde notification YOK → bildirim görünmez');
  assert.match(paket.notification.body, /takip etmeye başladı/);
  assert.equal(paket.apns.payload.aps.sound, 'default');
  // Derin bağlantı verisi de gitmeli (dokununca profile).
  assert.equal(paket.data.tur, 'takip');
  assert.equal(paket.data.ad, 'ayse');
});

test('MESAJ — Android VERİ-MESAJI kalır, iOS GÖRÜNÜR bildirim alır', async () => {
  const { cagir, gonderilenler } = pushKur({ tokenSatirlari: [ANDROID, IOS] });
  await cagir(9, 'mesaj', 3, { metin: 'bu akşam izliyoruz' });
  assert.equal(gonderilenler.length, 2, 'iki platform = iki ayrı gönderim');
  const android = gonderilenler.find((p) => p.tokens.includes('a1'));
  const ios = gonderilenler.find((p) => p.tokens.includes('i1'));
  // Android'in avatarlı MessagingStyle'ı veri-mesajına bağlı: BOZULMAMALI.
  assert.equal(android.notification, undefined);
  assert.equal(android.data.metin, 'bu akşam izliyoruz');
  // iOS'ta başlık GÖNDEREN, gövde MESAJIN KENDİSİ.
  assert.equal(ios.notification.title, '@ayse');
  assert.equal(ios.notification.body, 'bu akşam izliyoruz');
  assert.equal(ios.data.tur, 'mesaj');
});

test('ARAMA — iOS bildirimi çalma süresiyle ÖLÜR (apns-expiration)', async () => {
  const { cagir, gonderilenler } = pushKur({ tokenSatirlari: [IOS] });
  await cagir(9, 'arama', 3, { arama_id: 'x', arama_turu: 'ses' });
  const ios = gonderilenler[0];
  assert.equal(ios.notification.title, '@ayse');
  const sonaErme = Number(ios.apns.headers['apns-expiration']);
  const simdi = Math.floor(Date.now() / 1000);
  assert.ok(sonaErme > simdi && sonaErme <= simdi + 60,
    `apns-expiration çalma süresine yakın olmalı, gelen: ${sonaErme - simdi} sn`);
});

test('GEÇERSİZ JETON doğru listeden silinir (iOS/Android karışmaz)', async () => {
  const { cagir, silinenler } = pushKur({
    tokenSatirlari: [ANDROID, IOS],
    basarisiz: new Set(['i1']),
  });
  await cagir(9, 'takip', 3);
  assert.deepEqual(silinenler, ['i1']);
});

test('İSTEMCİ: iOS jetonu APNS jetonu BEKLENEREK alınır', () => {
  // 0 ios jetonunun ikinci yarısı istemcideydi: `getToken()` APNS jetonundan
  // önce çağrılınca `apns-token-not-set` fırlatıyor ve hata yutuluyordu.
  const PUSH = fs.readFileSync(
    path.join(path.dirname(KOK), 'app', 'lib', 'push.dart'), 'utf8');
  const i = PUSH.indexOf('Future<String?> _tokenAl(');
  assert.ok(i > 0, '_tokenAl yardımcısı yok');
  const govde = PUSH.slice(i, i + 900);
  assert.match(govde, /Platform\.isIOS/);
  assert.ok(govde.indexOf('getAPNSToken') < govde.indexOf('return mesajlasma.getToken()'),
    'APNS jetonu beklenmeden getToken çağrılıyor');
  // Sessiz yutma bitti: hata sunucuya bildiriliyor.
  assert.match(PUSH, /Api\.hataBildir\(hata, yigin, yol: 'push\/baslat'\)/);
});

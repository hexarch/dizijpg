// GERİ BİLDİRİM YANITI — uygulama içi bildirim (28 Ağu 2026).
//
// KORUDUĞU KARAR: admin panelinden yazılan yanıt artık YALNIZ e-postayla
// gitmiyor; `bildirimler` tablosuna da satır düşüyor ve kullanıcı yanıtı
// uygulamada okuyabiliyor.
//
// NEDEN GEREKTİ (ölçüm, 28 Ağu): mail hattı kusursuz değil — `mailler`
// tablosunda `sifirlama` türünde 3 gönderildi / 2 HATA var ve bugüne kadar
// `geri_bildirim_yanit` türünde HİÇ kayıt yok (özellik hiç kullanılmamış).
// `noreply@` + yeni alan adı spam'e de düşebiliyor. Yani bize geri bildirim
// yazacak kadar ilgilenen kullanıcıya verdiğimiz cevabın ulaşması garanti
// değildi.
//
// MAİL KALDIRILMADI: iki kanal BİRLİKTE çalışır. Aşağıdaki testlerden biri
// tam da bunu kilitliyor — "uygulama içi bildirim ekledik" diye maili
// düşürmek sessiz bir gerileme olurdu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-28.sql'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

/** `server.js`ten bir bildirimin tam metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^(?:async )?(const|function) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} yok`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if ('{(['.includes(c)) { derinlik++; girdi = true; }
    else if (')]}'.includes(c)) {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return KAYNAK.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return KAYNAK.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

test('migrasyon: yeni tür EKLENİR, mevcut sekizi DÜŞMEZ', () => {
  // CHECK'i yeniden yazıyoruz; bir türü unutmak canlıda o türün INSERT'ünü
  // düşürürdü (bildirim sessizce kaybolur, kimse fark etmez).
  for (const tur of ['yanit', 'begeni', 'takip', 'mesaj', 'etiket',
    'kacirilan_arama', 'bolum', 'kisi', 'geri_bildirim']) {
    assert.match(MIGRASYON, new RegExp(`'${tur}'`), `CHECK'ten düşen tür: ${tur}`);
  }
  assert.match(MIGRASYON, /ADD COLUMN IF NOT EXISTS geri_bildirim_id INT/);
  assert.match(MIGRASYON, /REFERENCES geri_bildirimler\(id\) ON DELETE CASCADE/,
    'geri bildirim silinince bildirim de gitmeli (ölü satır kalmasın)');
  // Aynı geri bildirime ikinci yanıt ikinci bildirim doğurmasın.
  assert.match(MIGRASYON, /CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_geri_bildirim_tekil/);
  assert.match(MIGRASYON, /WHERE tur = 'geri_bildirim'/);
});

test('sema.sql migrasyonla AYNI şeyi söylüyor', () => {
  // Yeni veritabanı sema.sql'den kuruluyor; ayrışırsa yeni kurulumda tür
  // CHECK'e takılır ve bildirim HİÇ yazılamaz.
  assert.match(SEMA, /'geri_bildirim'/);
  assert.match(SEMA, /geri_bildirim_id INT/);
  assert.match(SEMA, /bildirimler_geri_bildirim_tekil/);
});

test('yazıcı: push YALNIZ satır gerçekten yazıldıysa gider', () => {
  const f = bildirimCek('geriBildirimYanitBildirimi');
  // ON CONFLICT çıkarımı kısmi indekse dayanır; WHERE indeksin yüklemiyle
  // BİREBİR aynı olmalı, yoksa PostgreSQL 42P10 verir.
  assert.match(f, /ON CONFLICT \(kullanici_id, geri_bildirim_id\) WHERE tur='geri_bildirim'/);
  assert.match(f, /DO NOTHING/);
  // `if (!y.rowCount) return false` push'tan ÖNCE olmalı: aynı geri bildirime
  // ikinci kez yanıt yazılırsa kullanıcıya ikinci push gitmesin.
  const durdur = f.indexOf('if (!y.rowCount)');
  const push = f.indexOf('pushBildirim(');
  assert.ok(durdur > 0 && push > durdur,
    'push, satır yazılmadığında da gidiyor (yinelenen bildirim)');
});

test('yazıcı TERCİH KAPISI kullanmıyor (bilinçli)', () => {
  // Bu, kullanıcının BİZE yazdığı mesaja verilen doğrudan cevaptır;
  // "bildirimleri kapat" tercihleri BAŞKALARININ etkileşimleri içindir.
  const f = bildirimCek('geriBildirimYanitBildirimi');
  assert.doesNotMatch(f, /BILDIRIM_TERCIH_KOLON|bildir_/,
    'kendi sorusunun cevabı tercihle susturulmamalı');
});

test('uç: bildirim UPDATE\'ten SONRA yazılır ve MAİL DURUYOR', () => {
  const i = KAYNAK.indexOf("app.post('/admin/geri-bildirim-yanit'");
  assert.ok(i > 0);
  const blok = KAYNAK.slice(i, i + 3000);
  // Mail kanalı KALDIRILMADI — iki kanal birlikte.
  assert.match(blok, /mailGonder\(/, 'e-posta kanalı düşmüş');
  assert.match(blok, /tur: 'geri_bildirim_yanit'/);
  // SIRA: yanıt önce yazılmalı, çünkü istemci bildirime dokununca
  // `yanit_metni`ni okuyacak.
  const guncelle = blok.indexOf('UPDATE geri_bildirimler SET yanit_metni');
  const bildir = blok.indexOf('geriBildirimYanitBildirimi(');
  assert.ok(guncelle > 0 && bildir > guncelle,
    'bildirim, yanıt kaydedilmeden yazılıyor — dokununca boş görünür');
});

test('/bildirimler ucu yanıtı ve SORUYU birlikte döndürüyor', () => {
  const i = KAYNAK.indexOf("app.get('/bildirimler'");
  const blok = KAYNAK.slice(i, i + 2500);
  assert.match(blok, /LEFT JOIN geri_bildirimler g ON g\.id = b\.geri_bildirim_id/);
  assert.match(blok, /g\.yanit_metni AS geri_bildirim_yanit/);
  // Kullanıcının kendi yazdığı da gelmeli: yanıt aylar sonra gelebiliyor,
  // "neye cevap bu?" sorusu kalmasın (mail gövdesindeki alıntıyla aynı fikir).
  assert.match(blok, /g\.metin\s+AS geri_bildirim_metin/);
  // LEFT JOIN şart: öteki türlerde `geri_bildirim_id` NULL, INNER JOIN
  // bildirim listesini KOMPLE boşaltırdı.
  assert.doesNotMatch(blok, /INNER JOIN geri_bildirimler/);
});

test('push şablonu TÜM dillerde var ve {ad} yer tutucusu YOK', () => {
  const i = KAYNAK.indexOf('const PUSH_SABLON = {');
  const blok = KAYNAK.slice(i, KAYNAK.indexOf('\n};', i));
  const diller = blok.match(/^ {2}([a-z]{2}): \{/gm) || [];
  assert.ok(diller.length >= 16, `beklenenden az dil: ${diller.length}`);
  const anahtarlar = blok.match(/geri_bildirim: '/g) || [];
  assert.equal(anahtarlar.length, diller.length,
    'bazı dillerde geri_bildirim şablonu yok — o dilde push HİÇ gitmez');
  // Aktörsüz tür: şablonda {ad} olsaydı ekranda ham yer tutucu görünürdü.
  const satirlar = blok.match(/geri_bildirim: '[^']*'/g) || [];
  for (const s of satirlar) {
    assert.doesNotMatch(s, /\{ad\}/, `aktörsüz şablonda {ad} var: ${s}`);
  }
});

test('push gövdesi aktörsüz dala giriyor, veriye id koyuyor', () => {
  const f = bildirimCek('pushBildirim');
  assert.match(f, /tur === 'geri_bildirim'\s*\n?\s*\? \(sablon\.geri_bildirim \|\| ''\)/,
    'geri bildirim şablonu {ad} ile değiştirilen genel dala düşüyor');
  assert.match(f, /veri\.geri_bildirim_id = String\(/,
    'istemci push\'tan hangi geri bildirim olduğunu çıkaramaz');
  // Metin push'ta GİTMEZ: FCM data 4 KB sınırlı ve yanıt panelden
  // düzeltilebiliyor — tek doğru kaynak veritabanı.
  assert.doesNotMatch(f, /veri\.yanit_metni|veri\.geri_bildirim_metin/);
});

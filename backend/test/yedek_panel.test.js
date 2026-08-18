// YEDEK PANELİ — süzgeç körlüğü, şifreli elle yedek, indirme ucu.
//
// ASIL BULGU (19 Ağu 2026 kod taraması): `yedekDurumu` süzgeci
// `/\.(sql|dump)\.gz$/` idi. 8 Ağu'da yedekler gpg ile şifrelenip adları
// `dizijpg-20260817-0400.sql.gz.gpg` olunca HİÇBİRİ eşleşmedi ve panel
// 25 günlük yedek diskte dururken "Yedek bulunamadı" + "Son yedek: YOK"
// gösterdi. En kötüsü: GERÇEK bir yedek arızasında panel bugünküyle AYNI
// görüneceği için fark edilmezdi -- yedeğin tek gözlem yüzeyi kördü.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { yedekDurumu } from '../depolama.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const COMPOSE = fs.readFileSync(path.join(KOK, 'docker-compose.yml'), 'utf8');
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');

/** Gerçek dosyalarla geçici bir yedek dizini kurar. */
function dizinKur(adlar) {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'yedek-'));
  adlar.forEach((ad, i) => {
    fs.writeFileSync(path.join(d, ad), 'x'.repeat(100 + i));
    // mtime'ı sıraya koy: sonuncu EN YENİ olsun.
    const t = new Date(2026, 0, 1 + i);
    fs.utimesSync(path.join(d, ad), t, t);
  });
  return d;
}

test('ŞİFRELİ yedekler sayılıyor (.gpg) — panel körlüğü kapandı', () => {
  const d = dizinKur([
    'dizijpg-20260816-0400.sql.gz.gpg',
    'dizijpg-20260817-0400.sql.gz.gpg',
  ]);
  const y = yedekDurumu(d);
  assert.equal(y.adet, 2, 'şifreli yedekler hâlâ sayılmıyor');
  assert.ok(y.son, '"son yedek" boş — panel "YOK" gösterir');
  assert.equal(y.son.ad, 'dizijpg-20260817-0400.sql.gz.gpg', 'en yeni seçilmedi');
  fs.rmSync(d, { recursive: true, force: true });
});

test('eski (şifresiz) biçim de sayılmaya devam ediyor', () => {
  // Geriye uyumluluk: arşivde .sql.gz dosyalar da var; süzgeci daraltmak
  // onları görünmez yapardı.
  const d = dizinKur(['eski.sql.gz', 'rapor.dump.gz', 'tam.sql.gpg']);
  assert.equal(yedekDurumu(d).adet, 3);
  fs.rmSync(d, { recursive: true, force: true });
});

test('yedek OLMAYAN dosyalar sayılmıyor', () => {
  const d = dizinKur(['yedek.log', 'not.txt', 'intl-kullanicilar.txt']);
  const y = yedekDurumu(d);
  assert.equal(y.adet, 0);
  assert.equal(y.son, null);
  fs.rmSync(d, { recursive: true, force: true });
});

test('elle yedek ŞİFRELİ üretiliyor, anahtar yoksa AÇIKÇA hata', () => {
  const g = SERVER.slice(SERVER.indexOf("app.post('/admin/yedek-al'"),
    SERVER.indexOf("app.get('/admin/yedek-indir'"));
  assert.match(g, /--symmetric --cipher-algo AES256/, 'gpg şifreleme yok');
  assert.match(g, /passphrase-file/, 'anahtar dosyası kullanılmıyor');
  assert.match(g, /\.sql\.gz\.gpg/, 'çıktı adı .gpg değil');
  // Anahtar yoksa SESSİZCE şifresiz üretmek, tam da istenmeyeni yapıp
  // "tamam" demek olurdu.
  assert.match(g, /if \(!fs\.existsSync\(YEDEK_ANAHTAR\)\)/,
    'anahtar yokluğunda açık hata verilmiyor');
  assert.ok(!/\| gzip > /.test(g), 'şifresiz gzip yolu hâlâ duruyor');
});

test('indirme ucu: dosya adı İSTEMCİDEN alınmıyor (yol geçişi imkânsız)', () => {
  const g = SERVER.slice(SERVER.indexOf("app.get('/admin/yedek-indir'"),
    SERVER.indexOf("app.get('/admin/yedek-indir'") + 1400);
  assert.match(g, /adminKisit/, 'indirme ucu admin kısıtsız');
  assert.match(g, /sonYedek\(\)/, 'sunucu en yeniyi kendi seçmiyor');
  // Ad parametresi kabul edilseydi `../../etc/passwd` savunması yazmak
  // gerekirdi; kabul etmeyerek o sınıf tamamen siliniyor.
  assert.ok(!/req\.(params|query|body)/.test(g),
    'indirme ucu istemciden ad/parametre okuyor — yol geçişi yüzeyi açılmış');
  assert.match(g, /private, no-store/, 'yedek önbelleğe girebilir');
  assert.match(g, /attachment; filename=/, 'tarayıcıda açılır, inmez');
});

test('BAĞLANTI: gnupg imajda, anahtar compose ile bağlı', () => {
  assert.match(DOCKERFILE, /apk add --no-cache .*gnupg/,
    'gnupg imajda yok — elle yedek şifrelenemez');
  assert.match(COMPOSE, /yedek-anahtar\.key:\/yedek-anahtar\.key:ro/,
    'anahtar konteynere bağlanmamış (salt-okunur olmalı)');
});

test('PANEL: indirme düğmesi + inecek yedeğin TARİHİ tooltipte', () => {
  assert.match(ADMIN, /id="dep-yedek-indir"/, 'indirme düğmesi yok');
  assert.match(ADMIN, /onclick="yedekIndir\(\)"/);
  // Tooltip tarihi göstermezse "hangisini indiriyorum" sorusu cevapsız kalır.
  assert.match(ADMIN, /indirBtn\.title=`\$\{t\.toLocaleString\('tr'\)\}/,
    'tooltip inecek yedeğin tarihini yazmıyor');
  // Yedek yokken düğme kapalı olmalı: tıklayıp 404 almak kötü geri bildirim.
  assert.match(ADMIN, /indirBtn\.disabled=true/, 'yedek yokken düğme kapanmıyor');
});

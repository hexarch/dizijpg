// "dizi.jpg aile üyesi" rozeti — sunucu sözleşmesi testleri
//
// Rozeti istemci `testci` alanına bakarak çiziyor. O alan profil dönen
// uçlardan DÜŞERSE rozet sessizce kaybolur: hata da vermez, log da atmaz,
// yalnız 8 hesabın profilinden bir satır silinir. Bu yüzden alanın SELECT
// listesinde durduğu kaynak üzerinden kilitlenir.
//
// İki uç birden gerekiyor:
//   /profil/:kullaniciAdi → başkasının (ve giriş yapmamış ziyaretçinin) gördüğü
//   /profilim             → kendi profil ekranının başlığı bunu okur
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

/** Bir uç tanımından itibaren gelen ilk SQL metnini döndürür. */
function ucSorgusu(imza) {
  const bas = SERVER.indexOf(imza);
  assert.notEqual(bas, -1, `${imza} bulunamadı`);
  const govde = SERVER.slice(bas, bas + 1500);
  const eslesme = govde.match(/`SELECT[\s\S]*?`/);
  assert.ok(eslesme, `${imza} içinde SELECT bulunamadı`);
  return eslesme[0];
}

test('GET /profil/:kullaniciAdi yanıtı testci alanını taşır', () => {
  const sql = ucSorgusu("app.get('/profil/:kullaniciAdi'");
  assert.match(sql, /\btestci\b/, 'testci SELECT listesinde yok');
  assert.match(sql, /FROM kullanicilar WHERE kullanici_adi=\$1/);
  // Yanıt gövdesi satırı olduğu gibi yayıyor (...k.rows[0]); alan SELECT'te
  // olduğu sürece istemciye ulaşır.
  const bas = SERVER.indexOf("app.get('/profil/:kullaniciAdi'");
  const govde = SERVER.slice(bas, SERVER.indexOf('app.delete(', bas));
  assert.match(govde, /\.\.\.k\.rows\[0\]/);
});

test('GET /profilim yanıtı testci alanını taşır', () => {
  const sql = ucSorgusu("app.get('/profilim'");
  assert.match(sql, /\btestci\b/, 'testci SELECT listesinde yok');
});

test('profil uçları e-posta/şifre sızdırmıyor (rozet eklenirken de)', () => {
  // Rozet için SELECT listesine dokunuldu; açık profil ucu hâlâ e-posta ya da
  // şifre özetini dışarı vermemeli.
  const sql = ucSorgusu("app.get('/profil/:kullaniciAdi'");
  assert.doesNotMatch(sql, /\bemail\b/);
  assert.doesNotMatch(sql, /sifre_hash/);
});

test('sema.sql kullanicilar.testci sütununu tanımlıyor', () => {
  // Migrasyon uygulanmış bir veritabanı ile sıfırdan kurulan bir veritabanı
  // aynı şemaya sahip olmalı; sema.sql güncellenmezse yeni kurulumda uç
  // "column testci does not exist" ile 500 döner.
  assert.match(
    SEMA,
    /ALTER TABLE kullanicilar\s*\n?\s*ADD COLUMN IF NOT EXISTS testci BOOLEAN NOT NULL DEFAULT false/,
  );
});

test('migrasyon dosyası var ve geri dönüşü güvenli (IF NOT EXISTS)', () => {
  const yol = path.join(KOK, 'migrasyon-2026-08-05.sql');
  assert.ok(fs.existsSync(yol), 'migrasyon-2026-08-05.sql yok');
  const m = fs.readFileSync(yol, 'utf8');
  assert.match(m, /ADD COLUMN IF NOT EXISTS testci BOOLEAN NOT NULL DEFAULT false/);
  // Varsayılan false: migrasyon tek bir kullanıcıya rozet TAKMAZ, yalnız alan
  // açar. İşaretleme ayrı bir araçla, e-posta listesinden yapılır.
  assert.doesNotMatch(m, /UPDATE\s+kullanicilar/i);
});

test('e-posta listesi kaynak koda GÖMÜLMEDİ (kişisel veri)', () => {
  // Kapalı test adresleri kişisel veridir ve depoya giremez. Araç listeyi
  // dosyadan okur; server.js ve araç kaynağında adres olmamalı.
  const arac = fs.readFileSync(
    path.join(KOK, 'araclar', 'testci_isaretle.js'), 'utf8',
  );
  const eposta = /[A-Za-z0-9._%+-]+@(gmail|hotmail|outlook|yahoo|icloud)\.com/i;
  assert.doesNotMatch(arac, eposta, 'araçta gerçek e-posta adresi var');
  assert.doesNotMatch(SERVER, eposta, 'server.js içinde e-posta adresi var');
  // Araç listeyi gerçekten dosyadan okuyor.
  assert.match(arac, /--liste=/);
  assert.match(arac, /readFileSync\(yol, 'utf8'\)/);
  // Varsayılan kuru çalışma: --uygula verilmedikçe yazma yok.
  assert.match(arac, /const UYGULA = !!ARG\.uygula;/);
  assert.match(arac, /KURU ÇALIŞMA/);
});

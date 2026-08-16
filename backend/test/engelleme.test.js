// KULLANICI ENGELLEME (istek md. 19) — `node --test test/*.test.js`
//
// "Engellenen kişinin paylaşımları, yorumları, hiçbir şeyi görünmeyecek ve iki
//  taraf ASLA birbirine mesaj atamayacak."
//
// Bu testler İKİ KATMANI birden tutar:
//
//  1) DAVRANIŞ — `engelSuzgec()` KAYNAKTAN ÇEKİLİP GERÇEKTEN ÇALIŞTIRILIYOR.
//     Ürettiği SQL parçasının çift yönlü olduğu, iki dalı da içerdiği ve
//     oturumsuz okumada kısa devre yaptığı doğrulanıyor. (server.js içe
//     aktarılamıyor: modül yüklenir yüklenmez `app.listen` çağırıyor —
//     kisi_tepkisi/bolum_puani testleriyle aynı gerekçe.)
//
//  2) BAĞLANTI — süzgeç DOĞRU ise bile YANLIŞ YERE bağlanırsa (ya da bir uçta
//     hiç bağlanmazsa) davranış testi bunu görmez. Aşağıdaki "kapı listesi"
//     testleri her ucun gövdesini kaynaktan çıkarıp süzgecin/`engelliMi`nin
//     ORADA olduğunu denetler. Bir uç süzgeci kaybederse test kırmızıya döner
//     ve hangi uç olduğunu ADIYLA söyler.
//
// YENİ BİR LİSTE UCU EKLEYEN: kullanıcı üreten (kullanici_adi/avatar döndüren)
// her uç ya SUZULEN_UCLAR'a ya SUZULMEYENLER'e yazılmalı. İkincisi gerekçe
// ister — liste yalnız kayıt değil, KARARIN kendisidir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-13d.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın
// (geri alma bölümü bilerek DROP/CREATE örneği içerir).
const MIGRASYON_KOMUTLARI = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan kod çekme yardımcıları
// ---------------------------------------------------------------------------

/** `bas` indeksindeki ilk `{`/`(` çiftini dengeleyerek bloğu döndürür. */
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

/** Bir `function ad(...)` bildirimini kaynaktan çekip ÇALIŞTIRILABİLİR hâle getirir. */
function fonksiyonCek(ad) {
  const m = new RegExp(`^function ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  const govde = blokAl(KAYNAK, m.index, '{', '}');
  // eslint-disable-next-line no-new-func
  return new Function(`${govde}; return ${ad};`)();
}

/** `app.<metot>('<yol>'` ile başlayan uç kaydının TAM gövdesini döndürür. */
function ucGovdesi(metot, yol) {
  const ara = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot.toUpperCase()} ${yol}`);
  return blokAl(KAYNAK, bas + ara.length - 1, '(', ')');
}

const engelSuzgec = fonksiyonCek('engelSuzgec');

// ===========================================================================
// 1. SÜZGECİN KENDİSİ — çift yönlü, iki dallı, oturumsuzda kısa devreli
// ===========================================================================

test('engelSuzgec: İKİ YÖNÜ de kapsar (engelleyen VE engellenen dalı)', () => {
  const s = engelSuzgec('y.kullanici_id', '$1');
  // Yön 1: BEN engelledim -> onun satırları düşer.
  assert.match(s, /SELECT engellenen_id FROM engellemeler WHERE engelleyen_id=\$1/);
  // Yön 2: O beni engelledi -> onun satırları YİNE düşer. Bu dal olmasaydı
  // engellenen kişi engelleyeni okumaya devam ederdi ve engel tek taraflı,
  // yani fiilen etkisiz olurdu.
  assert.match(s, /SELECT engelleyen_id FROM engellemeler WHERE engellenen_id=\$1/);
  assert.match(s, /UNION/);
});

test('engelSuzgec: verilen sütunu ve yer tutucuyu AYNEN kullanır', () => {
  const s = engelSuzgec('k.id', '$3');
  assert.ok(s.includes('k.id NOT IN'), 'sütun yerine yazılmalı');
  assert.equal(s.includes('$1'), false, 'başka yer tutucu sızmamalı');
  assert.equal((s.match(/\$3/g) || []).length, 3, '$3 üç kez geçmeli (kısa devre + iki dal)');
});

test('engelSuzgec: oturumsuz okumada (ben=0) KISA DEVRE yapar', () => {
  // SEO/oturumsuz uçlarda benId 0'dır. Kısa devre olmasaydı sorgu her seferinde
  // boşuna iki indeks araması yapardı; sonuç aynı, plan pahalı olurdu.
  assert.match(engelSuzgec('k.id', '$2'), /\$2::int = 0 OR/);
});

test('engelSuzgec: NOT IN kullanır (IN değil) — süzgeç DIŞLAR, seçmez', () => {
  // Bir gün `NOT` düşerse süzgeç tam TERSİNE döner: kullanıcı YALNIZ
  // engellediklerini görür. Sessizce olacak bir felaket, o yüzden kilitli.
  assert.match(engelSuzgec('x', '$1'), /x NOT IN \(/);
});

// ===========================================================================
// 2. SÜZÜLEN UÇLARIN TAM LİSTESİ (md. 19'un "hiçbir şeyi görünmeyecek" kısmı)
// ===========================================================================
// Her satır: [açıklama, uç gövdesini veren fonksiyon]
const SUZULEN_UCLAR = [
  ['GET /yorum/:id — tek gönderi', () => ucGovdesi('get', '/yorum/:id')],
  ['GET /yorumlar/:id/begenenler — beğenenler listesi',
    () => ucGovdesi('get', '/yorumlar/:id/begenenler')],
  ['GET /yorumlar/:tur/:tmdbId — dizi/film/bölüm yorumları',
    () => ucGovdesi('get', '/yorumlar/:tur/:tmdbId')],
  ['GET /izleyenler/:tur/:tmdbId — izleyen kullanıcılar',
    () => ucGovdesi('get', '/izleyenler/:tur/:tmdbId')],
  ['GET /incelemeler/:tur/:tmdbId — puanlı incelemeler',
    () => ucGovdesi('get', '/incelemeler/:tur/:tmdbId')],
  ['GET /sohbetler — mesaj listesi + istekler',
    () => ucGovdesi('get', '/sohbetler')],
  ['GET /sohbetler/okunmamis — rozet sayacı',
    () => ucGovdesi('get', '/sohbetler/okunmamis')],
  ['GET /paylas-hedefler — gönderi paylaşma hedefleri',
    () => ucGovdesi('get', '/paylas-hedefler')],
  ['GET /kullanici-ara — kullanıcı arama',
    () => ucGovdesi('get', '/kullanici-ara')],
  ['GET /profil/:kullaniciAdi — profil (yanıtlanan gönderi bağlamı)',
    () => ucGovdesi('get', '/profil/:kullaniciAdi')],
  ['GET /arama/gecmis — sesli/görüntülü arama geçmişi',
    () => ucGovdesi('get', '/arama/gecmis')],
  ['GET /listeler/:id — herkese açık liste (doğrudan bağlantı)',
    () => ucGovdesi('get', '/listeler/:id')],
  ['GET /ceviri/:yorumId — gönderi METNİNİ döndürüyor',
    () => ucGovdesi('get', '/ceviri/:yorumId')],
];

for (const [ad, al] of SUZULEN_UCLAR) {
  test(`SÜZÜLÜYOR: ${ad}`, () => {
    assert.match(al(), /engelSuzgec\(/,
      `${ad} engelleme süzgecini KAYBETMİŞ`);
  });
}

test('SÜZÜLÜYOR: /akis ve /kesfet-akis (ortak AKIS_GOVDE parçası)', () => {
  // İki uç aynı SQL gövdesini paylaşıyor; süzgeç orada TEK yerde durur.
  const m = /^const AKIS_GOVDE = `/m.exec(KAYNAK);
  assert.ok(m, 'AKIS_GOVDE bulunamadı');
  const govde = KAYNAK.slice(m.index, KAYNAK.indexOf('`;', m.index));
  assert.match(govde, /engelSuzgec\('y\.kullanici_id'/);
  // Uçlar gerçekten bu parçayı kullanıyor mu? (/kesfet-akis skorlamayı
  // `kesfetAdaylari` üzerinden yapar; o da AKIS_GOVDE'yi kullanır.)
  assert.match(ucGovdesi('get', '/akis'), /AKIS_GOVDE/);
  assert.match(KAYNAK, /\$\{AKIS_GOVDE\}/);
});

test('SÜZÜLÜYOR: takipçi ve takip edilen listeleri', () => {
  // Ortak `takipListesi` yardımcısı üzerinden; ayrıca iki ucun da OTURUMU
  // OKUMASI şart (eskiden okumuyorlardı, dolayısıyla süzemezlerdi).
  const m = /async function takipListesi\b/.exec(KAYNAK);
  assert.ok(m, 'takipListesi bulunamadı');
  assert.match(blokAl(KAYNAK, m.index, '{', '}'), /engelSuzgec\('ku\.id'/);
  for (const yol of ['/takipciler/:kullaniciAdi', '/takipedilenler/:kullaniciAdi']) {
    assert.match(ucGovdesi('get', yol), /girisIsteğeBagli/,
      `${yol} oturumu okumazsa engellemeyi bilemez`);
  }
});

test('SÜZÜLÜYOR: /kullanici-ara ve /incelemeler oturumu OKUR', () => {
  // Süzgeç doğru yazılsa bile benId hep 0 gelirse kısa devre yüzünden HİÇBİR
  // ŞEY süzülmez — sessiz başarısızlık. Middleware'i de kilitliyoruz.
  assert.match(ucGovdesi('get', '/kullanici-ara'), /girisIsteğeBagli/);
  assert.match(ucGovdesi('get', '/incelemeler/:tur/:tmdbId'), /girisIsteğeBagli/);
});

test('/sohbetler: OKUNMAMIŞ ROZET SAYACI da süzülür', () => {
  // Sohbet listeden düşer ama rozet sayacı süzülmezse, kullanıcı asla
  // açamayacağı bir mesaj yüzünden sonsuza kadar "1" görür.
  const govde = ucGovdesi('get', '/sohbetler');
  assert.match(govde, /NOT okundu AND \$\{engelSuzgec\('gonderen_id', '\$1'\)\}/);
});

// ===========================================================================
// 3. SÜZÜLMEYENLER — bilinçli kararlar (gerekçesiz bırakılamaz)
// ===========================================================================

test('SÜZÜLMEZ: içeriğin KAMUSAL sayaçları (puan ortalaması/dağılımı, izleyen sayısı)', () => {
  // Karar: bunlar KİŞİYE değil İÇERİĞE ait istatistiklerdir. Kişiselleştirilseydi
  // aynı dizinin puanı her kullanıcıda başka çıkar; paylaşılan ekran görüntüsü,
  // SEO sayfası ve admin paneli birbirini tutmazdı.
  const govde = ucGovdesi('get', '/incelemeler/:tur/:tmdbId');
  // Ortalama sorgusu süzgeçsiz kalmalı (yalnız LİSTE süzülür).
  assert.match(govde, /round\(avg\(puan\)/);
  assert.equal((govde.match(/engelSuzgec\(/g) || []).length, 1,
    'yalnız inceleme LİSTESİ süzülmeli, ortalama/dağılım değil');
  // Gerekçe kodda yazılı kalmalı (uç kaydının HEMEN ÜSTÜNDEKİ blokta).
  assert.match(KAYNAK, /KAMUSAL istatistiğidir/);
});

test('SÜZÜLMEZ: /og/* SEO uçları — oturum YOK, kişiselleştirilemez', () => {
  // OG/sitemap yanıtları Cloudflare ve arama motorları tarafından PAYLAŞILAN
  // önbellekte tutulur; kullanıcıya göre değişen bir gövde oraya konamaz.
  // (Zaten oturum başlığı da göndermezler.)
  assert.equal(/app\.get\('\/og\/gonderi\/:id', girisZorunlu/.test(KAYNAK), false);
});

// ===========================================================================
// 4. MESAJLAŞMA — İKİ YÖNDE DE İMKÂNSIZ
// ===========================================================================

test('MESAJ GÖNDERME engelli çiftte 403 (çift yönlü kontrol)', () => {
  const govde = ucGovdesi('post', '/mesajlar');
  assert.match(govde, /await engelliMi\(req\.kullanici\.id, aliciId\)/);
  assert.match(govde, /403/);
});

test('MESAJ TEPKİSİ engelli çiftte 403; KALDIRMA serbest', () => {
  const govde = ucGovdesi('post', '/mesaj-tepki');
  // `emoji != null` koşulu: tepki BIRAKMA engelli, tepki KALDIRMA serbest.
  assert.match(govde, /emoji != null && await engelliMi\(/);
});

test('MESAJ GEÇMİŞİ engelli çiftte BOŞ döner (403 değil)', () => {
  // 403 yayındaki sohbet ekranında kırmızı hata çizerdi; boş liste "henüz
  // mesaj yok" durumuna düşer ve ekran sağlam kalır.
  const govde = ucGovdesi('get', '/mesajlar/:kullaniciAdi');
  assert.match(govde, /const engelVar = await engelliMi\(/);
  assert.match(govde, /mesajlar: \[\][\s\S]*engel: true/);
});

test('ARAMA (sesli/görüntülü) engelleme kapısı arama.js\'e VERİLİYOR', () => {
  // arama.js saf modül; engelleme bilgisini enjekte edilen `engelliMi` ile alır.
  assert.equal((KAYNAK.match(/engelliMi: \(a, b\) => engelliMi\(a, b\)/g) || []).length, 2,
    'hem baslat hem yanit kaynağına verilmeli');
});

// ===========================================================================
// 5. YAZMA KAPILARI — engel bildirimle DELİNMESİN
// ===========================================================================

test('TAKİP kurulamaz (kaldırma serbest)', () => {
  const govde = ucGovdesi('post', '/takip/:kullaniciAdi');
  // DELETE önce çalışır; kapı YALNIZ "yeni takip" dalında.
  assert.match(govde, /silindi\.rowCount === 0 && await engelliMi\(/);
});

test('BEĞENİ bırakılamaz (geri alma serbest), 404 ile — engel ele verilmez', () => {
  const govde = ucGovdesi('post', '/yorumlar/:id/begen');
  assert.match(govde, /await engelliMi\(req\.kullanici\.id, sahipId\)/);
  assert.match(govde, /404\)\.json\(\{ hata: 'Yorum bulunamadı' \}\)/);
});

test('YANIT yazılamaz — 404 (403 değil)', () => {
  const govde = ucGovdesi('post', '/yorumlar');
  assert.match(govde, /await engelliMi\(req\.kullanici\.id, u\.kullanici_id\)/);
  assert.match(govde, /404\)\.json\(\{ hata: 'Yanıtlanan yorum bulunamadı' \}\)/);
});

// ===========================================================================
// 6. ENGELLE / ENGELİ KALDIR UCU
// ===========================================================================

const ENGELLE = ucGovdesi('post', '/engelle/:kullaniciAdi');

test('KENDİNİ ENGELLEME 400 ile reddedilir', () => {
  assert.match(ENGELLE, /hedefId === req\.kullanici\.id[\s\S]{0,120}400/);
});

test('OLMAYAN KULLANICI 404', () => {
  assert.match(ENGELLE, /!hedef\.rows\.length[\s\S]{0,60}404/);
});

test('TOGGLE: varsa siler, yoksa ekler', () => {
  assert.match(ENGELLE, /DELETE FROM engellemeler WHERE engelleyen_id=\$1 AND engellenen_id=\$2/);
  assert.match(ENGELLE, /INSERT INTO engellemeler \(engelleyen_id, engellenen_id\)/);
  assert.match(ENGELLE, /engellendi: false/);
  assert.match(ENGELLE, /engellendi: true/);
});

test('ENGEL KURULUNCA KARŞILIKLI TAKİP KOPAR (iki yön birden)', () => {
  // Şart: sesli/görüntülü arama izni ve mesaj isteği atlaması KARŞILIKLI
  // TAKİBE bakıyor. Takip satırı kalsaydı engel o kapıları açık bırakırdı.
  assert.match(ENGELLE,
    /DELETE FROM takipler WHERE \(takip_eden_id=\$1 AND takip_edilen_id=\$2\)\s*\n?\s*OR \(takip_eden_id=\$2 AND takip_edilen_id=\$1\)/);
});

test('ENGEL KURULUNCA ÇİFTİN BİLDİRİMLERİ SİLİNİR (iki yön birden)', () => {
  // Engelden ÖNCE gelmiş "seni takip etti / gönderini beğendi" satırları zilde
  // kalırdı — "hiçbir şeyini görmeyeyim" isteğinin en görünür ihlali.
  assert.match(ENGELLE,
    /DELETE FROM bildirimler\s*\n?\s*WHERE \(kullanici_id=\$1 AND aktor_id=\$2\) OR \(kullanici_id=\$2 AND aktor_id=\$1\)/);
});

test('İKİ HIZLI DOKUNUŞ 500 vermez (ON CONFLICT) ve hız limiti var', () => {
  assert.match(ENGELLE, /ON CONFLICT DO NOTHING/);
  assert.match(ENGELLE, /engelLimiti/);
  assert.match(KAYNAK, /const engelLimiti = hizLimiti\(/);
});

test('ENGELLENENLER LİSTESİ: yalnız BENİM engellediklerim, en yeni önce', () => {
  const govde = ucGovdesi('get', '/engellenenler');
  assert.match(govde, /WHERE e\.engelleyen_id=\$1 ORDER BY e\.tarih DESC/);
  // Beni engelleyenler LİSTELENMEZ: kim engellediğini göstermek, engellemeyi
  // bir bildirime çevirir ve taciz senaryosunu tetikler.
  assert.equal(/engellenen_id=\$1/.test(govde), false);
  assert.match(govde, /kullanici_adi, k\.avatar/);
});

// ===========================================================================
// 7. PROFİL KARARI — 404 DEĞİL, BOŞ PROFİL; "seni engelledi" AÇIKLANMAZ
// ===========================================================================

const PROFIL = ucGovdesi('get', '/profil/:kullaniciAdi');

test('PROFİL: engelli çiftte içerik TAMAMEN düşer, 404 verilmez', () => {
  assert.match(PROFIL, /bool_or\(engelleyen_id=\$1\) AS ben_engelledim/);
  assert.match(PROFIL, /rozetler: \[\], listeler: \[\], incelemeler: \[\], yorumlar: \[\]/);
  assert.match(PROFIL, /bio: null, kapak: null, sosyal: null/);
  // 404 olsaydı engeli kaldırma düğmesine (bu ekranın menüsünde) ulaşılamazdı.
  assert.match(PROFIL, /engelledim: engel === true/);
});

test('PROFİL: `engel` bayrağı YALNIZ engelleyen tarafa gider', () => {
  // Karşı taraf beni engellediyse profil yine boş gelir ama bayrak GELMEZ:
  // sunucunun "seni engelledi" demesi, engellemeyi hedefe bildirmek olurdu.
  assert.match(PROFIL, /\.\.\.\(engel === true \? \{ engel: true \} : \{\}\)/);
});

// ===========================================================================
// 8. ŞEMA + MİGRASYON
// ===========================================================================

test('ŞEMA: engellemeler tablosu KENDİNİ ENGELLEMEYİ veritabanında da yasaklar', () => {
  assert.match(SEMA, /CHECK \(engelleyen_id <> engellenen_id\)/);
  assert.match(SEMA, /PRIMARY KEY \(engelleyen_id, engellenen_id\)/);
  // Kullanıcı silinince engelleme satırı da gitmeli (yetim satır kalmasın).
  assert.match(SEMA, /engelleyen_id INT REFERENCES kullanicilar\(id\) ON DELETE CASCADE/);
});

test('ŞEMA + MİGRASYON: ters yön indeksi KAPSAYAN hâle geldi', () => {
  // Süzgecin 2. dalı `SELECT engelleyen_id ... WHERE engellenen_id=$1`.
  // İkinci kolon anahtarda olmasaydı her eşleşmede tabloya (heap) gidilirdi.
  assert.match(SEMA, /engelleme_engellenen_kapsayan\s*\n?\s*ON engellemeler \(engellenen_id, engelleyen_id\)/);
  assert.match(MIGRASYON_KOMUTLARI,
    /CREATE INDEX IF NOT EXISTS engelleme_engellenen_kapsayan/);
  assert.match(MIGRASYON_KOMUTLARI, /DROP INDEX IF EXISTS engelleme_engellenen;/);
});

test('MİGRASYON: HİÇBİR SATIR yazmaz/siler/değiştirmez (yalnız indeks)', () => {
  for (const tehlike of [/\bINSERT\b/i, /\bUPDATE\b/i, /\bDELETE\b/i, /\bDROP TABLE\b/i,
    /\bALTER TABLE\b/i, /\bTRUNCATE\b/i]) {
    assert.equal(tehlike.test(MIGRASYON_KOMUTLARI), false,
      `migrasyon veri işlemi içeriyor: ${tehlike}`);
  }
});

test('MİGRASYON: idempotent (iki kez çalıştırılabilir)', () => {
  assert.match(MIGRASYON_KOMUTLARI, /CREATE INDEX IF NOT EXISTS/);
  assert.match(MIGRASYON_KOMUTLARI, /DROP INDEX IF EXISTS/);
});

// ===========================================================================
// 9. GERİ ALINABİLİRLİK — engel kalkınca içerik GERİ GELİR
// ===========================================================================

test('MESAJLAR ve GÖNDERİLER SİLİNMEZ — engel kalkınca geri gelir', () => {
  // Engelleme yalnız GÖRÜNÜRLÜK kuralıdır. Tek istisna bildirimlerdir
  // (türetilmiş veri) ve o istisna kodda gerekçesiyle yazılıdır.
  assert.equal(/DELETE FROM mesajlar/.test(ENGELLE), false,
    'engelleme mesaj SİLMEMELİ');
  assert.equal(/DELETE FROM yorumlar/.test(ENGELLE), false,
    'engelleme gönderi SİLMEMELİ');
  assert.match(ENGELLE, /DELETE FROM bildirimler/);
});

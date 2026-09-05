// KULLANICI ADI DEĞİŞTİRME + GÖRÜNEN AD (21 Ağu 2026) — `node --test test/*.test.js`
//
// Kullanıcı isteği: "Ayarlardan kullanıcı adı değiştirme olmalı. Kullanıcı
// adını değiştiren kullanıcı 90 gün boyunca kullanıcı adını değiştiremez.
// Ve kullanıcıların adları da olmalı."
// Kullanıcı kararı: "Eski kullanıcı adı 90 gün REZERVE edilir."
//
// Bu dosyanın koruduğu BEŞ KURAL:
//
//  1) 90 GÜN KİLİDİ SUNUCUDA. Arayüzde alanı kilitlemek yetmez — uç doğrudan
//     çağrılabilir. Süre dolmadan gelen istek 403 alır ve KALAN GÜN yanıtta
//     makine alanı olarak bildirilir (sessiz ret yasak).
//  2) BENZERSİZLİĞİN HAKEMİ VERİTABANI KISITI. "SELECT ile bak, sonra UPDATE"
//     bir yarış koşuludur; kaybeden taraf 23505 alır, 409'a çevrilir ve işlem
//     GERİ ALINIR (yarım yazılmış rezerv kalmaz).
//  3) REZERVE AD BAŞKASINA VERİLMEZ, SAHİBİNE VERİLİR. Yabancı 409 görür;
//     sahibi (geri dönüş) kilidi beklemeden alır ve kilit damgası SIFIRLANMAZ.
//  4) REZERV YARIŞI: yazmadan sonra bir kez daha okunur. Ön kontrol tek başına
//     "adını tam o anda bırakan kullanıcı" ile yarışı kaybederdi.
//  5) GÖRÜNEN AD serbest metindir ama BOZULMAZ: uzunluk aşımı reddedilir,
//     denetim karakteri ve görünmezler süzülür, boşluk kırpılır.
//
// YÖNTEM: `server.js` içe aktarılamıyor (modül yüklenir yüklenmez dinlemeye
// başlıyor — gizlilik_secenekleri/dogum_gunu testleriyle aynı gerekçe). Bu
// yüzden kural motoru KAYNAKTAN ÇEKİLİP SAHTE BİR HAVUZLA GERÇEKTEN
// ÇALIŞTIRILIYOR: sınanan şey kopyası değil, canlıdaki kodun ta kendisi.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-21.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın
// (geri alma bölümü bilerek DROP örneği içerir).
const MIGRASYON_KOMUTLARI = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan kod çekme (gizlilik_secenekleri.test.js'teki kalıbın aynısı)
// ---------------------------------------------------------------------------

/** `bas` indeksindeki ilk `{`/`(`/`[` çiftini dengeleyerek bloğu döndürür. */
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

/** `function` / `async function` / `const` bildiriminin TAM metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^(async function|function|const) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  if (m[1] === 'const') {
    // DİZE VE REGEX İÇİ ATLANIR: `KULLANICI_ADI_KURALI` metninde noktalı
    // virgül var ("3-20 karakter; küçük harf...") ve saf `;` taraması
    // bildirimi ortasından keserdi.
    let derinlik = 0;
    let tirnak = null;
    for (let i = m.index; i < KAYNAK.length; i++) {
      const c = KAYNAK[i];
      if (tirnak) {
        if (c === '\\') i++;
        else if (c === tirnak) tirnak = null;
        continue;
      }
      if (c === "'" || c === '"' || c === '`') tirnak = c;
      else if (c === '/' && /[=(,[]\s*$/.test(KAYNAK.slice(m.index, i))) {
        // regex sabiti: kapanana kadar atla (karakter sınıfı içindeki `/` dahil)
        let sinif = false;
        for (i++; i < KAYNAK.length; i++) {
          const r = KAYNAK[i];
          if (r === '\\') i++;
          else if (r === '[') sinif = true;
          else if (r === ']') sinif = false;
          else if (r === '/' && !sinif) break;
        }
      } else if ('{(['.includes(c)) derinlik++;
      else if ('})]'.includes(c)) derinlik--;
      else if (c === ';' && derinlik === 0) return KAYNAK.slice(m.index, i + 1);
    }
    assert.fail(`${ad} bildiriminin sonu bulunamadı`);
  }
  return blokAl(KAYNAK, m.index, '{', '}');
}

/** İstenen bildirimleri derleyip son ifadeyi döndüren sanal alan. */
function alan(adlar, ifade) {
  const govde = adlar.map(bildirimCek).join('\n');
  // eslint-disable-next-line no-new-func
  return new Function(`${govde}\nreturn (${ifade});`)();
}

/** `app.<metot>('<yol>'` ile başlayan uç kaydının TAM gövdesi. */
function ucGovdesi(metot, yol) {
  const ara = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot.toUpperCase()} ${yol}`);
  return blokAl(KAYNAK, bas + ara.length - 1, '(', ')');
}

const SABITLER = [
  'KULLANICI_ADI_KALIBI', 'KULLANICI_ADI_KURALI', 'MISAFIR_ADI_KALIBI',
  'KULLANICI_ADI_KILIT_GUN', 'KULLANICI_ADI_REZERV_GUN', 'GUN_MS', 'AD_AZAMI',
];
// Yasaklı ad süzgeci (21 Ağu 2026) — `kullaniciAdiDegistir` artık buna bağlı,
// yani sanal alana da girmesi gerekiyor. Ayrıntılı sınamalar
// `yasakli_kullanici_adi.test.js`te; burada yalnız bağımlılık.
const YASAK_SUZGEC = [
  'AD_RAKAM_HARF', 'YASAKLI_AD_ISKELETLERI', 'MARKA_ISKELETI',
  'adIskeletleri', 'yasakliKullaniciAdi',
];
const adDogrula = alan([...SABITLER, 'adDogrula'], 'adDogrula');
const kullaniciAdiKalanGun = alan(
  [...SABITLER, 'kullaniciAdiKalanGun'], 'kullaniciAdiKalanGun');
const kullaniciAdiDegistir = alan(
  [...SABITLER, ...YASAK_SUZGEC,
    'kullaniciAdiKalanGun', 'adRezerveMi', 'ilkAdSecimiUygun', 'kullaniciAdiDegistir'],
  'kullaniciAdiDegistir');
const ilkAdSecimiUygun = alan(['ilkAdSecimiUygun'], 'ilkAdSecimiUygun');
const KILIT_GUN = alan(SABITLER, 'KULLANICI_ADI_KILIT_GUN');
const REZERV_GUN = alan(SABITLER, 'KULLANICI_ADI_REZERV_GUN');

// ---------------------------------------------------------------------------
// Sahte havuz: her sorguyu KAYDEDER, kalıba göre yanıt üretir.
// ---------------------------------------------------------------------------
// Amaç kopya bir mantık kurmak DEĞİL, gerçek fonksiyonu koşturup ÜRETTİĞİ
// SORGU DİZİSİNİ ve dönüşünü sınamak. `gunluk` sayesinde "geri alındı mı",
// "rezerv yazıldı mı", "kaç kez okundu" gibi sorular kanıtla yanıtlanıyor.
function sahteHavuz(kurallar) {
  const gunluk = [];
  const istemci = {
    birakildi: false,
    async query(sql, par) {
      const duz = String(sql).replace(/\s+/g, ' ').trim();
      gunluk.push(duz);
      for (const [kalip, uret] of kurallar) {
        if (kalip.test(duz)) {
          const sonuc = typeof uret === 'function' ? uret(par, duz) : uret;
          if (sonuc instanceof Error) throw sonuc;
          return sonuc ?? { rows: [] };
        }
      }
      return { rows: [] };
    },
    release() { istemci.birakildi = true; },
  };
  return { havuz: { connect: async () => istemci }, istemci, gunluk };
}

const pg23505 = () => Object.assign(new Error('duplicate key'), { code: '23505' });

/** Ortak kural seti; `ustuneYaz` ile tek tek değiştirilir. */
function kurallar({ ben, rezerv = [], guncelle, rezervIkinci }) {
  let rezervOkuma = 0;
  return [
    [/^BEGIN$/, { rows: [] }],
    [/^COMMIT$/, { rows: [] }],
    [/^ROLLBACK$/, { rows: [] }],
    [/FROM kullanicilar WHERE id = \$1 FOR UPDATE/, { rows: ben ? [ben] : [] }],
    [/FROM kullanici_adi_rezervleri WHERE kullanici_adi/, () => {
      rezervOkuma += 1;
      // İkinci okuma = YAZMADAN SONRAKİ kontrol. Yarış senaryosunda bilerek
      // farklı cevap verilir: ilk bakışta boş, yazdıktan sonra dolu.
      if (rezervOkuma === 2 && rezervIkinci) return { rows: rezervIkinci };
      return { rows: rezerv };
    }],
    [/^UPDATE kullanicilar/, guncelle ?? (() => ({
      rows: [{
        id: ben?.id ?? 7, kullanici_adi: 'veli', email: 'v@x.tr',
        misafir: false, kullanici_adi_degisim: new Date().toISOString(),
      }],
    }))],
    [/^DELETE FROM kullanici_adi_rezervleri/, { rows: [] }],
    [/^INSERT INTO kullanici_adi_rezervleri/, { rows: [] }],
  ];
}

const BEN = {
  id: 7, kullanici_adi: 'ali', kullanici_adi_degisim: null, misafir: false,
};

// ===========================================================================
// 1. GÖRÜNEN AD — serbest metin, ama bozulmuyor
// ===========================================================================

test('ad: gönderilmezse/boşsa NULL (ad yok ile boş ad tek durumdur)', () => {
  assert.deepEqual(adDogrula(null), { tamam: true, deger: null });
  assert.deepEqual(adDogrula(''), { tamam: true, deger: null });
  assert.deepEqual(adDogrula('    '), { tamam: true, deger: null });
});

test('ad: baştan/sondan boşluk kırpılır, içerideki yığın tek boşluğa iner', () => {
  assert.equal(adDogrula('  Ali   Cihan  ').deger, 'Ali Cihan');
  // NBSP ve ideografik boşluk da boşluktur; "görünmez ad" üretmeye yaramasın.
  assert.equal(adDogrula(' Ali　Cihan ').deger, 'Ali Cihan');
});

test('ad: SATIR SONU ve denetim karakterleri BOŞLUĞA çevrilir (silinmez)', () => {
  // Silinseydi "AliVeli" olurdu — kullanıcının yazdığı ayrım kaybolurdu.
  assert.equal(adDogrula('Ali\nVeli').deger, 'Ali Veli');
  assert.equal(adDogrula('Ali\r\n\tVeli').deger, 'Ali Veli');
  assert.equal(adDogrula('Ali Veli').deger, 'Ali Veli');
  assert.equal(adDogrula('AliVeli').deger, 'Ali Veli');
  // Satır sonu KALSAYDI profil başlığı ve "{ad} seni takip etti" bildirimi
  // ortadan bölünürdü; sonuç dizede hiç `\n` kalmamalı.
  assert.doesNotMatch(adDogrula('a\nb\nc').deger, /[\r\n]/);
});

test('ad: GÖRÜNMEZ karakterler tamamen ATILIR', () => {
  // Sıfır genişlikli boşluk/birleştirici, BOM ve çift yönlü yazım geçersiz
  // kılıcıları: ekranda hiçbir şey göstermez, "eşsiz" ad üretmeye ve komşu
  // metnin yönünü ters çevirmeye yarar.
  assert.equal(adDogrula('A​l‌i‍').deger, 'Ali');
  assert.equal(adDogrula('﻿Ali').deger, 'Ali');
  assert.equal(adDogrula('‮Ali‬').deger, 'Ali');
  assert.equal(adDogrula('⁦Ali⁩').deger, 'Ali');
  // Yalnız görünmezlerden oluşan ad = ad yok.
  assert.equal(adDogrula('​​﻿').deger, null);
});

test('ad: UZUNLUK AŞIMI REDDEDİLİR (sessizce kırpılmaz)', () => {
  const tam = 'a'.repeat(40);
  assert.equal(adDogrula(tam).deger, tam, '40 karakter sınırın İÇİNDE');
  const asan = adDogrula('a'.repeat(41));
  assert.equal(asan.tamam, false);
  assert.equal(asan.kod, 'AD_UZUN');
  // Sessiz kırpma kullanıcıya yalan söylerdi: "kaydedildi" deyip yarısını yutmak.
  assert.equal(asan.deger, undefined);
});

test('ad: uzunluk KOD NOKTASI sayılır — emoji 2 değil 1', () => {
  // JS `length` UTF-16 birimi sayar; 40 emoji `length` 80'dir. Kullanıcı
  // kararı "emoji serbest" olduğu için ölçünün emojiyi cezalandırmaması şart.
  const emoji = '\u{1F600}'.repeat(40);
  assert.equal(emoji.length, 80);
  assert.equal(adDogrula(emoji).tamam, true, '40 emoji reddedildi');
  assert.equal(adDogrula('\u{1F600}'.repeat(41)).tamam, false);
});

test('ad: tek karakter ve emoji SERBEST (politika yok, kullanıcı kararı)', () => {
  assert.equal(adDogrula('x').deger, 'x');
  assert.equal(adDogrula('\u{1F680}').deger, '\u{1F680}');
  // "Taklit" de serbest — süzgeç yok, kullanıcı böyle istedi.
  assert.equal(adDogrula('dizi.jpg resmi').deger, 'dizi.jpg resmi');
});

test('ad: metin olmayan ve dev gövde erken reddedilir', () => {
  assert.equal(adDogrula(42).tamam, false);
  assert.equal(adDogrula({}).tamam, false);
  assert.equal(adDogrula('a'.repeat(1001)).tamam, false);
});

// ===========================================================================
// 2. 90 GÜN KİLİDİ — kalan gün hesabı
// ===========================================================================

test('kilit: hiç değiştirmemiş hesap SERBEST', () => {
  assert.equal(kullaniciAdiKalanGun(null), 0);
  assert.equal(kullaniciAdiKalanGun(undefined), 0);
  assert.equal(kullaniciAdiKalanGun('bozuk-tarih'), 0);
});

test('kilit: kalan gün YUKARI yuvarlanır (12 saat kaldıysa "1 gün")', () => {
  const gun = 24 * 60 * 60 * 1000;
  const simdi = Date.UTC(2026, 7, 21, 12, 0, 0);
  // Tam 90 gün önce değişmiş → süre DOLDU.
  assert.equal(kullaniciAdiKalanGun(new Date(simdi - KILIT_GUN * gun), simdi), 0);
  // 89,5 gün önce → 12 saat kaldı → "0 gün" DEMEZ, 1 der. "0 gün sonra"
  // yazısını okuyan kullanıcı hemen deneyip reddedilmemeli.
  assert.equal(kullaniciAdiKalanGun(new Date(simdi - 89.5 * gun), simdi), 1);
  // Bugün değişmiş → tam 90 gün.
  assert.equal(kullaniciAdiKalanGun(new Date(simdi), simdi), KILIT_GUN);
  // 48 gün önce → 42 gün kaldı (kullanıcıya söylenen cümlenin sayısı).
  assert.equal(kullaniciAdiKalanGun(new Date(simdi - 48 * gun), simdi), 42);
});

test('kilit SUNUCUDA zorlanıyor: süre dolmadan uç 4xx ve KALAN GÜN döner', async () => {
  const gun = 24 * 60 * 60 * 1000;
  const simdi = Date.UTC(2026, 7, 21);
  const ben = {
    ...BEN, kullanici_adi_degisim: new Date(simdi - 48 * gun).toISOString(),
  };
  const { havuz, gunluk, istemci } = sahteHavuz(kurallar({ ben }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli', simdi);
  assert.equal(s.durum, 403, '4xx dönmedi — kilit yalnız arayüzde kalırdı');
  assert.equal(s.kod, 'AD_KILIT');
  assert.equal(s.kalan_gun, 42, 'kalan gün bildirilmedi (sessiz ret)');
  assert.match(s.hata, /42/, 'kullanıcıya gösterilen metinde de kalan gün yok');
  // Kilitliyken HİÇBİR ŞEY YAZILMADI ve işlem geri alındı.
  assert.ok(!gunluk.some((q) => /^UPDATE kullanicilar/.test(q)), 'kilitliyken yazdı');
  assert.ok(gunluk.includes('ROLLBACK'), 'işlem geri alınmadı');
  assert.ok(istemci.birakildi, 'bağlantı havuza iade edilmedi');
});

test('kilit: süre dolmuşsa değişim GEÇER ve damga YENİLENİR', async () => {
  const gun = 24 * 60 * 60 * 1000;
  const simdi = Date.UTC(2026, 7, 21);
  const ben = {
    ...BEN, kullanici_adi_degisim: new Date(simdi - 91 * gun).toISOString(),
  };
  const { havuz, gunluk } = sahteHavuz(kurallar({ ben }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli', simdi);
  assert.equal(s.durum, 200);
  assert.equal(s.geri_donus, false);
  const u = gunluk.find((q) => /^UPDATE kullanicilar/.test(q));
  assert.ok(u, 'UPDATE hiç çalışmadı');
  // Damga `CASE WHEN <geriDonus> THEN eski ELSE now() END` ile yazılıyor;
  // geri dönüş DEĞİLSE ikinci parametre false gitmeli.
  assert.match(u, /kullanici_adi_degisim = CASE WHEN \$2 THEN kullanici_adi_degisim ELSE now\(\) END/);
  assert.ok(gunluk.includes('COMMIT'));
});

// ===========================================================================
// 2b. İLK SEÇİM (karşılama adımı, 5 Eyl 2026) — kilitsiz, rezervsiz, damgasız
// ===========================================================================
// Kullanıcı isteği: "kullanıcı adlarını otomatik atıyoruz, onu kullanıcı
// seçmeli." Google ile açılan hesabın adını sunucu türetiyor; karşılamadaki
// seçim bir DEĞİŞİKLİK değil İLK SEÇİM: kilit takılmaz, damga yazılmaz,
// üretilmiş ad rezerve edilmez. Pencere yalnız UYGUN hesaba açık — aksi hâlde
// herkes "karşılama ucu"ndan 90 gün kilidini atlardı.

const GOOGLE_BEN = {
  ...BEN, kullanici_adi: 'ali.veli_3f2a', google_sub: 'g-123', karsilama_bitti: false,
};

test('ilk seçim: yalnız Google kökenli + adı değişmemiş + karşılaması bitmemiş hesap', () => {
  assert.equal(ilkAdSecimiUygun(GOOGLE_BEN), true);
  // E-postayla kayıt: adı kendi seçti, pencere yok.
  assert.equal(ilkAdSecimiUygun({ ...GOOGLE_BEN, google_sub: null }), false);
  // Misafir: ad seçme hakkı /auth/bagla'da.
  assert.equal(ilkAdSecimiUygun({ ...GOOGLE_BEN, misafir: true }), false);
  // Ayarlardan bir kez değiştirmiş: artık kilitli yol.
  assert.equal(ilkAdSecimiUygun({
    ...GOOGLE_BEN, kullanici_adi_degisim: '2026-09-01T00:00:00Z',
  }), false);
  // Karşılama bitti: pencere KAPANDI.
  assert.equal(ilkAdSecimiUygun({ ...GOOGLE_BEN, karsilama_bitti: true }), false);
  assert.equal(ilkAdSecimiUygun(null), false);
  assert.equal(ilkAdSecimiUygun(undefined), false);
});

test('ilk seçim: uygun hesapta yazar; damga KORUNUR, rezerv YAZILMAZ', async () => {
  let parametreler;
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben: GOOGLE_BEN,
    guncelle: (par) => {
      parametreler = par;
      return { rows: [{
        id: 7, kullanici_adi: 'ali', email: 'a@x.tr', misafir: false,
        kullanici_adi_degisim: null,
      }] };
    },
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'Ali ', undefined, { ilkSecim: true });
  assert.equal(s.durum, 200, JSON.stringify(s));
  assert.equal(s.ilk_secim, true);
  assert.equal(s.onceki_ad, 'ali.veli_3f2a');
  assert.equal(s.kullanici.kullanici_adi, 'ali');
  // Kırpılıp küçültülerek yazıldı.
  assert.equal(parametreler[0], 'ali');
  // `CASE WHEN $2 THEN kullanici_adi_degisim` — $2 TRUE: damga yazılmadı,
  // yani ayarlardan yapılacak İLK değişiklik de serbest kalır (e-posta
  // kaydıyla eşit hak).
  assert.equal(parametreler[1], true, 'ilk seçimde kilit damgası yazıldı');
  // Sonraki kilit yok: kalan gün 0.
  assert.equal(s.kalan_gun, 0);
  // Üretilmiş ad rezerve EDİLMEDİ (tablo şişmesin, kimse ona dönmez).
  assert.ok(!gunluk.some((q) => /^INSERT INTO kullanici_adi_rezervleri/.test(q)),
    'ilk seçimde eski üretilmiş ad rezerve edildi');
  assert.ok(!gunluk.some((q) => /^DELETE FROM kullanici_adi_rezervleri/.test(q)));
  assert.ok(gunluk.includes('COMMIT'));
  // Uygunluk sütunları FOR UPDATE seçiminde okunuyor (yarış: aynı anda iki istek).
  const secim = gunluk.find((q) => /FOR UPDATE/.test(q));
  assert.match(secim, /google_sub/);
  assert.match(secim, /karsilama_bitti/);
});

test('ilk seçim: UYGUN OLMAYAN hesap 403 alır, hiçbir şey yazılmaz', async () => {
  for (const ben of [
    { ...GOOGLE_BEN, google_sub: null },            // e-posta kaydı
    { ...GOOGLE_BEN, karsilama_bitti: true },       // pencere kapandı
    { ...GOOGLE_BEN, kullanici_adi_degisim: new Date().toISOString() },
  ]) {
    const { havuz, gunluk, istemci } = sahteHavuz(kurallar({ ben }));
    const s = await kullaniciAdiDegistir(havuz, 7, 'veli', undefined, { ilkSecim: true });
    assert.equal(s.durum, 403);
    assert.equal(s.kod, 'ILK_SECIM_YOK');
    assert.ok(!gunluk.some((q) => /^UPDATE kullanicilar/.test(q)), 'uygun değilken yazdı');
    assert.ok(gunluk.includes('ROLLBACK'));
    assert.ok(istemci.birakildi);
  }
});

test('ilk seçim: yasaklı ad ve kalıp dışı ad burada da reddedilir', async () => {
  const { havuz } = sahteHavuz(kurallar({ ben: GOOGLE_BEN }));
  assert.equal((await kullaniciAdiDegistir(havuz, 7, 'admin', undefined, { ilkSecim: true })).kod,
    'AD_AYRILMIS');
  assert.equal((await kullaniciAdiDegistir(havuz, 7, 'ab', undefined, { ilkSecim: true })).kod,
    'AD_GECERSIZ');
  assert.equal((await kullaniciAdiDegistir(havuz, 7, 'misafir_ab12', undefined, { ilkSecim: true })).kod,
    'AD_AYRILMIS');
});

test('ilk seçim: OLAĞAN yol (seçenek yok) hâlâ damga yazar ve rezerv koyar', async () => {
  let parametreler;
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben: GOOGLE_BEN, guncelle: (par) => { parametreler = par; return { rows: [{
      id: 7, kullanici_adi: 'veli', email: 'a@x.tr', misafir: false,
      kullanici_adi_degisim: new Date().toISOString(),
    }] }; },
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli');
  assert.equal(s.durum, 200);
  assert.equal(s.ilk_secim, false);
  assert.equal(parametreler[1], false, 'olağan değişimde damga yazılmadı');
  assert.ok(gunluk.some((q) => /^INSERT INTO kullanici_adi_rezervleri/.test(q)));
});

test('uçlar: /karsilama/kullanici-adi ilkSecim kipiyle çağırıyor; müsaitlik ucu uygunluk kapılı', () => {
  const yaz = ucGovdesi('post', '/karsilama/kullanici-adi');
  assert.match(yaz, /ilkSecim: true/);
  assert.match(yaz, /ilkAdSecimLimiti/, 'hız limiti yok');
  const oku = ucGovdesi('get', '/karsilama/kullanici-adi-musait');
  assert.match(oku, /ilkAdSecimiUygun\(rows\[0\]\)/, 'müsaitlik ucu uygunluk kapısız');
  assert.match(oku, /ilkAdMusaitLimiti/);
  assert.match(oku, /KULLANICI_ADI_KALIBI\.test\(ad\)/);
  assert.match(oku, /adRezerveMi\(havuz, ad, req\.kullanici\.id\)/);
  // Karşılama GET'i istemciye "ad seçilmeli" bayrağını veriyor.
  const kars = ucGovdesi('get', '/karsilama');
  assert.match(kars, /ad_secilmeli: ilkAdSecimiUygun\(k\)/);
  // Google yeni hesap yanıtı `ad_otomatik` taşıyor (istemci adımı buna açar).
  const google = ucGovdesi('post', '/auth/google');
  assert.match(google, /yeni: true, ad_otomatik: true/);
});

// ===========================================================================
// 3. BENZERSİZLİK YARIŞI — hakem veritabanı kısıtı
// ===========================================================================

test('şema: kullanici_adi ÜZERİNDE UNIQUE var (yarışın tek gerçek hakemi)', () => {
  assert.match(SEMA, /kullanici_adi TEXT UNIQUE NOT NULL/,
    'UNIQUE kalkmış — iki kullanıcı aynı adı alabilir');
});

test('yarış: eşzamanlı istekte kaybeden 23505 alır → 409, veri BOZULMAZ', async () => {
  // İki istek aynı anda `veli` istiyor. İkisi de ön kontrolde "boş" görüyor
  // (sahte rezerv tablosu boş). Kaybeden tarafın UPDATE'i tekil indekse
  // takılıyor: pg 23505 fırlatır.
  const { havuz, gunluk, istemci } = sahteHavuz(kurallar({
    ben: BEN, guncelle: () => pg23505(),
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli');
  assert.equal(s.durum, 409, '23505 yutuldu ya da 500 oldu');
  assert.equal(s.kod, 'AD_ALINMIS');
  // VERİ BOZULMADI: işlem geri alındı, rezerv YAZILMADI.
  assert.ok(gunluk.includes('ROLLBACK'), 'çakışmada işlem geri alınmadı');
  assert.ok(!gunluk.includes('COMMIT'), 'çakışmaya rağmen işlendi');
  assert.ok(!gunluk.some((q) => /^INSERT INTO kullanici_adi_rezervleri/.test(q)),
    'kaybeden taraf yine de rezerv yazdı — eski adı boşuna kilitlerdi');
  assert.ok(istemci.birakildi);
});

test('yarış: 23505 DIŞINDAKİ hata yutulmuyor (500 olarak yukarı çıkar)', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben: BEN, guncelle: () => new Error('bağlantı koptu'),
  }));
  await assert.rejects(() => kullaniciAdiDegistir(havuz, 7, 'veli'), /bağlantı koptu/);
  assert.ok(gunluk.includes('ROLLBACK'));
});

test('yarış: aynı hesabın iki isteği FOR UPDATE ile sıraya girer', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({ ben: BEN }));
  await kullaniciAdiDegistir(havuz, 7, 'veli');
  assert.ok(
    gunluk.some((q) => /FROM kullanicilar WHERE id = \$1 FOR UPDATE/.test(q)),
    'satır kilidi yok — aynı hesaptan iki istek ikisi de "kilit yok" görürdü');
});

// ===========================================================================
// 4. REZERV — başkasına verilmez, sahibine verilir
// ===========================================================================

test('rezerve ad BAŞKASINA verilmiyor (409, yazma yok)', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben: BEN, rezerv: [{ kullanici_id: 99 }], // sahibi BAŞKASI
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli');
  assert.equal(s.durum, 409);
  assert.equal(s.kod, 'AD_REZERVE');
  assert.ok(!gunluk.some((q) => /^UPDATE kullanicilar/.test(q)),
    'rezerve ada rağmen yazdı — rezervin hiçbir anlamı kalmazdı');
  assert.ok(gunluk.includes('ROLLBACK'));
});

test('rezerve ad SAHİBİNE GERİ VERİLİYOR — kilit beklemeden (KARAR: evet)', async () => {
  // Kilit ile rezerv aynı 90 günü paylaşıyor; muafiyet olmasaydı "eski adına
  // dönebilirsin" fiilen imkânsız olurdu (kilit bittiği an rezerv de biterdi).
  const gun = 24 * 60 * 60 * 1000;
  const simdi = Date.UTC(2026, 7, 21);
  const ben = {
    ...BEN, kullanici_adi: 'veli',
    kullanici_adi_degisim: new Date(simdi - 3 * gun).toISOString(), // KİLİTLİ
  };
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben, rezerv: [{ kullanici_id: 7 }], // rezervin sahibi BENİM
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'ali', simdi);
  assert.equal(s.durum, 200, 'sahibi kendi rezervine dönemedi');
  assert.equal(s.geri_donus, true);
  assert.ok(gunluk.includes('COMMIT'));
});

test('geri dönüş kilit damgasını SIFIRLAMIYOR (sonsuz gidip gelme ödüllenmez)', async () => {
  const gun = 24 * 60 * 60 * 1000;
  const simdi = Date.UTC(2026, 7, 21);
  const ben = {
    ...BEN, kullanici_adi: 'veli',
    kullanici_adi_degisim: new Date(simdi - 3 * gun).toISOString(),
  };
  let ikinciParametre;
  const { havuz } = sahteHavuz(kurallar({
    ben,
    rezerv: [{ kullanici_id: 7 }],
    guncelle: (par) => {
      ikinciParametre = par[1];
      return { rows: [{ ...ben, kullanici_adi: 'ali' }] };
    },
  }));
  await kullaniciAdiDegistir(havuz, 7, 'ali', simdi);
  // $2 = geriDonus → true ise SQL damgayı olduğu gibi bırakıyor.
  assert.equal(ikinciParametre, true,
    'geri dönüşte damga yenileniyor — iki ad arasında flip-flop serbest kalırdı');
});

test('KULLANICI BAŞINA TEK REZERV: yenisi yazılmadan eskisi siliniyor', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({ ben: BEN }));
  await kullaniciAdiDegistir(havuz, 7, 'veli');
  const sil = gunluk.findIndex(
    (q) => /^DELETE FROM kullanici_adi_rezervleri WHERE kullanici_id = \$1/.test(q));
  const yaz = gunluk.findIndex(
    (q) => /^INSERT INTO kullanici_adi_rezervleri/.test(q));
  assert.ok(sil >= 0, 'eski rezerv silinmiyor — kişi 2\'den fazla ad işgal ederdi');
  assert.ok(yaz >= 0, 'bırakılan ad rezerve edilmiyor');
  assert.ok(sil < yaz, 'silme INSERT\'ten sonra: kısmi tekil indeks 23505 verirdi');
});

test('BIRAKILAN ad rezerve ediliyor ve süre 90 GÜN', async () => {
  let parametreler;
  const { havuz, gunluk } = sahteHavuz([
    ...kurallar({ ben: BEN }),
  ]);
  // INSERT kuralını yakalayabilmek için günlüğe ek olarak parametreyi de
  // yakalamak gerekiyor; en basit yol sorgu metnini incelemek.
  await kullaniciAdiDegistir(havuz, 7, 'veli');
  const ins = gunluk.find((q) => /^INSERT INTO kullanici_adi_rezervleri/.test(q));
  assert.ok(ins);
  assert.match(ins, /now\(\) \+ \(\$3 \|\| ' days'\)::interval/,
    'rezerv süresi sabit yazılmış ya da hiç yok');
  assert.equal(REZERV_GUN, 90, 'kullanıcı kararı 90 gün');
  assert.equal(KILIT_GUN, 90, 'kullanıcı kararı 90 gün');
  parametreler = ins;
  assert.ok(parametreler);
});

test('REZERV YARIŞI: yazmadan SONRA da okunuyor (ön kontrol tek başına yetmez)', async () => {
  // Senaryo: A tam bu anda `veli`yi bırakıp rezerve ediyor. Bizim ön
  // kontrolümüz A'nın rezervini HENÜZ GÖRMÜYOR (boş), ama yazmamız A'nın
  // işlemine takılıp bekliyor; A işlenince ikinci okuma rezervi GÖRÜYOR.
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben: BEN,
    rezerv: [],                        // ön kontrol: boş
    rezervIkinci: [{ kullanici_id: 99 }], // yazma sonrası: BAŞKASININ rezervi
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli');
  assert.equal(s.durum, 409, 'yazma sonrası kontrol yok — rezerv delinirdi');
  assert.equal(s.kod, 'AD_REZERVE');
  assert.ok(gunluk.includes('ROLLBACK'));
  assert.ok(!gunluk.includes('COMMIT'));
  const okumaSayisi = gunluk.filter(
    (q) => /FROM kullanici_adi_rezervleri WHERE kullanici_adi/.test(q)).length;
  assert.equal(okumaSayisi, 2, 'rezerv tablosu yazmadan sonra tekrar okunmuyor');
});

test('KAYIT ve BAĞLAMA uçları da rezerve saygı duyuyor (yoksa rezerv anlamsız)', () => {
  for (const [metot, yol] of [['post', '/auth/kayit'], ['post', '/auth/bagla']]) {
    const g = ucGovdesi(metot, yol);
    assert.match(g, /adRezerveMi\(istemci,/,
      `${yol} rezervi kontrol etmiyor — rezerve ad yeni kayıtla kapılırdı`);
    // Kontrol YAZMADAN SONRA: aynı yarış deliği burada da var.
    const yazma = g.search(/INSERT INTO kullanicilar|UPDATE kullanicilar/);
    const kontrol = g.indexOf('adRezerveMi(istemci,');
    assert.ok(yazma >= 0 && kontrol > yazma,
      `${yol} rezervi yalnız yazmadan ÖNCE kontrol ediyor — yarış açık kalır`);
    assert.match(g, /ROLLBACK/, `${yol} çakışmada işlemi geri almıyor`);
  }
});

test('SİLİNEN hesabın adı da 90 gün rezerve (misafir hariç)', () => {
  const g = ucGovdesi('delete', '/hesabim');
  assert.match(g, /INSERT INTO kullanici_adi_rezervleri/,
    'silinen hesabın adı anında kapılabilir — eski @bahsetmeler devralınır');
  assert.match(g, /AND NOT misafir/,
    'misafir adları da rezerve ediliyor — boşuna satır');
  // Sahibi kalmadı: kimse geri alamaz, yalnız KAPALI.
  assert.match(g, /SELECT kullanici_adi, NULL,/);
  // Rezerv ile silme ATOMİK olmalı: arada düşen sunucu ya adı korumasız
  // bırakır ya yaşayan hesabın adını kilitler.
  assert.match(g, /BEGIN/);
  assert.match(g, /COMMIT/);
  assert.match(g, /ROLLBACK/);
});

// ===========================================================================
// 5. GİRDİ KALIBI + MİSAFİR
// ===========================================================================

test('kullanıcı adı kalıbı TEK YERDE (üç uç aynı sabiti kullanıyor)', () => {
  // Eskiden regex üç uçta kopyalanmıştı; biri güncellenmediği gün sessizce
  // çatlardı. Kaynakta artık kopya kalmamalı.
  const kopya = KAYNAK.match(/\[a-z0-9_\]\[a-z0-9_\.-\]\{1,18\}/g) ?? [];
  // Biri sabit tanımı, biri de @bahsetme çözücüsünün kendi deseni
  // (`etiketBildirimleriGonder` — metin İÇİNDEN yakalıyor, aynı sabit olamaz).
  assert.ok(kopya.length <= 2, `kalıp ${kopya.length} kez kopyalanmış`);
});

test('geçersiz kullanıcı adı 400 (yazma hiç denenmiyor)', async () => {
  // NOT: 'Ali' burada YOK — uç büyük harfi reddetmez, KÜÇÜLTÜR (ayrı test).
  for (const kotu of ['ab', 'a'.repeat(21), 'ali..veli', '.ali', 'ali-', 'a li',
    'ALİ', 'ali@veli', '']) {
    const { havuz, gunluk } = sahteHavuz(kurallar({ ben: BEN }));
    const s = await kullaniciAdiDegistir(havuz, 7, kotu);
    assert.equal(s.durum, 400, `"${kotu}" kabul edildi`);
    assert.equal(s.kod, 'AD_GECERSIZ');
    assert.equal(gunluk.length, 0, `"${kotu}" için boşuna bağlantı açıldı`);
  }
});

test('büyük harf ve boşluk KABUL EDİLİP küçültülüyor (kayıt ucundan farklı)', async () => {
  let yazilan;
  const { havuz } = sahteHavuz(kurallar({
    ben: BEN,
    guncelle: (par) => {
      yazilan = par[0];
      return { rows: [{ ...BEN, kullanici_adi: par[0] }] };
    },
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, '  VELI  ');
  assert.equal(s.durum, 200, 'kullanıcı "Veli" yazınca reddedilmemeli');
  assert.equal(yazilan, 'veli', 'küçültme yapılmadı — DB büyük/küçük harf duyarlı');
});

test('MİSAFİR kalıbına bürünmek yasak (misafirlik kullanıcı adından okunuyor)', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({ ben: BEN }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'misafir_ab12cd34');
  assert.equal(s.durum, 400);
  assert.equal(s.kod, 'AD_AYRILMIS');
  assert.equal(gunluk.length, 0);
});

test('MİSAFİR hesap ad seçemiyor — sebebi SÖYLENİYOR', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({
    ben: { ...BEN, misafir: true },
  }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'veli');
  assert.equal(s.durum, 403);
  assert.equal(s.kod, 'MISAFIR_AD_YOK');
  // Kurtarma yolu metinde: yalnız "yapamazsın" demek kötü mesajdır.
  assert.match(s.hata, /bağla/i);
  assert.ok(!gunluk.some((q) => /^UPDATE kullanicilar/.test(q)));
});

test('aynı ada değişim reddediliyor (kilit boşuna harcanmasın)', async () => {
  const { havuz, gunluk } = sahteHavuz(kurallar({ ben: BEN }));
  const s = await kullaniciAdiDegistir(havuz, 7, 'ali');
  assert.equal(s.durum, 400);
  assert.equal(s.kod, 'AD_AYNI');
  assert.ok(!gunluk.some((q) => /^UPDATE kullanicilar/.test(q)));
});

// ===========================================================================
// 6. UÇLAR — sözleşme
// ===========================================================================

test('POST /profilim/kullanici-adi: giriş zorunlu + hız limiti + kural motoru', () => {
  const g = ucGovdesi('post', '/profilim/kullanici-adi');
  assert.match(g, /girisZorunlu/, 'oturumsuz çağrılabiliyor');
  assert.match(g, /kullaniciAdiLimiti/,
    'hız limiti yok — uç ad listesi taramaya yarardı (409 = "alınmış")');
  assert.match(g, /kullaniciAdiDegistir\(\s*havuz, req\.kullanici\.id/,
    'kural motoru çağrılmıyor ya da başka kullanıcının id\'si geçiyor');
  // Durum kodu MOTORDAN geliyor; uç kendi kararını vermiyor.
  assert.match(g, /res\.status\(durum\)\.json\(govde\)/);
});

test('POST /profilim ad alanını kabul ediyor ve adDogrula\'dan geçiriyor', () => {
  const g = ucGovdesi('post', '/profilim');
  assert.match(g, /const \{ bio, ulke, sosyal, ad \} = req\.body/);
  assert.match(g, /adDogrula\(/, 'ad ham hâliyle veritabanına gidiyor');
  assert.match(g, /ad = CASE WHEN \$8 THEN \$9 ELSE ad END/,
    'gönderilmeyen ad alanı da yazılıyor — başka ekrandan kaydeden adı silerdi');
  assert.match(g, /ad !== undefined/);
});

test('GET /profilim ad + KALAN GÜN döndürüyor (arayüz alanı kilitli çizebilsin)', () => {
  const g = ucGovdesi('get', '/profilim');
  assert.match(g, /testci, ad, kullanici_adi_degisim/);
  assert.match(g, /kullanici_adi_kalan_gun =\s*kullaniciAdiKalanGun/);
});

test('TOKEN YENİLENMİYOR ve bu güvenli: JWT\'deki kullanıcı adı hiç OKUNMUYOR', () => {
  // JWT yükü `kullanici_adi` taşıyor (jwtUret) ama yetkilendirme yalnız
  // id + sv üzerinden yürüyor. Biri gün gelip token'daki adı okumaya kalkarsa
  // burası kırmızıya döner ve ad değişimi bayat kimlikle çalışmaya başlardı.
  const yorumsuz = KAYNAK.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
  const okumalar = yorumsuz.match(/req\.kullanici\.kullanici_adi/g) ?? [];
  assert.equal(okumalar.length, 0,
    'JWT\'deki kullanıcı adı okunuyor — değişimden sonra 90 gün bayat kalır');
});

// ===========================================================================
// 7. ŞEMA + MİGRASYON
// ===========================================================================

test('migrasyon idempotent ve YIKICI DEĞİL', () => {
  assert.match(MIGRASYON_KOMUTLARI, /ADD COLUMN IF NOT EXISTS ad TEXT/);
  assert.match(MIGRASYON_KOMUTLARI, /ADD COLUMN IF NOT EXISTS kullanici_adi_degisim TIMESTAMPTZ/);
  assert.match(MIGRASYON_KOMUTLARI, /CREATE TABLE IF NOT EXISTS kullanici_adi_rezervleri/);
  assert.match(MIGRASYON_KOMUTLARI, /CREATE UNIQUE INDEX IF NOT EXISTS/);
  assert.match(MIGRASYON_KOMUTLARI, /CREATE INDEX IF NOT EXISTS kullanici_adi_rezerv_bitis/);
  // Kısıt için `IF NOT EXISTS` yok; pg_constraint bakan DO bloğu var.
  assert.match(MIGRASYON_KOMUTLARI, /FROM pg_constraint WHERE conname = 'kullanicilar_ad_uzunluk'/);
  // Komut bölümünde veri satırına dokunan hiçbir şey OLMAMALI (geri alma
  // örneği yorum satırındadır, MIGRASYON_KOMUTLARI onu zaten eliyor).
  // İFADE BAŞI aranıyor: `ON DELETE SET NULL` bir FK davranışıdır, veri
  // silmez — düz `\bDELETE\b` onu yanlışlıkla yakalardı.
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /^\s*(DELETE|UPDATE|TRUNCATE)\b/im);
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /\bDROP (TABLE|COLUMN)\b/i);
});

test('sema.sql ile migrasyon AYNI ŞEYİ tanımlıyor', () => {
  for (const parca of [
    /ADD COLUMN IF NOT EXISTS ad TEXT/,
    /ADD COLUMN IF NOT EXISTS kullanici_adi_degisim TIMESTAMPTZ/,
    /CREATE TABLE IF NOT EXISTS kullanici_adi_rezervleri/,
    /kullanici_id INT REFERENCES kullanicilar\(id\) ON DELETE SET NULL/,
    /CREATE UNIQUE INDEX IF NOT EXISTS kullanici_adi_rezerv_sahip/,
    /CREATE INDEX IF NOT EXISTS kullanici_adi_rezerv_bitis/,
    /char_length\(ad\) <= 40/,
  ]) {
    assert.match(SEMA, parca, `sema.sql'de eksik: ${parca}`);
    assert.match(MIGRASYON_KOMUTLARI, parca, `migrasyonda eksik: ${parca}`);
  }
});

test('rezerv FK\'sı SET NULL — CASCADE olsaydı silinen hesabın adı anında açılırdı', () => {
  assert.doesNotMatch(
    SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS kullanici_adi_rezervleri')),
    /kullanici_id INT REFERENCES kullanicilar\(id\) ON DELETE CASCADE/);
});

test('VARSAYILAN NULL: yükseltme kimseye geçmişe dönük kilit koymuyor', () => {
  // `kullanici_adi_degisim` NOT NULL DEFAULT now() olsaydı, migrasyonun
  // çalıştığı an TÜM kullanıcılar 90 gün kilitlenirdi.
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /kullanici_adi_degisim[^;]*DEFAULT/i);
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /kullanici_adi_degisim[^;]*NOT NULL/i);
  assert.equal(kullaniciAdiKalanGun(null), 0);
});

test('süresi dolan rezervler gecelik budamada siliniyor (yalnız disk için)', () => {
  const bas = KAYNAK.indexOf('async function tablolariBuda');
  assert.notEqual(bas, -1);
  const g = KAYNAK.slice(bas, bas + 3000);
  assert.match(g, /DELETE FROM kullanici_adi_rezervleri WHERE bitis <= now\(\)/);
  // Ama DOĞRULUK budamaya bağlı OLMAMALI: sorgular `bitis > now()` süzüyor.
  const motor = bildirimCek('adRezerveMi');
  assert.match(motor, /bitis > now\(\)/,
    'rezerv okuması süre süzmüyor — budama gecikirse süresi dolmuş ad kilitli kalır');
});

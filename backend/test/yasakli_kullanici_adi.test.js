// YASAKLI KULLANICI ADLARI + AI HESABI KİMLİĞİ (21 Ağu 2026)
// `node --test test/*.test.js`
//
// İKİ GÜVENLİK BOŞLUĞU, TEK KÖK: kullanıcı adı artık DEĞİŞTİRİLEBİLİR bir alan
// (`POST /profilim/kullanici-adi`, aynı gün eklendi). Ada dayanan her karar o
// gün kırılgan hâle geldi.
//
//  BOŞLUK 1 — `admin`, `destek`, `dizijpg` serbestti. Kullanıcı adı bu sistemin
//  KİMLİK ANAHTARI (profil yolu, `@bahsetme`, mesaj/engelleme uçları), yani
//  `@destek` adlı hesap kullanıcıya resmî destek gibi görünür. Ad değiştirme
//  yüzeyi büyüttü: yaşlı, güvenilir görünen bir hesap sonradan `@admin` olabilirdi.
//
//  BOŞLUK 2 — AI hesabı `kullanici_adi = 'dizi.jpg.ai'` metin karşılaştırmasıyla
//  tanınıyordu (dört yerde). Ad değişince AI KAÇIRILIR, adı kapan TAKLİT EDER.
//
// BU DOSYANIN KORUDUĞU ALTI KURAL:
//  1) Yasaklı ad ÜÇ giriş noktasının HEPSİNDE reddediliyor — ayrı ayrı, gerçek
//     uç gövdesi çalıştırılarak (kayıt · bağlama · ad değiştirme).
//  2) Normalleştirme kararı: `adm1n`/`a.d.m.i.n`/`admin1` YAKALANIR ama
//     `admiral`/`yardimci`/`misafirperver` MEŞRU kalır.
//  3) MEVCUT kullanıcı kilitlenmiyor: kural yalnız YENİ atamada çalışır.
//  4) AI kimliği ADA BAĞLI DEĞİL: hesabın adı değişse de muafiyet sürer, adı
//     kapan sahtekâr muafiyet ALMAZ.
//  5) `tohum` (17 hesap) ile `ai` (1 hesap) AYRI: dört noktanın hiçbiri
//     `tohum`a bağlanmamış, ama `tohum` süzgeci de bozulmamış.
//  6) Veritabanı "AI hesabı BİR tanedir"i kısmi tekil indeksle garanti eder.
//
// YÖNTEM: `server.js` içe aktarılamıyor (yüklenir yüklenmez dinlemeye başlıyor).
// `kullanici_adi.test.js`teki kalıp: kural motoru ve UÇ GÖVDELERİ kaynaktan
// çekilip sahte bağımlılıklarla GERÇEKTEN çalıştırılıyor. Sınanan şey kopya bir
// mantık değil, canlıya gidecek kodun ta kendisi.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ARSIV_YAS_SAAT } from '../siralama.js';
// GERÇEK fonksiyonlar enjekte ediliyor, taklit değil: kayıt/bağlama uçları
// e-posta biçimini bunlarla eliyor (bkz. eposta_bicimi.test.js). Taklit
// koysaydık test, uçların artık geçerli e-posta istediğini göremezdi.
import { epostaGecerli, epostaNormalle } from '../iki_adim.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-21d.sql');

// Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın
// (geri alma bölümü bilerek DROP örneği içerir).
const MIGRASYON_KOMUTLARI = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan kod çekme (kullanici_adi.test.js'teki kalıbın aynısı)
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
  // FONKSİYON: gövde, PARAMETRE LİSTESİNDEN SONRAKİ ilk `{`tir. Doğrudan
  // "ilk süslü parantez" demek YETMEZ — `akisSatiri`/`adaylariGetir` gibi
  // NESNE AYRIŞTIRAN imzalarda (`function f({ a, b })`) ilk `{` parametrenin
  // kendisidir ve bildirim ortasından kesilir (gövdesiz bir fonksiyon üretir,
  // hata da "Unexpected token 'const'" gibi alakasız bir yerde patlar).
  const pAc = KAYNAK.indexOf('(', m.index);
  const parametreler = blokAl(KAYNAK, pAc, '(', ')');
  const govdeBas = KAYNAK.indexOf('{', pAc + parametreler.length);
  const govde = blokAl(KAYNAK, govdeBas, '{', '}');
  return KAYNAK.slice(m.index, govdeBas + govde.length);
}

/**
 * `app.<metot>('<yol>', ..., sarici(async (req, res) => {...}))` içindeki
 * İŞLEYİCİNİN kaynak metni. Ara katmanlar (hız limiti, giriş kontrolü)
 * testin konusu değil; burada sınanan şey uç GÖVDESİNİN davranışı.
 */
function ucIsleyiciKaynagi(metot, yol) {
  const ara = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(ara);
  assert.ok(bas >= 0, `uç bulunamadı: ${metot.toUpperCase()} ${yol}`);
  const s = KAYNAK.indexOf('sarici(', bas);
  assert.ok(s > bas && s < bas + 400, `sarici() bulunamadı: ${yol}`);
  return blokAl(KAYNAK, s + 'sarici'.length, '(', ')');
}

/**
 * Bildirimleri derleyip `ifade`yi döndüren sanal alan; `bagimliliklar`
 * (havuz, bcrypt, ...) parametre olarak enjekte edilir.
 */
function kur(bildirimler, bagimliliklar, ifade) {
  const adlar = Object.keys(bagimliliklar);
  const govde = bildirimler.map(bildirimCek).join('\n');
  // eslint-disable-next-line no-new-func
  return new Function(...adlar, `${govde}\nreturn (${ifade});`)(
    ...adlar.map((a) => bagimliliklar[a]));
}

// Yasak süzgecinin TÜM bildirimleri — üç uç da bunlara dayanıyor.
const SUZGEC = [
  'KULLANICI_ADI_KALIBI', 'KULLANICI_ADI_KURALI', 'MISAFIR_ADI_KALIBI',
  'AD_RAKAM_HARF', 'YASAKLI_AD_ISKELETLERI', 'MARKA_ISKELETI',
  'adIskeletleri', 'yasakliKullaniciAdi',
];

const yasakliKullaniciAdi = kur(SUZGEC, {}, 'yasakliKullaniciAdi');

// ---------------------------------------------------------------------------
// Sahte istek/yanıt ve "dokunulursa patlar" havuz
// ---------------------------------------------------------------------------
/**
 * SQL'i sadeleştirir: `--` yorumları ATILIR, boşluk tekleşir.
 * Yorumları atmak ZORUNLU — gerekçe metinleri eski (`kullanici_adi = $1`)
 * hâli anlatmak için ALINTILIYOR ve düz arama kendi açıklamamıza takılırdı.
 */
const sqlSadeles = (sql) => String(sql)
  .replace(/--[^\n]*/g, ' ').replace(/\s+/g, ' ').trim();

function sahteYanit() {
  const y = { kod: 200, govde: null };
  y.status = (k) => { y.kod = k; return y; };
  y.json = (g) => { y.govde = g; return y; };
  return y;
}

/** Her çağrısı testi düşüren havuz: "yasaklı ad DB'ye hiç gitmedi" kanıtı. */
const PATLAYAN_HAVUZ = {
  connect: () => { assert.fail('yasaklı ad için havuz.connect() çağrıldı'); },
  query: () => { assert.fail('yasaklı ad için havuz.query() çağrıldı'); },
};
const PATLAYAN_BCRYPT = {
  hash: () => { assert.fail('yasaklı ad için bcrypt.hash() çağrıldı'); },
  compare: () => assert.fail('bcrypt.compare çağrılmamalı'),
};

// Yakalanması ZORUNLU adlar + neden. Normalleştirme kararının kanıtı bu tablo.
const YAKALANMALI = [
  ['admin', 'düz yetki taklidi'],
  ['ADMIN', 'büyük harf: kalıp zaten reddeder ama süzgeç de küçültüp yakalar'],
  ['adm1n', 'leet 1→i'],
  ['4dmin', 'leet 4→a'],
  ['a.d.m.i.n', 'nokta ayırıcı'],
  ['a_d_m_i_n', 'alt çizgi ayırıcı'],
  ['ad-min', 'tire ayırıcı'],
  ['admin1', 'sondaki rakam kalıbı'],
  ['admin2026', 'sondaki rakam kalıbı (çok haneli)'],
  ['adm1n1', 'önce sondaki rakam atılır, SONRA leet uygulanır'],
  ['r00t', 'leet 0→o'],
  ['de5tek', 'leet 5→s'],
  ['s1stem', 'leet 1→i'],
  ['yardim', 'destek kanalı taklidi (TR)'],
  ['support', 'destek kanalı taklidi (EN)'],
  ['helpdesk', 'destek kanalı taklidi (EN)'],
  ['staff', 'personel taklidi'],
  ['guvenlik', 'güvenlik uyarısı taklidi'],
  ['security', 'güvenlik uyarısı taklidi (EN)'],
  ['official', 'resmî hesap iddiası'],
  ['resmi', 'resmî hesap iddiası (TR)'],
  ['noreply', 'sistem/otomasyon kimliği'],
  ['yonetici', 'yetki taklidi (TR)'],
  ['moderator', 'yetki taklidi'],
  ['dizijpg', 'marka'],
  ['dizi.jpg', 'marka — nokta varyasyonu'],
  ['dizi-jpg', 'marka — tire varyasyonu'],
  ['d1zijpg', 'marka — leet varyasyonu'],
  ['dizijpg_official', 'marka + resmîlik iddiası'],
  ['dizijpgfan', 'marka ALT DİZE: bedeli bilerek kabul edildi'],
  ['resmidizijpg', 'marka alt dize (baştan değil ortadan)'],
  ['dizi.jpg.ai', 'AI hesabının adı da kapılamaz'],
  ['misafir_deadbeef', 'sunucunun ürettiği misafir kalıbı'],
];

// Yakalanmaması ZORUNLU adlar: aşırı normalleştirmenin bedeli.
const MESRU = [
  'admiral', 'admiralbey', 'admiral1',
  'yardimci', 'yardimsever',
  'sistemli', 'sistemci',
  'destekci', 'destekleyen',
  'guvenlikci', 'securityden',
  'moderatorluk', 'resimlerim',
  'rootkit', 'helpsever', 'staffordshire',
  'misafirperver', 'misafirhane',
  'dizi', 'dizisever', 'filmjpg', 'jpgsever',
  'alcelik', 'testkullanici', 'yuki.dorama', 'miles.watches',
  'ali.veli', 'ali_veli-1', 'a1b2c3',
];

// ===========================================================================
// 1. GİRİŞ NOKTASI 1/3 — POST /auth/kayit
// ===========================================================================
function kayitUcu(bagimlilik = {}) {
  return kur(
    [...SUZGEC, 'adRezerveMi'],
    {
      cihazKapisi: async () => false,
      bcrypt: PATLAYAN_BCRYPT,
      havuz: PATLAYAN_HAVUZ,
      jwtUret: () => 'tok',
      epostaGecerli,
      epostaNormalle,
      ...bagimlilik,
    },
    ucIsleyiciKaynagi('post', '/auth/kayit'));
}

test('KAYIT: yasaklı ad 400 + AD_AYRILMIS — bcrypt ve veritabanına HİÇ gidilmiyor', async () => {
  const uc = kayitUcu();
  for (const [ad, neden] of YAKALANMALI) {
    const res = sahteYanit();
    await uc({ body: { email: 'a@b.tr', kullanici_adi: ad, sifre: 'sifre123' } }, res);
    // Büyük harfli ad kalıptan düşer (KULLANICI_ADI_KURALI); ikisi de 400.
    assert.equal(res.kod, 400, `${ad} (${neden}) kabul edildi`);
    if (ad === ad.toLowerCase()) {
      assert.equal(res.govde.kod, 'AD_AYRILMIS', `${ad} (${neden}) yasak listesine takılmadı`);
    }
  }
});

test('KAYIT: MEŞRU adlar süzgeçten geçiyor (bcrypt aşamasına ulaşıyorlar)', async () => {
  // `bcrypt.hash` patlayıcı olmaktan çıkarılıp İŞARET bırakıyor: süzgeci geçen
  // ad gerçekten ileri gidiyor mu, yoksa sessizce mi düşüyor?
  let ulasan = 0;
  const uc = kayitUcu({
    bcrypt: { hash: async () => { ulasan += 1; throw new Error('DUR'); } },
  });
  for (const ad of MESRU) {
    const res = sahteYanit();
    await uc({ body: { email: 'a@b.tr', kullanici_adi: ad, sifre: 'sifre123' } }, res)
      .catch((e) => { if (e.message !== 'DUR') throw e; });
    assert.equal(res.kod, 200, `MEŞRU ad reddedildi: ${ad}`);
  }
  assert.equal(ulasan, MESRU.length, 'bazı meşru adlar bcrypt aşamasına ulaşmadı');
});

// ===========================================================================
// 2. GİRİŞ NOKTASI 2/3 — POST /auth/bagla (misafir hesabı bağlama)
// ===========================================================================
function baglaUcu(bagimlilik = {}) {
  return kur(
    [...SUZGEC, 'adRezerveMi'],
    {
      bcrypt: PATLAYAN_BCRYPT,
      havuz: PATLAYAN_HAVUZ,
      jwtUret: () => 'tok',
      sifreSurumOnbellekSil: () => {},
      epostaGecerli,
      epostaNormalle,
      ...bagimlilik,
    },
    ucIsleyiciKaynagi('post', '/auth/bagla'));
}

test('BAĞLA: yasaklı ad 400 + AD_AYRILMIS — "önce misafir aç, sonra @admin ol" kapalı', async () => {
  const uc = baglaUcu();
  for (const [ad, neden] of YAKALANMALI) {
    if (ad !== ad.toLowerCase()) continue; // kalıp dalı, kayıt testinde sınandı
    const res = sahteYanit();
    await uc(
      { body: { email: 'a@b.tr', sifre: 'sifre123', kullanici_adi: ad },
        kullanici: { id: 7 } }, res);
    assert.equal(res.kod, 400, `${ad} (${neden}) kabul edildi`);
    assert.equal(res.govde.kod, 'AD_AYRILMIS', `${ad} (${neden}) yasak listesine takılmadı`);
  }
});

// ===========================================================================
// 3. GİRİŞ NOKTASI 3/3 — POST /profilim/kullanici-adi (kural motoru)
// ===========================================================================
const kullaniciAdiDegistir = kur(
  [...SUZGEC, 'KULLANICI_ADI_KILIT_GUN', 'KULLANICI_ADI_REZERV_GUN', 'GUN_MS',
    'kullaniciAdiKalanGun', 'adRezerveMi', 'kullaniciAdiDegistir'],
  {}, 'kullaniciAdiDegistir');

test('AD DEĞİŞTİRME: yasaklı ad 400 + AD_AYRILMIS — işlem hiç AÇILMIYOR', async () => {
  for (const [ad, neden] of YAKALANMALI) {
    if (ad !== ad.toLowerCase()) continue; // motor girdiyi zaten küçültüyor
    const s = await kullaniciAdiDegistir(PATLAYAN_HAVUZ, 7, ad);
    assert.equal(s.durum, 400, `${ad} (${neden}) kabul edildi`);
    assert.equal(s.kod, 'AD_AYRILMIS', `${ad} (${neden}) yasak listesine takılmadı`);
  }
});

test('AD DEĞİŞTİRME: BÜYÜK harfli yasaklı ad da yakalanıyor (motor küçültüyor)', async () => {
  // Bu uç, kayıt ucundan farklı olarak girdiyi `.toLowerCase()` ediyor —
  // yani `Admin` kalıptan DÜŞMEZ, doğrudan yasak süzgecine gelir.
  const s = await kullaniciAdiDegistir(PATLAYAN_HAVUZ, 7, '  ADMIN  ');
  assert.equal(s.durum, 400);
  assert.equal(s.kod, 'AD_AYRILMIS');
});

// ===========================================================================
// 4. NORMALLEŞTİRME KARARI — hem yakalanan hem MEŞRU örnek
// ===========================================================================
test('normalleştirme: ayırıcı + leet YAKALIYOR', () => {
  for (const [ad, neden] of YAKALANMALI) {
    assert.ok(yasakliKullaniciAdi(ad), `yakalanmadı: ${ad} (${neden})`);
  }
});

test('normalleştirme AŞIRI DEĞİL: `admiral` gibi meşru adlar geçiyor', () => {
  // Karar: TAM EŞİTLİK (alt dize değil). Alt dize olsaydı `yardimsever`,
  // `sistemli`, `destekci` gibi meşru adlar da düşerdi.
  for (const ad of MESRU) {
    assert.equal(yasakliKullaniciAdi(ad), null, `haksız yere yasaklandı: ${ad}`);
  }
});

test('normalleştirme SINIRI: Levenshtein/benzerlik YOK — `admln` serbest', () => {
  // Kasıtlı sınır: eşiksiz "benzer" tanımı yanlış pozitif üretir ve kullanıcıya
  // açıklanamaz. Yalnız TARTIŞMASIZ dönüşümler (ayırıcı, altı leet eşlemesi).
  assert.equal(yasakliKullaniciAdi('admln'), null);
  assert.equal(yasakliKullaniciAdi('adnim'), null);
  // Buna karşılık listedeki altı rakam TARTIŞMASIZ sayılıyor:
  assert.ok(yasakliKullaniciAdi('h3lp'));
  assert.ok(yasakliKullaniciAdi('5taff'));
});

test('boş/anlamsız girdi süzgeci PATLATMIYOR (iskelet boşalabilir)', () => {
  // `1234` → sondaki rakamlar atılınca BOŞ dize kalır; boş dize hiçbir şeye
  // eşit olmamalı ve `''.includes(marka)` tuzağına düşülmemeli.
  for (const x of [null, undefined, '', '   ', '1234', '0', '.-_']) {
    assert.equal(yasakliKullaniciAdi(x), null, `boş iskelet yasak sandı: ${x}`);
  }
});

// ===========================================================================
// 5. MEVCUT KULLANICI KİLİTLENMİYOR — kural YALNIZ yeni atamada
// ===========================================================================
test('MEVCUT `admin` hesabı adını DEĞİŞTİREBİLİYOR (eski ad yeniden doğrulanmıyor)', async () => {
  // Canlıda böyle bir hesap olup olmadığını göremiyoruz (ssh yok). Kod bu
  // durumda kilitlenmemeli: doğrulanan şey YENİ addır, mevcut ad değil.
  const gunluk = [];
  const istemci = {
    async query(sql, par) {
      const duz = String(sql).replace(/\s+/g, ' ').trim();
      gunluk.push(duz);
      if (/FROM kullanicilar WHERE id = \$1 FOR UPDATE/.test(duz)) {
        return { rows: [{ kullanici_adi: 'admin', kullanici_adi_degisim: null, misafir: false }] };
      }
      if (/^UPDATE kullanicilar/.test(duz)) {
        return { rows: [{ id: 7, kullanici_adi: par[0], email: 'a@b.tr',
          misafir: false, kullanici_adi_degisim: new Date().toISOString() }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const s = await kullaniciAdiDegistir({ connect: async () => istemci }, 7, 'alicihan');
  assert.equal(s.durum, 200, 'yasaklı adı TAŞIYAN hesap kilitlendi');
  assert.equal(s.onceki_ad, 'admin');
  assert.ok(gunluk.includes('COMMIT'));
});

test('BAĞLA: kullanıcı adı GÖNDERİLMEZSE mevcut ad yeniden doğrulanmıyor', async () => {
  // Misafirin mevcut adı `misafir_...` — yani listede. Bağlama isteği ad
  // taşımıyorsa (COALESCE) hesap kilitlenmemeli.
  let baglandi = false;
  const istemci = {
    async query(sql) {
      if (/^UPDATE kullanicilar/.test(String(sql).trim())) {
        baglandi = true;
        return { rows: [{ id: 7, kullanici_adi: 'misafir_deadbeef',
          email: 'a@b.tr', misafir: false }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const uc = baglaUcu({
    bcrypt: { hash: async () => 'h' },
    havuz: {
      query: async () => ({ rows: [{ misafir: true }] }),
      connect: async () => istemci,
    },
  });
  const res = sahteYanit();
  await uc({ body: { email: 'a@b.tr', sifre: 'sifre123' }, kullanici: { id: 7 } }, res);
  assert.equal(res.kod, 200, 'ad göndermeyen bağlama isteği reddedildi');
  assert.ok(baglandi, 'bağlama UPDATE\'i hiç çalışmadı');
});

test('GİRİŞ yolu yasak süzgecine HİÇ uğramıyor (mevcut hesap giriş yapabilir)', () => {
  const bas = KAYNAK.indexOf("app.post('/auth/giris'");
  assert.notEqual(bas, -1);
  const govde = KAYNAK.slice(bas, KAYNAK.indexOf("app.post('/auth/", bas + 10));
  assert.doesNotMatch(govde, /yasakliKullaniciAdi/,
    'giriş ucu adı yeniden doğruluyor — listeye giren adı taşıyan hesap kilitlenir');
  assert.doesNotMatch(govde, /KULLANICI_ADI_KALIBI/);
});

test('süzgeç SADECE üç yeni-atama noktasında çağrılıyor (okuma yolları temiz)', () => {
  const cagri = KAYNAK.match(/yasakliKullaniciAdi\(/g) || [];
  // 1 tanım + 3 çağrı. Dördüncü bir çağrı çıkarsa muhtemelen bir OKUMA yolunu
  // doğrulamaya başlamışızdır ve mevcut kullanıcı kilitlenir.
  assert.equal(cagri.length, 4,
    `yasakliKullaniciAdi çağrı sayısı beklenenden farklı: ${cagri.length}`);
});

// ===========================================================================
// 6. AI HESABI — kimlik ADDA DEĞİL, `kullanicilar.ai` SÜTUNUNDA
// ===========================================================================
test('server.js\'te `dizi.jpg.ai` KİMLİK OLARAK karşılaştırılmıyor', () => {
  // Satır BAŞINDA bildirim aranıyor: dosyadaki gerekçe yorumu eski sabitin
  // adını ANIYOR ve düz arama kendi yorumumuza takılırdı.
  assert.doesNotMatch(KAYNAK, /^const AI_KULLANICI\s*=/m,
    'AI_KULLANICI sabiti geri gelmiş — kimlik yine ada bağlı');
  assert.doesNotMatch(KAYNAK, /kullanici_adi\s*(===|!==|<>|=)\s*\$?\d*['"]?dizi\.jpg\.ai/);
});

const akisSatiri = kur(
  ['ceviriUygula', 'akisSatiri'],
  { istekBaglam: { getStore: () => ({ dil: 'tr' }) } },
  'akisSatiri');

test('AKIŞ: AI hesabının ADI DEĞİŞSE DE spoiler muafiyeti sürüyor', () => {
  // Hesap `dizi.jpg.ai` → `yapayzeka.hesabi` olarak yeniden adlandırıldı.
  // Eski kodda (`kullanici_adi === AI_KULLANICI`) bu satır ANINDA bulanıklaşırdı.
  const satir = akisSatiri({
    id: 1, tur: 'tv', sezon: 1, bolum: 1, kullanici_adi: 'yapayzeka.hesabi',
    ai_hesap: true, guvenli: false, spoiler_isaret: false,
  });
  assert.equal(satir.spoiler, false, 'ad değişince AI muafiyeti kayboldu');
});

test('AKIŞ: adı KAPAN sahtekâr muafiyet ALMIYOR', () => {
  // Yasak listesi bunu zaten engelliyor; bu test İKİNCİ katmanı sınıyor —
  // yasaktan önce açılmış bir hesap o adı taşısa bile muafiyet almamalı.
  const satir = akisSatiri({
    id: 2, tur: 'tv', sezon: 1, bolum: 1, kullanici_adi: 'dizi.jpg.ai',
    ai_hesap: false, guvenli: false, spoiler_isaret: false,
  });
  assert.equal(satir.spoiler, true, 'adı kapan hesap AI muafiyeti aldı');
});

test('AKIŞ: AI kendi gönderisini SPOİLER işaretlerse yine bulanık', () => {
  const satir = akisSatiri({
    id: 3, tur: 'tv', sezon: 1, bolum: 1, kullanici_adi: 'dizi.jpg.ai',
    ai_hesap: true, guvenli: false, spoiler_isaret: true,
  });
  assert.equal(satir.spoiler, true);
});

test('AKIŞ: `ai_hesap` yanıt sözleşmesine SIZMIYOR', () => {
  const satir = akisSatiri({
    id: 4, tur: 'tv', kullanici_adi: 'x', ai_hesap: true,
    guvenli: true, spoiler_isaret: false,
  });
  assert.ok(!('ai_hesap' in satir), 'iç kimlik bayrağı istemciye gidiyor');
  assert.ok(!('guvenli' in satir));
});

// ---------------------------------------------------------------------------
// AI NOKTASI 1/4 — GET /yorumlar/:tur/:tmdbId (otomatik spoiler perdesi)
// ---------------------------------------------------------------------------
test('YORUMLAR SQL: muafiyet `NOT k.ai` — ad artık PARAMETRE bile değil', async () => {
  let yakalanan = null;
  const uc = kur(
    // ETIKET_ALANI 30 Ağu 2026'da eklendi: uç artık gönderinin TÜM
    // etiketlerini (`yorum_etiketleri`) de döndürüyor ve sorgu metnine o
    // sabitten yerleşiyor. Bildirilmezse `new Function` gövdesi
    // "ETIKET_ALANI is not defined" ile patlar.
    ['YORUM_TURLERI', 'ETIKET_ALANI', 'engelSuzgec'],
    {
      havuz: { query: async (sql, par) => { yakalanan = { sql, par }; return { rows: [] }; } },
      istekBaglam: { getStore: () => ({ dil: 'tr' }) },
      gorunumKaydet: () => {},
      ceviriUygula: (r) => r,
      // 30 Ağu 2026: uç, etiketlerin ad/posterini de döndürüyor. Bu testin
      // konusu SORGU METNİ; TMDB'ye giden yanıt yükü değil, o yüzden taklit.
      akisIcerikleri: async () => ({}),
    },
    ucIsleyiciKaynagi('get', '/yorumlar/:tur/:tmdbId'));

  const res = sahteYanit();
  await uc({ params: { tur: 'tv', tmdbId: '1396' }, query: {}, ip: '1.2.3.4' }, res);

  assert.ok(yakalanan, 'sorgu hiç çalışmadı');
  const duz = sqlSadeles(yakalanan.sql);
  assert.match(duz, /AND NOT k\.ai/, 'spoiler muafiyeti `ai` sütununa bağlı değil');
  assert.doesNotMatch(duz, /k\.kullanici_adi <> \$/, 'ad karşılaştırması geri gelmiş');
  assert.doesNotMatch(duz, /tohum/,
    '17 hesaplık `tohum` kümesi AI sanılmış — 15 intl persona muaf olur, SPOİLER SIZAR');
  // Kullanılmayan parametre Postgres'te "could not determine data type" ile patlar.
  assert.equal(yakalanan.par.length, 6, 'parametre sayısı değişmiş');
  assert.ok(!yakalanan.par.includes('dizi.jpg.ai'), 'ad hâlâ parametre olarak gidiyor');
  assert.doesNotMatch(duz, /\$7/, '$7 sorguda duruyor ama artık gönderilmiyor');
});

// ---------------------------------------------------------------------------
// AI NOKTASI 2/4 — panel ölçümü `ai_gonderi`
// ---------------------------------------------------------------------------
test('ÖLÇÜM SQL: `ai_gonderi` TEK hesabı sayıyor (`k.ai`), 17 tohumu değil', async () => {
  let yakalanan = null;
  const olcumHesapla = kur(
    ['ALG_OLCUM_SQL', 'olcumHesapla'],
    {
      havuz: { query: async (sql, par) => { yakalanan = { sql, par }; return { rows: [{}] }; } },
      ARSIV_YAS_SAAT,
    },
    'olcumHesapla');
  await olcumHesapla();

  const duz = sqlSadeles(yakalanan.sql);
  assert.match(duz, /WHERE k\.ai\)::int AS ai_gonderi/);
  assert.doesNotMatch(duz, /k\.kullanici_adi = \$/, 'ad karşılaştırması geri gelmiş');
  assert.doesNotMatch(duz, /k\.tohum/,
    'panel "dizi.jpg.ai hesabına ait" diyor ama 17 hesabı sayıyor olurdu');
  assert.deepEqual(yakalanan.par, [ARSIV_YAS_SAAT], 'parametre listesi ada bağlı');
});

// ---------------------------------------------------------------------------
// AI NOKTASI 3/4 — sıralama aday sorgusu (`ai_payi` tavanı)
// ---------------------------------------------------------------------------
test('ADAY SQL: `ai_payi` tavanı `k.ai` sütunundan besleniyor', async () => {
  let yakalanan = null;
  const istemci = {
    async query(sql, par) {
      if (/^SELECT/.test(String(sql).trim())) yakalanan = { sql, par };
      return { rows: [] };
    },
    release() {},
  };
  const adaylariGetir = kur(
    ['engelSuzgec', 'AKIS_GOVDE', 'AKIS_KURAL', 'KESFET_VIDEOLU', 'KESFET_KAT',
      'KESFET_MEDYALI', 'ADAY_AZAMI', 'adaylariGetir'],
    {
      havuz: { connect: async () => istemci },
      yazarKaliteleri: async () => new Map(),
      ARSIV_YAS_SAAT,
    },
    'adaylariGetir');

  await adaylariGetir({ benId: 7, dil: 'tr', kadro: [], hacim: { pay: {} } });

  assert.ok(yakalanan, 'aday sorgusu çalışmadı');
  const duz = sqlSadeles(yakalanan.sql);
  assert.match(duz, /k\.ai AS ai/, '`ai` bayrağı sütundan gelmiyor');
  assert.doesNotMatch(duz, /kullanici_adi = \$4/, 'ad karşılaştırması geri gelmiş');
  assert.doesNotMatch(duz, /tohum/,
    'tavan 17 hesap arasında paylaştırılıyor — panelin kolu başka iş yapar');
  assert.equal(yakalanan.par.length, 3, 'kullanılmayan $4 parametresi geri gelmiş');
  assert.ok(!yakalanan.par.includes('dizi.jpg.ai'));
});

// ---------------------------------------------------------------------------
// AI NOKTASI 4/4 — akış SELECT'i (`akisSatiri`nin girdisi)
// ---------------------------------------------------------------------------
test('AKIŞ SELECT: `k.ai AS ai_hesap` seçiliyor — yoksa muafiyet SESSİZCE ölür', () => {
  const alanlar = bildirimCek('AKIS_ALANLAR');
  assert.match(alanlar, /k\.ai AS ai_hesap/);
  assert.doesNotMatch(alanlar, /tohum/);
});

// ===========================================================================
// 7. `tohum` (17) ≠ `ai` (1) — ayrım her iki yönde de korunuyor
// ===========================================================================
test('`tohum` süzgeci BOZULMADI: SEO/puan yolları hâlâ tohuma bakıyor', () => {
  // Karşı hata: "hepsini `ai`ye çevirelim" denip tohum süzgecinin delinmesi.
  // O zaman 15 intl personanın puanı yeniden `aggregateRating`e girerdi.
  assert.match(KAYNAK, /tk\.id = \$\{alias\}\.kullanici_id AND tk\.tohum/,
    'toplum puanı tohum süzgecini kaybetmiş');
  assert.match(KAYNAK, /r\.tohum \? 'Organization' : 'Person'/,
    'schema.org yazar tipi tohum süzgecini kaybetmiş');
});

test('migrasyon: `ai` TEK hesaba veriliyor ve `tohum`u ezmiyor', () => {
  assert.match(MIGRASYON_KOMUTLARI, /ADD COLUMN IF NOT EXISTS ai BOOLEAN NOT NULL DEFAULT false/);
  // İşaretleme adla YAPILIYOR ve bu adın SON kimlik kullanımı — tek satır.
  assert.match(MIGRASYON_KOMUTLARI,
    /SET ai = true\s+WHERE NOT ai\s+AND kullanici_adi = 'dizi\.jpg\.ai'/);
  // 17 tohum hesabının HİÇBİRİ toplu olarak `ai` yapılmıyor.
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /SET ai = true[^;]*tohum\s*(=|IS)/i);
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /SET ai = true[^;]*intl\.dizijpg\.invalid/);
  // Ters yön: AI hesabı tohum olarak KALIYOR (SEO süzgeci onu dışlamalı).
  assert.match(MIGRASYON_KOMUTLARI, /SET tohum = true WHERE ai AND NOT tohum/);
});

test('AI hesabı BİR TANEDİR: kısmi tekil indeks bunu veritabanında garanti ediyor', () => {
  for (const parca of [
    /ai BOOLEAN NOT NULL DEFAULT false/,
    /CREATE UNIQUE INDEX IF NOT EXISTS kullanicilar_tek_ai\s+ON kullanicilar \(\(ai\)\) WHERE ai/,
  ]) {
    assert.match(SEMA, parca, `sema.sql'de eksik: ${parca}`);
    assert.match(MIGRASYON_KOMUTLARI, parca, `migrasyonda eksik: ${parca}`);
  }
  // `tohum` ayrı sütun olarak DURUYOR — birleştirilmedi.
  assert.match(SEMA, /tohum BOOLEAN NOT NULL DEFAULT false/);
});

test('migrasyon İDEMPOTENT ve YIKICI DEĞİL', () => {
  assert.match(MIGRASYON_KOMUTLARI, /ADD COLUMN IF NOT EXISTS/);
  assert.match(MIGRASYON_KOMUTLARI, /WHERE NOT ai/);
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /DROP (TABLE|COLUMN|INDEX)/i);
  assert.doesNotMatch(MIGRASYON_KOMUTLARI, /DELETE FROM/i);
  // DEFAULT false: yükseltme anında hiçbir gerçek hesap AI sayılmaz.
  assert.match(MIGRASYON_KOMUTLARI, /ai BOOLEAN NOT NULL DEFAULT false/);
});

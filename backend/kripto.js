// Özel mesajların DURAĞAN ŞİFRELENMESİ (at-rest) — SAF modül.
//
// `cevrimici.js` ile aynı kalıp: burada Express de, `pg` de, `process.env` de
// yok. Modül içe aktarıldığında HİÇBİR yan etki olmaz (anahtar okunmaz, hata
// atılmaz). Böylece `backend/test/kripto.test.js` gerçek fonksiyonları çağırıp
// davranışı ölçebilir — kaynak metnine regex tutturmak değil.
//
// ---------------------------------------------------------------------------
// NEYİ KORUR, NEYİ KORUMAZ  (belgelerde de AYNI cümleyi kur; abartma)
// ---------------------------------------------------------------------------
// KORUR:  çalınmış veritabanı dökümü, çalınmış gece yedeği (`/opt/dizijpg/
//         yedekler/*.sql.gz`), diske/volume'a erişen ama uygulama sırlarına
//         erişemeyen saldırgan. Yedek betiği YALNIZ `pg_dump` alıyor
//         (`/opt/dizijpg/yedek.sh` — doğrulandı), yani anahtar yedeğin İÇİNE
//         GİRMİYOR: döküm tek başına işe yaramaz.
// KORUMAZ: sunucunun tamamen ele geçirilmesi. Anahtar `/opt/dizijpg/.env`
//         içinde ve API süreci onu belleğe alıyor; root olan biri hem anahtarı
//         hem veriyi alır. Uçtan uca şifreleme DEĞİLDİR — sunucu içeriği
//         çözebilir (moderasyon, push önizlemesi, sohbet listesi önizlemesi ve
//         web istemcisi bu yüzden aynen çalışmaya devam eder).
//
// ---------------------------------------------------------------------------
// ZARF BİÇİMİ
// ---------------------------------------------------------------------------
//   v1.k1.<iv>.<etiket>.<sifreli>
//   \/ \/  \_____ base64url, dolgusuz (padding yok) _____/
//    |  |
//    |  +-- ANAHTAR KİMLİĞİ: hangi anahtarla yazıldı. Anahtar döndürmenin
//    |      (rotation) tek şartı budur; kimlik olmasaydı eski anahtarla
//    |      yazılmış satırı yeni anahtar devredeyken çözmenin yolu kalmazdı.
//    +----- SÜRÜM: ileride algoritma/parametre değişirse (ör. anahtar
//           türetme eklenirse) v2 yazılır, v1 satırlar okunmaya devam eder.
//
// Ayraç olarak '.' güvenli: base64url alfabesi [A-Za-z0-9_-] noktayı İÇERMEZ,
// yani parça sayısı her zaman tam 5'tir.
//
// AAD (ek doğrulanmış veri) = "v1.k1" yani zarfın BAŞLIĞI. Başlık şifrelenmez
// ama kimlik doğrulamaya girer: birisi `v1.k2.…` diye kimliği değiştirirse ya
// da sürümü düşürmeye çalışırsa GCM etiketi tutmaz ve `coz()` HATA verir.
// (Satır kimliğini AAD'ye koymadık: `mesajlar.id` SERIAL, INSERT anında henüz
// yok. Yani DB'ye YAZABİLEN biri şifreli metni satırdan satıra kopyalayabilir —
// bu, "sunucu ele geçirilirse korumuyoruz" sınırının içinde kalır.)
//
// ---------------------------------------------------------------------------
// KARIŞIK DÖNEM (düz metin + şifreli aynı kolonda)
// ---------------------------------------------------------------------------
// Geri doldurma bitene kadar `mesajlar.metin` içinde hem eski DÜZ METİN hem
// yeni ZARF satırlar bulunur. `coz()` zarf görmediği değeri düz metin sayıp
// AYNEN döndürür.
//
// Peki kullanıcı mesaj olarak `v1.k1.…` yazarsa? İki ayrı savunma var:
//  1) YAZMA YOLUNDA: `sifrele()` her şeyi şifreler. Kullanıcının yazdığı metin
//     ham hâliyle kolona HİÇ girmez; zarfın İÇİNDE durur. `coz()` bir kez
//     çözer ve sonucu TEKRAR ayrıştırmaz (özyineleme yok), böylece o metin
//     kullanıcıya harfi harfine geri döner.
//  2) OKUMA YOLUNDA: `sifreliMi()` yalnız ön eke bakmaz — parça sayısı (5),
//     anahtar kimliği kalıbı, IV'nin TAM 12 bayt, etiketin TAM 16 bayt olması,
//     alfabenin base64url olması ve her parçanın KANONİK base64url olması
//     (yeniden kodlayıp karşılaştırıyoruz) aranır. Rastgele bir insan
//     cümlesinin bunu tutturma olasılığı yok denecek kadar azdır.
// Geriye tek bir delik kalır: geri doldurmadan ÖNCE yazılmış, kasten zarf gibi
// biçimlendirilmiş bir düz metin satır. Canlıda böyle satır YOK (7 Ağu 2026:
// `SELECT count(*) FROM mesajlar WHERE metin LIKE 'v_.%'` -> 0) ve geri
// doldurma betiği bu satırları ayrıca raporlar.

import crypto from 'node:crypto';

/** Zarfın sürüm etiketi. Biçim değişirse burası artar; v1 okunmaya devam eder. */
export const ZARF_SURUM = 'v1';

/** AES-256-GCM: IV 12 bayt (GCM'in önerilen/en verimli boyutu). */
export const IV_UZUNLUK = 12;

/** GCM kimlik doğrulama etiketi: 16 bayt (tam güç; kırpılmış etiket yok). */
export const ETIKET_UZUNLUK = 16;

/** AES-256 → anahtar tam 32 bayt olmak zorunda. */
export const ANAHTAR_UZUNLUK = 32;

/** Anahtar kimliği kalıbı: k1, k2, … k999. */
const KIMLIK_KALIP = /^k[1-9][0-9]{0,2}$/;

/** base64url alfabesi (dolgusuz). '.' ve '=' bilerek DIŞARIDA. */
const B64URL_KALIP = /^[A-Za-z0-9_-]+$/;

const b64 = (buf) => buf.toString('base64url');

/**
 * base64url çözer ve KANONİK olduğunu doğrular.
 * Node'un çözücüsü hoşgörülüdür (geçersiz karakteri atlar, dolgusuzu kabul
 * eder); bu yüzden çözdükten sonra YENİDEN KODLAYIP karşılaştırıyoruz.
 * Böylece "aynı baytlara çözülen ama farklı yazılmış" ikinci bir gösterim
 * zarf sayılmaz — `sifreliMi()`nin yanlış pozitif vermemesi buna dayanır.
 * @returns {Buffer|null}
 */
function b64Coz(metin, beklenenBayt = null) {
  if (typeof metin !== 'string' || metin.length === 0) return null;
  if (!B64URL_KALIP.test(metin)) return null;
  // base64'te 4'e bölümünden kalan 1 olan uzunluk hiçbir zaman geçerli değildir.
  if (metin.length % 4 === 1) return null;
  const buf = Buffer.from(metin, 'base64url');
  if (buf.toString('base64url') !== metin) return null;
  if (beklenenBayt != null && buf.length !== beklenenBayt) return null;
  return buf;
}

/**
 * Zarfı ayrıştırır. Zarf DEĞİLSE `null` döner (hata atmaz) — çünkü "zarf
 * değil" karışık dönemde NORMAL bir durumdur: o satır düz metindir.
 * @returns {{surum:string, kimlik:string, iv:Buffer, etiket:Buffer,
 *            sifreli:Buffer, baslik:string}|null}
 */
export function zarfAyristir(deger) {
  if (typeof deger !== 'string') return null;
  // Hızlı eleme: satırların %99'u ya düz metin ya v1 zarfı.
  if (!deger.startsWith(ZARF_SURUM + '.')) return null;
  const parcalar = deger.split('.');
  if (parcalar.length !== 5) return null;
  const [surum, kimlik, ivMetin, etiketMetin, sifreliMetin] = parcalar;
  if (surum !== ZARF_SURUM) return null;
  if (!KIMLIK_KALIP.test(kimlik)) return null;
  const iv = b64Coz(ivMetin, IV_UZUNLUK);
  if (!iv) return null;
  const etiket = b64Coz(etiketMetin, ETIKET_UZUNLUK);
  if (!etiket) return null;
  // Şifreli gövde BOŞ OLAMAZ: boş metni hiç şifrelemiyoruz (aşağıya bakın),
  // dolayısıyla gövdesi boş bir zarf bizim ürettiğimiz bir şey değildir.
  const sifreli = b64Coz(sifreliMetin);
  if (!sifreli || sifreli.length === 0) return null;
  return { surum, kimlik, iv, etiket, sifreli, baslik: `${surum}.${kimlik}` };
}

/**
 * Bu değer BİZİM ürettiğimiz bir zarf mı? (İçeriğin çözülebildiğini
 * söylemez — yalnız biçimin kanonik olduğunu söyler.)
 */
export function sifreliMi(deger) {
  return zarfAyristir(deger) !== null;
}

// ---------------------------------------------------------------------------
// Anahtarlar
// ---------------------------------------------------------------------------

/**
 * Tek bir anahtarı çözer ve boyunu doğrular.
 * base64 ve base64url'ün ikisi de kabul edilir (parola yöneticisinden
 * kopyalarken '+/' mi '-_' mi geldiğine kullanıcı takılmasın).
 */
function anahtarBaytlari(metin, nerede) {
  const temiz = String(metin || '').trim();
  if (!temiz) throw new Error(`${nerede}: anahtar boş`);
  const buf = Buffer.from(temiz, 'base64');
  if (buf.length !== ANAHTAR_UZUNLUK) {
    throw new Error(
      `${nerede}: anahtar ${buf.length} bayt çözüldü, ${ANAHTAR_UZUNLUK} bayt olmalı ` +
      `(üretmek için: openssl rand -base64 32)`);
  }
  return buf;
}

/**
 * "k2:<base64>" ya da "<base64>" biçimini ayrıştırır.
 * Kimlik yazılmamışsa `varsayilanKimlik` kullanılır — kullanıcı .env'e sadece
 * anahtarı yapıştırdığında da çalışsın diye.
 */
function anahtarGirdisiCoz(girdi, varsayilanKimlik, nerede) {
  const temiz = String(girdi || '').trim();
  const ikiNokta = temiz.indexOf(':');
  let kimlik = varsayilanKimlik;
  let govde = temiz;
  if (ikiNokta > 0 && KIMLIK_KALIP.test(temiz.slice(0, ikiNokta))) {
    kimlik = temiz.slice(0, ikiNokta);
    govde = temiz.slice(ikiNokta + 1);
  }
  if (!KIMLIK_KALIP.test(kimlik)) {
    throw new Error(`${nerede}: geçersiz anahtar kimliği "${kimlik}" (k1..k999 olmalı)`);
  }
  return { kimlik, anahtar: anahtarBaytlari(govde, nerede) };
}

/**
 * Ortam değişkenlerinden anahtar takımını kurar.
 *
 *   MESAJ_ANAHTARI       AKTİF anahtar. "k2:<base64 32 bayt>" veya "<base64>"
 *                        (kimliksiz yazılırsa k1 sayılır). YENİ YAZMALAR bununla.
 *   MESAJ_ANAHTARI_ESKI  Yalnız OKUMA için eski anahtarlar; virgülle ayrılır,
 *                        her biri kimlikli olmak ZORUNDA: "k1:<b64>,k2:<b64>".
 *   MESAJ_SIFRELEME      "kapali" ise anahtarsız çalışmaya İZİN verilir.
 *
 * ANAHTAR YOKKEN NE OLUR — bilinçli karar:
 *   `MESAJ_SIFRELEME=kapali` YAZILMADIKÇA bu fonksiyon HATA ATAR. Çağıran
 *   (server.js) bunu açılışta yapar ve süreç ölür. Gerekçe: sessizce düz metne
 *   düşmek en tehlikeli sonuçtur — şifreleme kapanır, hiçbir uç hata vermez,
 *   aylarca kimse fark etmez ve yedek yine düz metin dolar. Yüksek sesle
 *   ölmek, sessizce korumasız kalmaktan iyidir.
 *   Buna karşılık üretimde çalışan servisi kilitlememek için AÇIK bir kaçış
 *   var: `MESAJ_SIFRELEME=kapali`. Bu bir bayrak, bir kaza değil — .env'e o
 *   satırı yazan kişi ne yaptığını bilir ve `docker logs`ta uyarıyı görür.
 *
 * @returns {{aktif:{kimlik:string,anahtar:Buffer}|null,
 *            hepsi:Map<string,Buffer>, acik:boolean}}
 */
export function anahtarYukle(env = {}) {
  const kapali = String(env.MESAJ_SIFRELEME || '').trim().toLowerCase() === 'kapali';
  const ham = String(env.MESAJ_ANAHTARI || '').trim();
  const hepsi = new Map();

  for (const parca of String(env.MESAJ_ANAHTARI_ESKI || '').split(/[,\s]+/)) {
    if (!parca.trim()) continue;
    if (!/^k[1-9][0-9]{0,2}:/.test(parca.trim())) {
      throw new Error(
        'MESAJ_ANAHTARI_ESKI: her anahtar "kN:<base64>" biçiminde olmalı ' +
        '(kimliksiz eski anahtarın hangi satırları açtığı bilinemez)');
    }
    const { kimlik, anahtar } = anahtarGirdisiCoz(parca, null, 'MESAJ_ANAHTARI_ESKI');
    hepsi.set(kimlik, anahtar);
  }

  if (!ham) {
    if (!kapali) {
      throw new Error(
        'MESAJ_ANAHTARI tanımlı değil. Özel mesajlar şifresiz yazılacaktı; ' +
        'bu yüzden AÇILIŞ DURDURULDU.\n' +
        '  Anahtar üret : openssl rand -base64 32\n' +
        '  /opt/dizijpg/.env -> MESAJ_ANAHTARI=<üretilen>\n' +
        '  docker-compose.yml -> api.environment: MESAJ_ANAHTARI: ${MESAJ_ANAHTARI}\n' +
        '  Bilerek şifresiz çalışacaksan: MESAJ_SIFRELEME=kapali');
    }
    return { aktif: null, hepsi, acik: false };
  }

  const aktif = anahtarGirdisiCoz(ham, 'k1', 'MESAJ_ANAHTARI');
  const eski = hepsi.get(aktif.kimlik);
  if (eski && !eski.equals(aktif.anahtar)) {
    // Aynı kimlikte iki FARKLI anahtar: hangisinin doğru olduğu bilinemez,
    // yanlış olanı seçmek satırları okunamaz gösterir. Erken ve gürültülü öl.
    throw new Error(
      `Anahtar kimliği çakışması: "${aktif.kimlik}" hem MESAJ_ANAHTARI hem ` +
      'MESAJ_ANAHTARI_ESKI içinde ve değerler farklı. Yeni anahtara YENİ bir ' +
      'kimlik ver (k1 -> k2).');
  }
  hepsi.set(aktif.kimlik, aktif.anahtar);
  return { aktif, hepsi, acik: true };
}

// Modül düzeyinde varsayılan takım. İÇE AKTARMA sırasında DOLDURULMAZ;
// server.js açılışta `baslat(process.env)` çağırır. Testler ise takımı
// doğrudan parametre olarak geçebilir (küresel duruma bağımlı test yok).
let varsayilan = null;

/**
 * Açılışta bir kez çağrılır. Anahtar yoksa ve kaçış bayrağı da yoksa HATA
 * ATAR — çağıran süreci sonlandırmalıdır (server.js yaması bunu yapar).
 */
export function baslat(env = {}) {
  varsayilan = anahtarYukle(env);
  return varsayilan;
}

/** Test/araç kodu için: varsayılan takımı elle koy ya da (null ile) temizle. */
export function anahtarlariAyarla(takim) {
  varsayilan = takim;
  return varsayilan;
}

/** Şu anki varsayılan takım (kurulmadıysa null). */
export function anahtarlar() {
  return varsayilan;
}

function takimAl(verilen) {
  const takim = verilen || varsayilan;
  if (!takim) {
    throw new Error(
      'kripto: anahtar takımı kurulmadı — açılışta baslat(process.env) çağrılmalı');
  }
  return takim;
}

// ---------------------------------------------------------------------------
// Şifrele / çöz
// ---------------------------------------------------------------------------

/**
 * Düz metni zarfa koyar.
 *
 *  - `null`/`undefined` -> `null`. `mesajlar.metin` NULL OLABİLİR: sesli
 *    mesaj, medya ve içerik kartı gönderimlerinde POST /mesajlar `temiz ||
 *    null` yazıyor (server.js). NULL'u zarfa sokmak, "metni olmayan mesaj"
 *    ile "metni boş mesaj" ayrımını bozardı.
 *  - `''` -> `''`. Boş metin sır taşımaz; şifrelemek 48 baytlık bir zarfın
 *    içinde HİÇBİR ŞEY saklamak olurdu. (Zaten POST /mesajlar boş metni NULL
 *    yapıyor; bu dal yalnız savunma amaçlı.)
 *  - Şifreleme KAPALIYSA (anahtar yok + MESAJ_SIFRELEME=kapali) metin AYNEN
 *    döner. Sessiz değil: bu duruma ancak .env'e o bayrağı yazarak düşülür.
 *
 * Her çağrıda YENİ rastgele IV üretilir. Aynı metin iki kez şifrelendiğinde
 * çıktılar farklıdır; yoksa "iki kişi aynı şeyi yazmış" bilgisi şifreli
 * dökümden bile okunurdu (ve GCM'de IV tekrarı anahtarı yakar).
 */
export function sifrele(metin, takim = null) {
  if (metin == null) return null;
  const m = String(metin);
  if (m.length === 0) return '';
  const t = takimAl(takim);
  if (!t.acik || !t.aktif) return m;             // şifreleme bilerek kapalı
  const iv = crypto.randomBytes(IV_UZUNLUK);
  const baslik = `${ZARF_SURUM}.${t.aktif.kimlik}`;
  const sifreleyici = crypto.createCipheriv('aes-256-gcm', t.aktif.anahtar, iv);
  sifreleyici.setAAD(Buffer.from(baslik, 'utf8'));
  const govde = Buffer.concat([
    sifreleyici.update(m, 'utf8'),
    sifreleyici.final(),
  ]);
  const etiket = sifreleyici.getAuthTag();
  return `${baslik}.${b64(iv)}.${b64(etiket)}.${b64(govde)}`;
}

/**
 * Zarfı açar.
 *
 *  - Zarf DEĞİLSE (karışık dönemin düz metin satırı) değer AYNEN döner.
 *  - Zarfsa ama etiket tutmazsa / anahtar yanlışsa HATA ATAR. Bu bilerek
 *    böyle: bozulmuş ya da oynanmış satırı sessizce yutmak, tespit etmek için
 *    kurduğumuz GCM etiketini çöpe atmak olurdu.
 *  - Çözülen metin TEKRAR ayrıştırılmaz. Kullanıcı mesaj olarak
 *    "v1.k1.<...>" yazmış olsa bile o metin harfi harfine geri döner.
 */
export function coz(deger, takim = null) {
  const zarf = zarfAyristir(deger);
  if (!zarf) return deger;                        // düz metin (ya da null)
  const t = takimAl(takim);
  const anahtar = t.hepsi.get(zarf.kimlik);
  if (!anahtar) {
    throw new Error(
      `Mesaj "${zarf.kimlik}" anahtarıyla şifrelenmiş ama o anahtar yüklü ` +
      'değil. MESAJ_ANAHTARI / MESAJ_ANAHTARI_ESKI eksik.');
  }
  const cozucu = crypto.createDecipheriv('aes-256-gcm', anahtar, zarf.iv);
  cozucu.setAAD(Buffer.from(zarf.baslik, 'utf8'));
  cozucu.setAuthTag(zarf.etiket);
  // final() etiketi doğrular; tutmazsa fırlatır ("Unsupported state or unable
  // to authenticate data"). Mesajı kendi cümlemizle sarıyoruz.
  try {
    return Buffer.concat([cozucu.update(zarf.sifreli), cozucu.final()])
      .toString('utf8');
  } catch {
    throw new Error(
      'Mesaj çözülemedi: kimlik doğrulama etiketi tutmadı (veri bozulmuş, ' +
      'oynanmış ya da anahtar yanlış).');
  }
}

/**
 * `coz()`un ASLA fırlatmayan sürümü — OKUMA UÇLARI BUNU KULLANIR.
 *
 * Neden ayrı bir fonksiyon: tek bozuk satır yüzünden `GET /mesajlar/:ad`in
 * 500 dönmesi, kullanıcının TÜM sohbetini kullanılmaz yapardı. Çözülemeyen
 * satır `null` olur (istemci zaten metinsiz mesajı — sesli/medya — çizebiliyor)
 * ve olay sunucu günlüğüne düşer. Şifreli metin İSTEMCİYE ASLA HAM GİTMEZ.
 */
export function cozGoster(deger, takim = null, gunluk = console.error) {
  try {
    return coz(deger, takim);
  } catch (e) {
    gunluk('kripto.cozGoster:', e.message);
    return null;
  }
}

/**
 * Bir nesnenin verilen alanlarını yerinde çözer (okuma uçlarındaki satır
 * eşlemelerini kısaltır). Nesneyi DEĞİŞTİRİR ve geri döndürür.
 */
export function satirCoz(satir, alanlar = ['metin'], takim = null, gunluk = console.error) {
  if (!satir) return satir;
  for (const alan of alanlar) {
    if (satir[alan] !== undefined) satir[alan] = cozGoster(satir[alan], takim, gunluk);
  }
  return satir;
}

/** Yeni anahtar üretmek için (araç/betik kullanır). base64 döner. */
export function anahtarUret() {
  return crypto.randomBytes(ANAHTAR_UZUNLUK).toString('base64');
}

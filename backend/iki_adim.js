// İki adımlı doğrulama (md. 52) — SAF modül.
//
// `yasak.js` / `kripto.js` ile aynı kalıp: burada ne Express, ne `pg`, ne
// `process.env` var. İçe aktarıldığında hiçbir yan etki olmaz; böylece
// `test/iki_adim.test.js` GERÇEK fonksiyonları çağırıp davranışı ölçer,
// server.js metnine regex tutturmaz.
//
// server.js'te kalan tek şey I/O'dur: DB satırını okumak/yazmak, bcrypt
// hash'lemek ve postayı göndermek. KARAR AĞACI burada.
//
// ---------------------------------------------------------------------------
// TASARIM ÖZETİ (uzun gerekçe: migrasyon-2026-08-14f.sql ve server.js)
// ---------------------------------------------------------------------------
//   · Kod 6 hane, e-postaya gider, 10 dk yaşar, 5 yanlışta İPTAL olur.
//   · Kod DB'de bcrypt ile HASH'li durur; karşılaştırma sabit zamanlıdır.
//   · Giriş ikinci adımını "bilet" taşır: `<kullanici_id>.<32 bayt rastgele>`.
//     Sunucuda yalnız sha256'sı saklanır. Kod doğrulanana kadar OTURUM
//     TOKEN'I VERİLMEZ; şifre istemcide BEKLETİLMEZ.
import crypto from 'crypto';

/** Bir kod kaç YANLIŞ denemeden sonra tamamen iptal edilir. */
export const IKI_ADIM_MAX_DENEME = 5;

/**
 * Kodun (ve giriş biletinin) ömrü, dakika.
 * Şifre sıfırlamada 15; burada 10 — giriş kodu anında girilir, pencere ne
 * kadar darsa o kadar iyi.
 */
export const IKI_ADIM_DK = 10;

/** Kabul edilen kod biçimi: tam 6 rakam. */
export const IKI_ADIM_KOD_DESENI = /^\d{6}$/;

/** Ayarlardan istenebilecek amaçlar. Giriş kodu bu uçtan İSTENMEZ ('giris'). */
export const IKI_ADIM_AMAC = ['ac', 'kapat'];

/**
 * Sabit zamanlı bayt karşılaştırması.
 * `crypto.timingSafeEqual` farklı uzunlukta HATA atar; uzunluk zaten gizli
 * değil (sha256 hep 32 bayt), o yüzden önce uzunluğa bakıp erken çıkıyoruz.
 */
export function esitSabit(a, b) {
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Giriş bileti üretir: `{bilet, hash}`.
 *
 * Bilet `<kullanici_id>.<gizli>` biçimindedir. Kimlik AÇIKTA çünkü sır değil
 * (JWT'de de var) ve satırı tek sorguda bulmayı sağlıyor; güvenlik tamamen
 * `gizli` kısmın 256 bit rastgeleliğinden gelir. Sunucu gizliyi SAKLAMAZ,
 * yalnız sha256'sını tutar — DB sızıntısı oturum vermez.
 */
export function ikiAdimBiletUret(kullaniciId) {
  const gizli = crypto.randomBytes(32).toString('base64url');
  return { bilet: `${kullaniciId}.${gizli}`, hash: biletHashla(gizli) };
}

/** Biletin gizli kısmının sha256'sı (hex). */
export const biletHashla = (gizli) =>
  crypto.createHash('sha256').update(gizli).digest('hex');

/**
 * Bileti çözer: `{id, hash}` ya da biçim bozuksa null.
 * Uzunluk üst sınırı var: 200 karakterden uzun girdi hash'lenmeden reddedilir.
 */
export function ikiAdimBiletCoz(bilet) {
  const s = String(bilet || '');
  if (s.length < 10 || s.length > 200) return null;
  const nokta = s.indexOf('.');
  if (nokta <= 0) return null;
  const id = Number(s.slice(0, nokta));
  const gizli = s.slice(nokta + 1);
  if (!Number.isInteger(id) || id <= 0 || gizli.length < 32) return null;
  return { id, hash: biletHashla(gizli) };
}

/**
 * E-posta ipucu: `ali@gmail.com` → `a•••@gmail.com`.
 *
 * Kullanıcı adıyla giren kişi hangi kutuya bakacağını bilmeyebilir. TAM adres
 * yazılmaz; yerel kısım tek harfe iner. (Buraya YALNIZ doğru şifreyle
 * gelinir — yani bu ipucu saldırgana yeni bilgi vermez.)
 */
export function epostaMaskele(email) {
  const s = String(email || '');
  const at = s.indexOf('@');
  if (at < 1) return '•••';
  return `${s[0]}•••${s.slice(at)}`;
}

/**
 * Doğrulama karar ağacı — `sifre-sifirla` ile AYNI disiplin.
 *
 * @returns {'bicimsiz'|'gecersiz'|'kilit'|'yanlis'|'kabul'}
 *   bicimsiz — 6 hane değil. DENEME HAKKI HARCAMAZ ve DB'ye dokunulmaz:
 *              böyle bir dize zaten hiçbir zaman doğru olamaz, yazım hatası
 *              yüzünden kullanıcıyı kilitlemek anlamsız olurdu.
 *   gecersiz — kayıt yok / amaç tutmuyor / süre dolmuş.
 *   kilit    — sınır aşılmış. KOD DOĞRU OLSA BİLE kabul edilmez; çağıran
 *              satırı SİLER, yani yeniden gönderim şarttır ("biraz bekle"
 *              demekle yetinmeyiz).
 *   yanlis   — hak var, kod tutmadı (çağıran sayacı artırır).
 *   kabul    — geçerli; çağıran satırı siler (TEK KULLANIMLIK).
 *
 * AMAÇ DA KARŞILAŞTIRILIR: kapatma için istenmiş bir kod giriş adımında,
 * giriş kodu da kapatmada kabul edilmez — aksi halde tek bir posta üç kapıyı
 * birden açardı.
 */
export function ikiAdimKarar({
  bicimGecerli, kayitVar, amacUyuyor, suresiDoldu, deneme, kodDogru,
}) {
  if (!bicimGecerli) return 'bicimsiz';
  if (!kayitVar || !amacUyuyor || suresiDoldu) return 'gecersiz';
  if (deneme >= IKI_ADIM_MAX_DENEME) return 'kilit';
  return kodDogru ? 'kabul' : 'yanlis';
}

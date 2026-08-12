// dizi.jpg — küme (cluster) hesapları. SAF MODÜL.
//
// `yasak.js` / `arama.js` / `gunluk.js` ile aynı disiplin: Express, pg ve
// zamanlayıcı yok; `process.env` DOĞRUDAN okunmaz (çağıran enjekte eder).
// Böylece `test/kume.test.js` işçi sayısı ve havuz matematiğini süreç
// açmadan, saniyeler içinde kilitler.
//
// NEDEN VAR (yapilacaklar2 D1): Node tek süreçti ve 16 çekirdeğin 1'ini
// kullanıyordu. `kume.js` birincil süreç olarak N işçi forklar; buradaki
// fonksiyonlar o N'i ve işçi başına pg havuz tavanını hesaplar.

/** Varsayılan işçi sayısı. 16 çekirdekli makinede BİLEREK 4:
 *  aynı makinede Postgres, coturn, nginx ve başka projeler de koşuyor;
 *  ölçülen yük (0.10) için 4 kat kapasite bol bol yeter, işçi başına
 *  önbellek kopyalarının RAM maliyeti de düşük kalır. Gerekirse
 *  `NODE_ISCI` ile artırılır. */
export const VARSAYILAN_ISCI = 4;

/** Postgres `max_connections = 100`. 20 bağlantı superuser yedeği, psql,
 *  yedek betiği ve elle müdahale payıdır — işçilere dağıtılan tavan 80. */
export const HAVUZ_TOPLAM_TAVAN = 80;

/** Tek sürecin bugüne kadarki bilinen-iyi havuz tavanı (server.js `max:30`).
 *  İşçi sayısı ne kadar az olursa olsun bunun ÜSTÜNE ÇIKILMAZ: 30, "/akis
 *  istek başına 20-30 paralel sorgu açar" ölçümünden geliyor; 80'e çıkarmak
 *  davranışı değiştirmek olurdu. */
export const HAVUZ_TEK_SUREC = 30;

/** Bir işçinin ömrü bundan kısaysa ölümü "hızlı ölüm" sayılır ve fren
 *  sayacına girer (açılışta çöken kötü bir dağıtım, fork fırtınası yapmasın). */
export const HIZLI_OLUM_MS = 30_000;

/** Yeniden fork beklemesinin üst sınırı. */
export const FREN_TAVAN_MS = 30_000;

/**
 * İşçi sayısı: `NODE_ISCI` ortam değişkeni, yoksa min(4, çekirdek).
 *
 *   NODE_ISCI=0  → KÜMESİZ kaçış yolu: kume.js server.js'i forksuz,
 *                  doğrudan bu süreçte çalıştırır (bugünkü davranış).
 *   NODE_ISCI>çekirdek → çekirdek sayısına KIRPILIR (çekirdekten fazla
 *                  CPU-bağımlı işçi yalnız bağlam değiştirme masrafıdır).
 *   geçersiz değer → varsayılan (yanlış yazılmış env yüzünden tek işçiye
 *                  ya da sıfıra düşmek sessiz bir kapasite kaybı olurdu).
 *
 * @param {object} env  process.env (test enjekte eder)
 * @param {number} cekirdek  os.cpus().length
 */
export function isciSayisi(env = {}, cekirdek = 1) {
  const ust = Math.max(1, Math.floor(cekirdek) || 1);
  const ham = env.NODE_ISCI;
  if (ham !== undefined && String(ham).trim() !== '') {
    const n = Number(ham);
    if (Number.isInteger(n) && n >= 0) return Math.min(n, ust);
  }
  return Math.min(VARSAYILAN_ISCI, ust);
}

/**
 * İşçi başına pg havuz tavanı (yapilacaklar2 D1'in ⚠ uyarısı):
 * kod `max:30` TEK SÜREÇ içindi; 4 işçi × 30 = 120 > max_connections(100)
 * olur ve API bağlantı tükenmesiyle 500 vermeye başlardı.
 *
 * Kural: işçi_başına = min(30, floor(80 / işçi_sayısı)).
 * `PG_HAVUZ_MAX` ile ezilebilir ama toplam 80'i AŞAMAZ — override bile
 * floor(80/N)'e kırpılır, çünkü buradaki yanlışın bedeli "her uç 500".
 *
 * Değişmez (testle kilitli): her N ve her override için N × sonuç ≤ 80.
 */
export function havuzMax(env = {}, isci = 1) {
  const n = Math.max(1, Math.floor(isci) || 1);
  const isciBasinaTavan = Math.max(1, Math.floor(HAVUZ_TOPLAM_TAVAN / n));
  const ham = Number(env.PG_HAVUZ_MAX);
  if (Number.isInteger(ham) && ham >= 1) return Math.min(ham, isciBasinaTavan);
  return Math.min(HAVUZ_TEK_SUREC, isciBasinaTavan);
}

/**
 * Hızlı-ölüm freni: art arda hızlı ölümlerde yeniden fork'tan önce beklenecek
 * süre. İlk ölüm bedava (tekil çökme normaldir, B1 bunu zaten öngörüyor),
 * sonrası üstel: 1s, 2s, 4s ... 30s tavan. Sayaç, HIZLI_OLUM_MS'ten uzun
 * yaşayan bir işçiyle sıfırlanır.
 */
export function frenMs(ardArdaHizliOlum) {
  const n = Math.max(0, Math.floor(ardArdaHizliOlum) || 0);
  if (n <= 1) return 0;
  return Math.min(FREN_TAVAN_MS, 500 * 2 ** Math.min(n, 10));
}

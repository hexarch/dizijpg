#!/usr/bin/env node
// Mevcut DÜZ METİN özel mesajları AES-256-GCM zarfına taşır (geri doldurma).
//
// ---------------------------------------------------------------------------
// KULLANIM
// ---------------------------------------------------------------------------
//   docker exec -it dizijpg-api node mesaj_sifrele_geri_doldur.js            # KURU ÇALIŞTIRMA
//   docker exec -it dizijpg-api node mesaj_sifrele_geri_doldur.js --uygula   # gerçek
//   docker exec -it dizijpg-api node mesaj_sifrele_geri_doldur.js --dogrula  # okuma denetimi
//   docker exec -it dizijpg-api node mesaj_sifrele_geri_doldur.js --geri --uygula   # GERİ AL
//
// Bayraklar:
//   (bayraksız)   KURU ÇALIŞTIRMA. Hiçbir şey yazılmaz; ne olacağı sayılır.
//                 Varsayılanın kuru olması bilinçli: bu betiği yanlışlıkla
//                 çalıştırmanın bedeli sıfır olmalı.
//   --uygula      Gerçekten yaz. Kuru çalıştırma raporunu okumadan verme.
//   --geri        TERS YÖN: zarfları çözüp DÜZ METİN olarak geri yaz.
//                 (Anahtar kaybı DIŞINDA her senaryodan dönüş yolu budur.)
//   --dogrula     Hiçbir şey yazmaz; her satırı okuyup çözmeyi dener ve
//                 çözülemeyenleri listeler. Dağıtım sonrası kabul testi.
//   --obek N      Öbek boyu (varsayılan 200). Büyük tabloda belleği ve
//                 işlem süresini sınırlar.
//   --baslangic N Bu id'den SONRAKİ satırlardan devam et (kesilirse elle
//                 devam; ama gerek yok — aşağıdaki "yeniden çalıştırılabilir"
//                 notuna bakın).
//   --supheli-duz Zarfa BENZEYEN ama çözülemeyen satırları DÜZ METİN kabul
//                 edip şifrele. Varsayılan: dokunma, yalnız raporla.
//
// ---------------------------------------------------------------------------
// KESİLİRSE NE OLUR — yeniden çalıştırılabilirlik
// ---------------------------------------------------------------------------
// Betik her satırı AYRI AYRI sınıflandırır (`sifreliMi()`), yani "zaten
// şifreli" satırlar hep atlanır. Yarıda kesilen bir çalıştırmadan sonra
// betiği BAŞTAN çalıştırmak yeterlidir: kaldığı yerden devam etmiş olur.
// Ayrıca her öbek TEK BİR TRANSACTION'dır (BEGIN/COMMIT) ve commit'ten ÖNCE
// aynı transaction içinde geri okuyup çözerek DOĞRULAR; doğrulama tutmazsa
// ROLLBACK yapıp durur. Yani yarım yazılmış öbek diye bir şey oluşmaz.
//
// ---------------------------------------------------------------------------
// ÖNCE MİGRASYONU UYGULA
// ---------------------------------------------------------------------------
// `migrasyon-2026-08-07.sql` CHECK kısıtını düşürür. Kısıt dururken bu betik
// 2000 karakteri aşan ilk zarfta hata alır. Betik açılışta kısıtı KONTROL
// EDER ve varsa çalışmayı reddeder.

import pg from 'pg';
import { sifrele, coz, sifreliMi, anahtarYukle, zarfAyristir } from './kripto.js';

const argv = process.argv.slice(2);
const bayrak = (ad) => argv.includes(ad);
const deger = (ad, varsayilan) => {
  const i = argv.indexOf(ad);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : varsayilan;
};

const UYGULA = bayrak('--uygula');
const GERI = bayrak('--geri');
const DOGRULA = bayrak('--dogrula');
const SUPHELI_DUZ = bayrak('--supheli-duz');
const OBEK = Math.max(1, Number(deger('--obek', '200')) || 200);
let sonId = Number(deger('--baslangic', '0')) || 0;

const yaz = (...a) => console.log(...a);

function yardim() {
  yaz(`
mesaj_sifrele_geri_doldur.js — özel mesajları şifreler / geri alır

  (bayraksız)     KURU ÇALIŞTIRMA — hiçbir şey yazılmaz
  --uygula        gerçekten yaz
  --geri          ters yön: şifreliden düz metne
  --dogrula       yalnız oku ve çözülebilirliği raporla
  --obek N        öbek boyu (varsayılan 200)
  --baslangic N   bu id'den sonrasını işle
  --supheli-duz   zarfa benzeyen ama çözülemeyen satırı düz metin say
  --yardim        bu metin
`);
}

if (bayrak('--yardim') || bayrak('-h')) {
  yardim();
  process.exit(0);
}

// ---------------------------------------------------------------------------

const takim = anahtarYukle(process.env);
if (!takim.acik && !GERI) {
  console.error(
    'HATA: MESAJ_ANAHTARI yok (ya da MESAJ_SIFRELEME=kapali). Şifrelenecek ' +
    'bir şey yok; anahtarı .env\'e ekleyip konteyneri yeniden başlat.');
  process.exit(1);
}

const havuz = new pg.Pool({ connectionString: process.env.DATABASE_URL });

/** CHECK kısıtı duruyorsa uzun zarf INSERT/UPDATE'i patlatır — önce uyar. */
async function migrasyonKontrol() {
  const { rows } = await havuz.query(
    `SELECT conname FROM pg_constraint
     WHERE conrelid='mesajlar'::regclass AND conname='mesajlar_metin_check'`);
  if (rows.length) {
    console.error(
      'HATA: `mesajlar_metin_check` kısıtı hâlâ duruyor. Şifreli zarf 2000 ' +
      'karakteri aşabilir ve UPDATE reddedilir.\n' +
      '  Önce uygula: psql -f migrasyon-2026-08-07.sql');
    process.exit(1);
  }
}

/** Bir satırın hangi kovaya düştüğü. */
function siniflandir(satir) {
  if (satir.metin == null) return 'bos';          // sesli/medya/içerik kartı
  if (satir.metin === '') return 'bos';
  if (!sifreliMi(satir.metin)) return 'duz';
  try {
    coz(satir.metin, takim);
    return 'sifreli';
  } catch {
    // Zarf gibi görünüyor ama açılmıyor: (a) geri doldurmadan ÖNCE yazılmış,
    // kasten zarf biçiminde bir KULLANICI METNİ, (b) bozulmuş satır,
    // (c) anahtarı yüklü olmayan eski bir zarf. Üçünü ayırt edemeyiz —
    // bu yüzden varsayılan davranış DOKUNMAMAK.
    return 'supheli';
  }
}

const sayac = { taranan: 0, islenen: 0, atlanan_sifreli: 0, atlanan_bos: 0, supheli: 0 };
const supheliIdler = [];

async function obekIsle(istemci, satirlar) {
  const yapilacak = [];
  for (const s of satirlar) {
    sayac.taranan++;
    const sinif = siniflandir(s);
    if (sinif === 'bos') { sayac.atlanan_bos++; continue; }
    if (sinif === 'supheli') {
      sayac.supheli++;
      supheliIdler.push(s.id);
      if (!SUPHELI_DUZ) continue;
      // --supheli-duz: düz metin kabul et
      if (!GERI) yapilacak.push({ id: s.id, eski: s.metin, yeni: sifrele(s.metin, takim) });
      continue;
    }
    if (!GERI) {
      if (sinif === 'sifreli') { sayac.atlanan_sifreli++; continue; }
      yapilacak.push({ id: s.id, eski: s.metin, yeni: sifrele(s.metin, takim) });
    } else {
      if (sinif === 'duz') { sayac.atlanan_sifreli++; continue; }   // zaten düz
      yapilacak.push({ id: s.id, eski: s.metin, yeni: coz(s.metin, takim) });
    }
  }
  if (!yapilacak.length) return;

  if (!UYGULA) {                                   // KURU ÇALIŞTIRMA
    sayac.islenen += yapilacak.length;
    for (const y of yapilacak.slice(0, 3)) {
      const on = GERI ? '(zarf)' : JSON.stringify(String(y.eski).slice(0, 30));
      yaz(`    kuru: #${y.id} ${on} -> ${String(y.yeni).slice(0, 46)}…`);
    }
    return;
  }

  await istemci.query('BEGIN');
  try {
    for (const y of yapilacak) {
      await istemci.query('UPDATE mesajlar SET metin=$1 WHERE id=$2', [y.yeni, y.id]);
    }
    // COMMIT'TEN ÖNCE GERİ OKU VE DOĞRULA. Yazdığımızı okuyup çözmeden
    // commit etmek, 87 mesajı geri dönüşsüz bozma riskini almak olurdu.
    const idler = yapilacak.map((y) => y.id);
    const geri = await istemci.query(
      'SELECT id, metin FROM mesajlar WHERE id = ANY($1::int[])', [idler]);
    const harita = new Map(geri.rows.map((r) => [r.id, r.metin]));
    for (const y of yapilacak) {
      const okunan = harita.get(y.id);
      const cozulen = GERI ? okunan : coz(okunan, takim);
      const beklenen = GERI ? y.yeni : String(y.eski);
      if (cozulen !== beklenen) {
        throw new Error(
          `DOĞRULAMA BAŞARISIZ #${y.id}: geri okunan değer aslıyla eşleşmiyor`);
      }
      if (!GERI && !sifreliMi(okunan)) {
        throw new Error(`DOĞRULAMA BAŞARISIZ #${y.id}: yazılan değer zarf değil`);
      }
    }
    await istemci.query('COMMIT');
    sayac.islenen += yapilacak.length;
  } catch (e) {
    await istemci.query('ROLLBACK');
    console.error('\nÖBEK GERİ ALINDI (ROLLBACK):', e.message);
    throw e;
  }
}

async function dogrulamaModu() {
  const bozuk = [];
  const dagilim = { duz: 0, sifreli: 0, bos: 0, supheli: 0 };
  const kimlikler = new Map();
  let id = 0;
  for (;;) {
    const { rows } = await havuz.query(
      'SELECT id, metin FROM mesajlar WHERE id > $1 ORDER BY id LIMIT $2', [id, OBEK]);
    if (!rows.length) break;
    for (const r of rows) {
      const s = siniflandir(r);
      dagilim[s]++;
      if (s === 'supheli') bozuk.push(r.id);
      if (s === 'sifreli') {
        const k = zarfAyristir(r.metin).kimlik;
        kimlikler.set(k, (kimlikler.get(k) || 0) + 1);
      }
    }
    id = rows[rows.length - 1].id;
  }
  yaz('\n=== DOĞRULAMA ===');
  yaz(`  şifreli   : ${dagilim.sifreli}`);
  yaz(`  düz metin : ${dagilim.duz}   ${dagilim.duz ? '<-- geri doldurma EKSİK' : ''}`);
  yaz(`  metinsiz  : ${dagilim.bos}   (sesli/medya/içerik kartı mesajları)`);
  yaz(`  şüpheli   : ${dagilim.supheli}${bozuk.length ? '  id: ' + bozuk.join(',') : ''}`);
  for (const [k, n] of kimlikler) yaz(`  anahtar ${k}: ${n} satır`);
  return dagilim.supheli === 0 ? 0 : 2;
}

async function main() {
  await migrasyonKontrol();

  if (DOGRULA) {
    const kod = await dogrulamaModu();
    await havuz.end();
    process.exit(kod);
  }

  const yon = GERI ? 'GERİ ALMA (şifreli -> düz metin)' : 'ŞİFRELEME (düz metin -> zarf)';
  yaz(`\n=== ${yon} ===`);
  yaz(UYGULA
    ? '  MOD: GERÇEK — veritabanına yazılacak'
    : '  MOD: KURU ÇALIŞTIRMA — hiçbir şey yazılmayacak (yazmak için --uygula)');
  if (takim.aktif) yaz(`  aktif anahtar: ${takim.aktif.kimlik}` +
    `  |  okunabilir kimlikler: ${[...takim.hepsi.keys()].join(', ')}`);
  const { rows: t } = await havuz.query('SELECT count(*)::int n FROM mesajlar');
  yaz(`  tablo: ${t[0].n} satır  |  öbek: ${OBEK}  |  başlangıç id: ${sonId}\n`);

  const istemci = await havuz.connect();
  try {
    for (;;) {
      const { rows } = await istemci.query(
        'SELECT id, metin FROM mesajlar WHERE id > $1 ORDER BY id LIMIT $2',
        [sonId, OBEK]);
      if (!rows.length) break;
      await obekIsle(istemci, rows);
      sonId = rows[rows.length - 1].id;
      yaz(`  ilerleme: id<=${sonId}  taranan ${sayac.taranan}  işlenen ${sayac.islenen}` +
          `  atlanan ${sayac.atlanan_sifreli + sayac.atlanan_bos}` +
          (sayac.supheli ? `  ŞÜPHELİ ${sayac.supheli}` : ''));
    }
  } finally {
    istemci.release();
  }

  yaz('\n=== ÖZET ===');
  yaz(`  taranan            : ${sayac.taranan}`);
  yaz(`  ${GERI ? 'düz metne döndürülen' : 'şifrelenen         '}: ${sayac.islenen}` +
      (UYGULA ? '' : '  (KURU — yazılmadı)'));
  yaz(`  atlanan (hedefte)  : ${sayac.atlanan_sifreli}`);
  yaz(`  atlanan (metinsiz) : ${sayac.atlanan_bos}`);
  if (sayac.supheli) {
    yaz(`  ŞÜPHELİ            : ${sayac.supheli}  id: ${supheliIdler.join(',')}`);
    yaz('    Zarfa benziyor ama çözülemedi. Üç ihtimal: (a) kullanıcının kasten');
    yaz('    zarf biçiminde yazdığı ESKİ düz metin, (b) bozulmuş satır,');
    yaz('    (c) anahtarı yüklü olmayan bir zarf. DOKUNULMADI.');
    yaz('    (a) olduğundan eminsen --supheli-duz ile tekrar çalıştır.');
  }
  if (!UYGULA && sayac.islenen) {
    yaz('\n  Bu bir KURU ÇALIŞTIRMAYDI. Gerçekten yazmak için: --uygula');
  }
  if (UYGULA && !GERI) {
    yaz('\n  Sonraki adım: --dogrula ile tüm satırların çözülebildiğini kanıtla.');
  }
  await havuz.end();
}

main().catch(async (e) => {
  console.error('\nHATA:', e.message);
  await havuz.end().catch(() => {});
  process.exit(1);
});

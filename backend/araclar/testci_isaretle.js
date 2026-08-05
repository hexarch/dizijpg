#!/usr/bin/env node
/**
 * "dizi.jpg aile üyesi" rozetini üreten araç — `kullanicilar.testci` bayrağını
 * bir e-posta listesinden işaretler.
 *
 * KİŞİSEL VERİ UYARISI (bu dosyanın var oluş sebebi):
 * Kapalı test (Play Console) e-posta adresleri kişisel veridir ve DEPOYA
 * GİREMEZ. Bu yüzden liste burada GÖMÜLÜ DEĞİL, her çalıştırmada bir dosyadan
 * okunur. Betik e-postaları ekrana da BASMAZ: raporda yalnız maskelenmiş
 * biçim (ab***d@saglayici.com) görünür, böylece çıktısı bir yere yapıştırılsa bile
 * adresler sızmaz. `--acik-liste` verilmedikçe bu maske kalkmaz.
 *
 * NEDEN KALICI BAYRAK (çalışma anında liste kontrolü değil):
 *  - Play Console listesi uygulamanın göremediği bir yerde yaşar,
 *  - her profil isteğinde 28 adresle karşılaştırma gereksiz iş,
 *  - adresler sunucu koduna/ortamına taşınmak zorunda kalırdı,
 *  - bayrak elle de verilebilir (listede olmayan ekip üyesi).
 * Yeni testçi eklendiğinde bu betik yeni listeyle TEKRAR çalıştırılır.
 *
 * EŞLEŞTİRME: e-posta karşılaştırması küçük harfe indirgenmiş ve kırpılmış
 * biçimde yapılır (`lower(btrim(email))`). Gmail nokta/artı takma adları
 * (a.b+x@saglayici.com) KASITLI olarak normalleştirilmez: kullanıcı hangi adresle
 * kayıt olduysa Play Console'da da o adres davetlidir, "akıllı" eşleştirme
 * yanlış hesaba rozet takma riski taşır.
 *
 * VARSAYILAN KURU ÇALIŞMA: `--uygula` verilmedikçe TEK BİR SATIR yazılmaz.
 * `--uygula` önce `kullanicilar` tablosunun tarihli yedeğini alır.
 *
 * Sunucuda, HOST üzerinde çalışır (dil_duzelt.js ile aynı desen): veritabanı
 * dışarı port açmadığı için `docker exec dizijpg-db psql` kullanılır.
 *
 * Kullanım (sunucuda /opt/dizijpg içinde):
 *   node araclar/testci_isaretle.js --liste=/root/testciler.txt
 *   node araclar/testci_isaretle.js --liste=/root/testciler.txt --uygula
 *   node araclar/testci_isaretle.js --liste=... --uygula --temizle
 *
 * Seçenekler:
 *   --liste=YOL     e-posta listesi (satır başına bir adres; # yorum satırı)
 *   --uygula        gerçekten yaz (yoksa yalnız rapor)
 *   --temizle       listede OLMAYAN hesapların bayrağını da kaldır
 *                   (varsayılan: yalnız ekler, elle verilmiş rozeti silmez)
 *   --acik-liste    raporda e-postaları maskelemeden göster (dikkat!)
 *   --yedek-dizin=  yedek klasörü (varsayılan /opt/dizijpg/yedekler)
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ARG = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v === undefined ? '1' : v];
  }),
);

const DB_KAP = process.env.DIL_DB_KAP || 'dizijpg-db';
const DB_KULLANICI = process.env.DIL_DB_KULLANICI || 'dizijpg';
const DB_AD = process.env.DIL_DB_AD || 'dizijpg';
const UYGULA = !!ARG.uygula;
const TEMIZLE = !!ARG.temizle;
const ACIK = !!ARG['acik-liste'];
const YEDEK_DIZIN = ARG['yedek-dizin'] || '/opt/dizijpg/yedekler';

const log = (...m) => process.stdout.write(`${m.join(' ')}\n`);

// Sütun ayracı: birim ayracı (U+001F). Boru/virgül gibi görünür bir karakter
// seçilse e-posta ya da kullanıcı adı içindeki aynı karakter satırı bölerdi.
const AYRAC = '\u001f';

/** psql'i `docker exec` ile çalıştırır; SQL stdin'den gider. */
function psql(sql, { satirlar = false } = {}) {
  const cikti = execFileSync('docker', [
    'exec', '-i', DB_KAP, 'psql', '-U', DB_KULLANICI, '-d', DB_AD,
    '-v', 'ON_ERROR_STOP=1', '-q', '-tA', '-F', AYRAC, '-f', '-',
  ], { input: sql, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (!satirlar) return cikti.trim();
  return cikti.split('\n').filter(Boolean).map((s) => s.split(AYRAC));
}

/** SQL metin sabiti — tek tırnak kaçışı. */
const q = (s) => `'${String(s).replace(/'/g, "''")}'`;

/** Rapor için e-posta maskesi: adsoyad@saglayici.com -> ad***d@saglayici.com */
function maskele(eposta) {
  if (ACIK) return eposta;
  const [ad, alan] = eposta.split('@');
  if (!alan) return '***';
  const bas = ad.slice(0, 2);
  const son = ad.length > 3 ? ad.slice(-1) : '';
  return `${bas}***${son}@${alan}`;
}

function listeyiOku(yol) {
  if (!yol || yol === '1') {
    log('HATA: --liste=YOL zorunlu (satır başına bir e-posta).');
    log('E-posta listesi bilerek gömülü DEĞİL: kişisel veri depoya giremez.');
    process.exit(2);
  }
  if (!fs.existsSync(yol)) {
    log(`HATA: liste dosyası yok: ${yol}`);
    process.exit(2);
  }
  const ham = fs.readFileSync(yol, 'utf8').split(/\r?\n/);
  const gecersiz = [];
  const adresler = [];
  for (const satir of ham) {
    const s = satir.trim();
    if (!s || s.startsWith('#')) continue;
    const e = s.toLowerCase();
    // Kaba biçim denetimi: bozuk satır sessizce yutulup "0 eşleşme" demesin.
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) { gecersiz.push(s); continue; }
    adresler.push(e);
  }
  if (gecersiz.length) {
    log(`UYARI: ${gecersiz.length} satır e-posta biçiminde değil, atlandı.`);
  }
  return [...new Set(adresler)];
}

/** Yazmadan önce kullanicilar tablosunun tarihli yedeği. */
function yedekAl() {
  fs.mkdirSync(YEDEK_DIZIN, { recursive: true });
  const damga = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '');
  const yol = path.join(YEDEK_DIZIN, `kullanicilar-${damga}.sql`);
  const dokum = execFileSync('docker', [
    'exec', '-i', DB_KAP, 'pg_dump', '-U', DB_KULLANICI, '-d', DB_AD,
    '-t', 'kullanicilar',
  ], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  fs.writeFileSync(yol, dokum);
  const boyut = fs.statSync(yol).size;
  if (boyut < 1024) {
    log(`HATA: yedek şüpheli derecede küçük (${boyut} bayt) — yazma iptal.`);
    process.exit(3);
  }
  log(`yedek: ${yol} (${boyut} bayt)`);
  return yol;
}

function main() {
  const adresler = listeyiOku(ARG.liste);
  log(`liste: ${adresler.length} benzersiz e-posta (${ARG.liste})`);

  // Sütun var mı? (migrasyon-2026-08-05.sql uygulanmadan çalıştırılmasın)
  const sutun = psql(
    "SELECT count(*) FROM information_schema.columns " +
    "WHERE table_name='kullanicilar' AND column_name='testci';",
  );
  if (sutun !== '1') {
    log('HATA: kullanicilar.testci sütunu yok — önce migrasyon-2026-08-05.sql.');
    process.exit(4);
  }

  const dizi = `ARRAY[${adresler.map(q).join(',')}]::text[]`;
  const eslesenSQL = adresler.length
    ? `SELECT id, kullanici_adi, lower(btrim(email)), testci
       FROM kullanicilar
       WHERE email IS NOT NULL AND lower(btrim(email)) = ANY(${dizi})
       ORDER BY id;`
    : 'SELECT 1 WHERE false;';
  const eslesen = psql(eslesenSQL, { satirlar: true });

  const eklenecek = eslesen.filter((r) => r[3] !== 't');
  const zaten = eslesen.filter((r) => r[3] === 't');

  log('');
  log(`kayıtlı kullanıcı toplamı: ${psql('SELECT count(*) FROM kullanicilar;')}`);
  log(`listeyle eşleşen hesap    : ${eslesen.length}`);
  log(`  - zaten işaretli        : ${zaten.length}`);
  log(`  - İŞARETLENECEK         : ${eklenecek.length}`);
  for (const [id, kadi, eposta] of eslesen) {
    const durum = eklenecek.some((r) => r[0] === id) ? 'YENİ ' : 'zaten';
    log(`    ${durum} #${id} @${kadi} <${maskele(eposta)}>`);
  }

  // Listede olmayıp bayrağı olanlar (elle verilmiş ya da listeden çıkmış).
  const fazlaSQL = adresler.length
    ? `SELECT id, kullanici_adi, coalesce(lower(btrim(email)),'')
       FROM kullanicilar
       WHERE testci AND (email IS NULL OR lower(btrim(email)) <> ALL(${dizi}))
       ORDER BY id;`
    : "SELECT id, kullanici_adi, coalesce(lower(btrim(email)),'') FROM kullanicilar WHERE testci ORDER BY id;";
  const fazla = psql(fazlaSQL, { satirlar: true });
  if (fazla.length) {
    log(`listede OLMAYAN işaretli hesap: ${fazla.length}` +
        (TEMIZLE ? ' (--temizle: bayrak KALDIRILACAK)' : ' (dokunulmayacak)'));
    for (const [id, kadi, eposta] of fazla) {
      log(`    #${id} @${kadi} <${eposta ? maskele(eposta) : 'e-posta yok'}>`);
    }
  }

  // Listede olup hiç hesabı olmayan adres sayısı (adres YAZILMAZ).
  const kayitsiz = adresler.length - eslesen.length;
  log(`listede olup henüz kayıt olmamış adres: ${kayitsiz}`);

  const yazilacak = eklenecek.length + (TEMIZLE ? fazla.length : 0);
  log('');
  if (!UYGULA) {
    log(`KURU ÇALIŞMA — hiçbir şey yazılmadı. Etkilenecek satır: ${yazilacak}`);
    log('Yazmak için aynı komuta --uygula ekleyin.');
    return;
  }
  if (!yazilacak) { log('Değişiklik yok; yedek de alınmadı.'); return; }

  yedekAl();
  const idler = eklenecek.map((r) => Number(r[0]));
  let yazilan = 0;
  if (idler.length) {
    yazilan += Number(psql(
      `WITH g AS (UPDATE kullanicilar SET testci=true
                  WHERE id = ANY(ARRAY[${idler.join(',')}]::int[]) RETURNING 1)
       SELECT count(*) FROM g;`,
    ));
  }
  if (TEMIZLE && fazla.length) {
    const silIdler = fazla.map((r) => Number(r[0]));
    const kaldirilan = Number(psql(
      `WITH g AS (UPDATE kullanicilar SET testci=false
                  WHERE id = ANY(ARRAY[${silIdler.join(',')}]::int[]) RETURNING 1)
       SELECT count(*) FROM g;`,
    ));
    log(`bayrağı kaldırılan: ${kaldirilan}`);
  }
  log(`işaretlenen: ${yazilan}`);
  log(`toplam testci: ${psql('SELECT count(*) FROM kullanicilar WHERE testci;')}`);
}

main();

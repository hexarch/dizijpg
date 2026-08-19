// Tekrar izleme + ekran süresi testleri — `node --test backend/test/*.test.js`
//
// KORUNAN KARARLAR (istek listesi md. 22, 13 Ağu 2026):
//
//  1) Yeniden izleme sayısı `durumlar.tekrar`dadır; `izlemeler`e İKİNCİ SATIR
//     ATILMAZ. O tablo bölüm SAYAÇLARININ kaynağı (rozetler, kitaplık, uyum,
//     profil sayaçları, "bir öncekini izledi mi" kuralı) — çoğaltmak hepsini
//     bozardı. Şema değişikliği GEREKMEDİ.
//  2) Ekran süresi formülü TEK YERDE: `SURE_DK` + `izlemeDakikasi`. Üç uç
//     (kendi istatistiğin, açık profil, yıl özeti) aynı sabitleri oradan alır.
//     Daha önce üçü de kopyala-yapıştırdı; bu projede aynı kalıp puanlamada
//     "10/10 vs 5.0" hatasını doğurmuştu (`app/lib/puan.dart`). Aşağıdaki
//     "kopya formül" testi, birisi `* 42`yi geri yazarsa KIRILIR.
//  3) Tekrar, o başlığın KAYITLI süresini katlar: çarpan `1 + tekrar`.
//  4) Yıl özeti tekrarı SAYMAZ: tekrarın hangi yılda yapıldığı kayıtlı değil.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (bolum_puani.test.js / seo_gizlilik.test.js ile aynı gerekçe). Saf yardımcı
// kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekme (bolum_puani.test.js'teki kalıp)
// ---------------------------------------------------------------------------
function bildirimCek(kaynak, ad) {
  const m = new RegExp(`^(const|function) ${ad}\\b`, 'm').exec(kaynak);
  assert.ok(m, `${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; } else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return kaynak.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return kaynak.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

const { SURE_DK, izlemeDakikasi } = new Function(
  `${bildirimCek(KAYNAK, 'SURE_DK')}\n${bildirimCek(KAYNAK, 'izlemeDakikasi')}\n`
  + 'return { SURE_DK, izlemeDakikasi };',
)();

const tv = (adet, tekrar = 0) => ({ tur: 'tv', adet, tekrar });
const film = (adet, tekrar = 0) => ({ tur: 'movie', adet, tekrar });

// ---------------------------------------------------------------------------
// Şema: tekrar sütunu var, izlemeler'in anahtarı DEĞİŞMEDİ
// ---------------------------------------------------------------------------
test('şema: durumlar.tekrar var ve NOT NULL DEFAULT 0', () => {
  assert.match(SEMA, /tekrar\s+INT\s+NOT NULL\s+DEFAULT\s+0/i);
});

test('şema: izlemeler anahtarı bölüm başına TEK satır (tekrar satırı atılmaz)', () => {
  assert.match(
    SEMA,
    /PRIMARY KEY \(kullanici_id, tur, tmdb_id, sezon, bolum\)/,
    'izlemeler PK değişmiş: tekrarlar buraya satır olarak yazılıyorsa bölüm '
    + 'sayaçları, rozetler ve uyum yüzdesi şişer',
  );
});

// ---------------------------------------------------------------------------
// Formül: tekrarsız
// ---------------------------------------------------------------------------
test('sabitler: bölüm 42 dk, film 110 dk', () => {
  assert.equal(SURE_DK.tv, 42);
  assert.equal(SURE_DK.movie, 110);
});

test('tekrarsız: eski formülle BİREBİR aynı sonuç', () => {
  // Geriye uyum: tekrar=0 olan bir kitaplıkta sayı değişmemeli.
  for (const [b, f] of [[0, 0], [1, 0], [0, 1], [250, 37], [10000, 1265]]) {
    assert.equal(
      izlemeDakikasi([tv(b), film(f)]),
      b * 42 + f * 110,
      `bölüm=${b} film=${f}`,
    );
  }
});

test('boş kitaplık 0 dakika', () => {
  assert.equal(izlemeDakikasi([]), 0);
  assert.equal(izlemeDakikasi(null), 0);
  assert.equal(izlemeDakikasi(undefined), 0);
});

// ---------------------------------------------------------------------------
// Formül: tekrarlı
// ---------------------------------------------------------------------------
test('DİZİ tekrarı izlenen BÖLÜM sayısını katlar', () => {
  // 62 bölüm bir kez = 2604 dk; bir kez daha izlenince iki katı.
  assert.equal(izlemeDakikasi([tv(62, 0)]), 62 * 42);
  assert.equal(izlemeDakikasi([tv(62, 1)]), 62 * 42 * 2);
  assert.equal(izlemeDakikasi([tv(62, 3)]), 62 * 42 * 4);
});

test('FİLM tekrarı 110 dakikayı katlar', () => {
  assert.equal(izlemeDakikasi([film(1, 0)]), 110);
  assert.equal(izlemeDakikasi([film(1, 1)]), 220);
  assert.equal(izlemeDakikasi([film(1, 9)]), 1100);
});

test('karışık kitaplık: her öbek kendi tekrarıyla çarpılır', () => {
  const dakika = izlemeDakikasi([
    tv(100, 0), // 4200
    tv(20, 2),  // 20*42*3 = 2520
    film(5, 0), // 550
    film(2, 1), // 2*110*2 = 440
  ]);
  assert.equal(dakika, 4200 + 2520 + 550 + 440);
});

test('üst sınır: tekrar=99 (sunucunun izin verdiği en büyük değer)', () => {
  assert.equal(izlemeDakikasi([film(1, 99)]), 110 * 100);
  assert.equal(izlemeDakikasi([tv(500, 99)]), 500 * 42 * 100);
});

// ---------------------------------------------------------------------------
// Kenar durumlar
// ---------------------------------------------------------------------------
test('tekrar NULL/undefined/bozuk → 0 sayılır (durumlar satırı olmayabilir)', () => {
  for (const t of [null, undefined, '', 'abc', NaN]) {
    assert.equal(izlemeDakikasi([{ tur: 'movie', adet: 1, tekrar: t }]), 110);
  }
});

test('NEGATİF tekrar süreyi AZALTAMAZ', () => {
  assert.equal(izlemeDakikasi([film(1, -5)]), 110);
  assert.equal(izlemeDakikasi([tv(10, -1)]), 420);
});

test('negatif/bozuk adet 0 sayılır', () => {
  assert.equal(izlemeDakikasi([tv(-3, 2)]), 0);
  assert.equal(izlemeDakikasi([{ tur: 'tv', adet: null, tekrar: 2 }]), 0);
});

test('bilinmeyen tür süre KATMAZ (person vb. sızarsa sessizce 0)', () => {
  assert.equal(izlemeDakikasi([{ tur: 'person', adet: 9, tekrar: 3 }]), 0);
  assert.equal(izlemeDakikasi([{ adet: 9, tekrar: 3 }]), 0);
  assert.equal(izlemeDakikasi([null]), 0);
});

test('İZLEME SATIRI OLMAYAN başlık tekrarla da 0 dakika katar', () => {
  // Karar: süre `izlemeler` satırlarından türer, TMDB bölüm sayısından değil.
  // Tabana 0 dakika katan bir başlık tekrarına da 0 katmalı — yoksa ilk
  // izleme 0 dk, ikinci izleme 220 dk sayılırdı.
  assert.equal(izlemeDakikasi([tv(0, 5)]), 0);
  assert.equal(izlemeDakikasi([film(0, 5)]), 0);
});

// ---------------------------------------------------------------------------
// KOPYA FORMÜL NÖBETİ: sabitler tek yerde mi?
// ---------------------------------------------------------------------------
test('KOPYA YOK: `* 42` / `* 110` kaynağın hiçbir yerinde geçmiyor', () => {
  const kopya = KAYNAK.split('\n')
    .map((s, i) => [i + 1, s])
    .filter(([, s]) => /\*\s*42\b|\*\s*110\b|\b42\s*\*|\b110\s*\*/.test(s));
  assert.deepEqual(
    kopya, [],
    'Ekran süresi formülü yeniden kopyalanmış. Sabitler YALNIZ SURE_DK\'da '
    + 'durmalı, toplama YALNIZ izlemeDakikasi\'nda',
  );
});

test('/istatistiklerim ve /profil/:ad AYNI yardımcıyı çağırır', () => {
  // tahminiDakika: 1 tanım + 3 çağrı (/istatistiklerim, /profil/:ad ve
  // 19 Ağu 2026'da eklenen /istatistiklerim/izleme). Beklenenden AZSA
  // uçlardan biri kendi hesabını yapıyor demektir — testin asıl koruduğu şey
  // bu: iki ekranın aynı kullanıcı için FARKLI ekran süresi göstermesi.
  // FAZLAYSA yeni bir uç eklenmiştir ve bilinçli olmalı (bu satır o kararın
  // kaydı).
  const sayi = (KAYNAK.match(/tahminiDakika\(/g) || []).length;
  assert.equal(sayi, 4, `tahminiDakika( ${sayi} kez geçiyor, 4 bekleniyordu`);
  // İki uç da yanıtta doğrudan bu değeri veriyor.
  const alan = (KAYNAK.match(/tahmini_dakika: dakika/g) || []).length;
  assert.equal(alan, 2, 'tahmini_dakika iki uçta da yardımcıdan gelmeli');
});

test('yıl özeti tekrarı SAYMAZ (tekrarın yılı kayıtlı değil)', () => {
  const m = /dakika: izlemeDakikasi\(\[([\s\S]{0,260}?)\]\)/.exec(KAYNAK);
  assert.ok(m, '/ozet/:yil ortak yardımcıyı kullanmıyor');
  assert.equal(
    (m[1].match(/tekrar: 0/g) || []).length, 2,
    'yıl özetinde tekrar açıkça 0 verilmeli',
  );
});

// ---------------------------------------------------------------------------
// SQL sözleşmesi
// ---------------------------------------------------------------------------
test('tahminiDakika sorgusu: izlemeler ⟕ durumlar, tür+tekrar öbekli', () => {
  const m = /async function tahminiDakika[\s\S]*?\n}/.exec(KAYNAK);
  assert.ok(m, 'tahminiDakika bulunamadı');
  const g = m[0];
  assert.match(g, /FROM izlemeler i/);
  assert.match(g, /LEFT JOIN durumlar d/,
    'INNER JOIN olursa `durumlar` satırı olmayan filmler süreden düşer');
  assert.match(g, /COALESCE\(d\.tekrar, 0\)/);
  assert.match(g, /GROUP BY i\.tur, COALESCE\(d\.tekrar, 0\)/,
    'öbeklenmezse tüm kitaplık satır satır taşınır');
  assert.ok(
    !/durum\s*=\s*'bitirdim'/.test(g),
    "durum='bitirdim' süzgeci OLMAMALI: kullanıcı yeni sezon için "
    + "'izliyorum'a dönünce geçmiş tekrarların süresi silinmemeli",
  );
});

test('/rewatch: yalnız "bitirdim" içerikte yazar ve 0-99 arasında kalır', () => {
  const m = /app\.post\('\/rewatch'[\s\S]*?\n\}\)\);/.exec(KAYNAK);
  assert.ok(m, '/rewatch ucu bulunamadı');
  assert.match(m[0], /LEAST\(99, GREATEST\(0, tekrar \+ \$4\)\)/);
  assert.match(m[0], /durum='bitirdim'/);
  assert.match(m[0], /RETURNING tekrar/,
    'istemci rozetteki sayıyı yanıttan okur');
  assert.ok(
    !/INSERT INTO izlemeler/.test(m[0]),
    'tekrar `izlemeler`e satır YAZMAMALI (bölüm sayaçlarını şişirir)',
  );
});

test('/kitapligim yanıtı `tekrar` taşır (poster rozeti bunu okur)', () => {
  const m = /app\.get\('\/kitapligim'[\s\S]*?\n\}\)\);/.exec(KAYNAK);
  assert.ok(m, '/kitapligim ucu bulunamadı');
  assert.match(
    m[0], /SELECT tur, tmdb_id, durum, tekrar, guncelleme FROM durumlar/,
    'tekrar dönmezse poster kartındaki "×2" hiç çıkmaz',
  );
});

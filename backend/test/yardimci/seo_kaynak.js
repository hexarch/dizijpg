// SEO testlerinin paylaştığı kaynak-okuma yardımcıları.
//
// NEDEN KAYNAK OKUMA: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani uçlar doğrudan çağrılamıyor (seo_gizlilik.test.js ile aynı gerekçe).
// Saf yardımcılar kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR: test canlıdaki
// kodu sınar, kopyasını değil.
//
// NEDEN `test/yardimci/` ALTINDA: `npm test` betiği `node --test test/*.test.js`
// çalıştırıyor; alt klasördeki dosya test olarak toplanmaz, yalnız içe aktarılır.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
// SSR dil tablosu (29 Ağu 2026): server.js'ten ÇEKİLEN saf yardımcılar artık
// `seoDil` / `bic` / `seoTarih` / `seoSayi` / `seoUlke` / `seoDilliYol`
// çağırıyor. Sanal alan bu adları GÖRMEK zorunda; yoksa "seoDil is not
// defined" ile patlar. TEK YERDEN enjekte edilir ki test dosyaları
// bağımlılık listelerine dil altyapısını tek tek yazmak zorunda kalmasın.
import * as DIL from '../../seo_dil.js';

export const KOK = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))));
export const PROJE = path.dirname(KOK);
export const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
export const ROBOTS = fs.readFileSync(path.join(KOK, 'robots.txt'), 'utf8');
export const YONLENDIRME = fs.readFileSync(
  path.join(PROJE, 'app', 'lib', 'yonlendirme.dart'), 'utf8');

/**
 * `function ad(...) {...}`, `async function ad(...) {...}` ya da
 * `const ad = ...;` bildiriminin tam metni.
 *
 * `async` 21 Ağu 2026'da eklendi (`/kisisel-raflar`): eski desen yalnız
 * `^(const|function)` arıyordu, yani `async function` ile yazılmış saf
 * yardımcılar "bildirim bulunamadı" diye patlıyordu.
 */
export function bildirimCek(ad) {
  const m = new RegExp(`^(?:async )?(const|function) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; }
    else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return KAYNAK.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return KAYNAK.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

// Sanal alana HER ZAMAN enjekte edilen dil altyapısı (seo_dil.js).
const DIL_ADLARI = [
  'SEO_DIL', 'SEO_DILLER', 'seoDil', 'seoDilVar', 'seoDilliYol', 'seoDilAyir',
  'seoTarih', 'seoSayi', 'seoOndalik', 'seoUlke', 'bic', 'seoSagAyrac',
];

/** İstenen bildirimleri sırayla derleyip son ifadeyi döndüren sanal alan. */
export function alan(adlar, ifade) {
  const govde = adlar.map(bildirimCek).join('\n');
  return new Function(...DIL_ADLARI, `${govde}\nreturn (${ifade});`)(
    ...DIL_ADLARI.map((k) => DIL[k]));
}

/** Kaynağın [bas, son) arasındaki bölümü; sınır yoksa test patlar. */
export function bolum(bas, son) {
  const i = KAYNAK.indexOf(bas);
  assert.notEqual(i, -1, `kaynakta bulunamadı: ${bas}`);
  const j = KAYNAK.indexOf(son, i + bas.length);
  assert.notEqual(j, -1, `kaynakta bulunamadı: ${son}`);
  return KAYNAK.slice(i, j);
}

/** `User-agent: *` bloğundaki Disallow/Allow yolları. */
export const robotsYildizBlogu = (() => {
  const satirlar = ROBOTS.split('\n').map((s) => s.replace(/#.*$/, '').trim());
  const disallow = [];
  const allow = [];
  let icerde = false;
  for (const s of satirlar) {
    const ua = /^User-agent:\s*(.+)$/i.exec(s);
    if (ua) { icerde = ua[1].trim() === '*'; continue; }
    if (!icerde) continue;
    const d = /^Disallow:\s*(.+)$/i.exec(s);
    if (d) disallow.push(d[1].trim());
    const a = /^Allow:\s*(.+)$/i.exec(s);
    if (a) allow.push(a[1].trim());
  }
  return { disallow, allow };
})();

/** Joker içermeyen ön ek kuralları — `yol` robots.txt ile kapalı mı? */
export const robotsKapali = (yol) => robotsYildizBlogu.disallow
  .filter((d) => !d.includes('*'))
  .some((d) => yol.startsWith(d));

// ---------------------------------------------------------------------------
// yonlendirme.dart rota listesi
// ---------------------------------------------------------------------------
/**
 * Flutter rotalarının TAM listesi (`:param` yazımı korunur).
 *
 * seo_gizlilik.test.js'teki basit ayrıştırıcıdan farkı: İÇ İÇE rotaları
 * (`path: 'takipciler'` gibi eğik çizgisiz alt yollar) ve SABİT üzerinden
 * verilen yolları (`path: tamAramaYolu`) da çözer. Soft 404 rota tablosunun
 * gerçekle eşleşmesi bu tam listeye bağlı — eksik ayrıştırma testi ETKİSİZ
 * bırakırdı.
 */
export function flutterRotalari() {
  // Sabitler (`const String gelenAramaYolu = '/arama-gelen';`) yonlendirme.dart
  // ve arama_cubugu.dart içinde yaşıyor.
  const sabitler = new Map();
  for (const dosya of [
    path.join(PROJE, 'app', 'lib', 'yonlendirme.dart'),
    path.join(PROJE, 'app', 'lib', 'ekranlar', 'arama_cubugu.dart'),
  ]) {
    const metin = fs.readFileSync(dosya, 'utf8');
    for (const m of metin.matchAll(/const\s+String\s+(\w+)\s*=\s*'([^']*)'/g)) {
      sabitler.set(m[1], m[2]);
    }
  }

  const rotalar = [];
  let ustYol = null;   // en son görülen KÖK yol (iç içe rotanın ebeveyni)
  for (const m of YONLENDIRME.matchAll(/path:\s*(?:'([^']*)'|(\w+))/g)) {
    const ham = m[1] !== undefined ? m[1] : sabitler.get(m[2]);
    assert.ok(ham !== undefined, `path sabiti çözülemedi: ${m[2]}`);
    if (ham.startsWith('/')) {
      ustYol = ham;
      rotalar.push(ham);
    } else {
      // İç içe rota: dosyada ebeveyninin HEMEN ARDINDAN geliyor.
      assert.ok(ustYol, `iç içe rotanın ebeveyni bulunamadı: ${ham}`);
      rotalar.push(`${ustYol}/${ham}`);
    }
  }
  return [...new Set(rotalar)];
}

/** `:param` yer tutucularını gerçekçi örnek değerlerle doldurur. */
export function ornekYol(yol) {
  return yol.replace(/:(\w+)/g, (_, ad) => {
    if (ad === 'tur') return 'tv';
    if (ad === 'durum') return 'izliyorum';
    if (ad === 'ad') return 'testkullanici';
    if (ad === 'yil') return '2026';
    return '1';   // id, sezon, bolum
  });
}

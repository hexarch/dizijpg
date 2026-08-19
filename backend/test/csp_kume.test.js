// CSP İHLAL SAYACI — KÜME GENELİ (19 Ağu 2026)
//
// HANGİ HATAYI ÇÖZÜYOR (canlıda ölçüldü):
// `/admin/csp` ucu peş peşe çağrıldığında farklı rakamlar dönüyordu —
// toplam 2, 3, 8, 1, 2, 3, 8, 1... Çünkü sayaç İŞÇİNİN BELLEĞİNDEYDİ ve küme
// 4 işçi çalıştırıyor; uç hangi işçiye düşerse onun kopyasını gösteriyordu.
//
// NEDEN CİDDİ: bu ucun TEK işi "toplam 0 mı?" sorusuna cevap vermek ve o
// cevaba bakıp CSP'yi report-only'den ZORUNLU moda almak. Dörtte bir görüşe
// bakıp "0" demek, enforce'a geçip fragman/giriş gibi yolları sessizce
// kırmanın en kolay yoluydu. Yani hata sayının kendisinde değil, o sayıya
// dayanarak verilecek KARARDA.
//
// KORUNAN KARARLAR
//  1) İşçi ihlali birincile YOLLAR (`cspKaydet`), birincil toplar.
//  2) Okuma ucu BİRLEŞİK özeti ister; birincile ulaşamazsa yerel sayaca düşer
//     ama yanıtta `kapsam: 'yerel'` + açık UYARI ile bunu SÖYLER — sessizce
//     eksik veri dönmez.
//  3) Sıfırlama YEREL + BİRLEŞİK ikisini birden temizler.
//  4) Birleşik haritanın da TAVANI var (bozuk/saldırgan istemci şişirmesin).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const SERVER = oku('server.js');
const KUME = oku('kume.js');
const IPC = oku('kume_ipc.js');

// ---------------------------------------------------------------------------
// İŞÇİ → BİRİNCİL
// ---------------------------------------------------------------------------
test('işçi CSP ihlalini birincile YOLLAR', () => {
  assert.match(IPC, /export function cspKaydet\(/, 'cspKaydet yok');
  assert.match(IPC, /process\.send\(\{ k: 'csp', veri \}\)/);
  // Ateşle-unut olmalı: rapor akışı kullanıcıyı bekletmemeli.
  const govde = /export function cspKaydet\([\s\S]*?\n\}/.exec(IPC)[0];
  assert.doesNotMatch(govde, /await|return rpc/, 'cspKaydet isteği bekletiyor');
  // server.js gerçekten çağırıyor mu?
  assert.match(SERVER, /cspKaydet\(\{ anahtar, ornekYol \}\)/);
});

test('kümelenmemişken cspKaydet SESSİZ geçer (tek süreçte kırılmasın)', () => {
  const govde = /export function cspKaydet\([\s\S]*?\n\}/.exec(IPC)[0];
  assert.match(govde, /if \(!kumelenmisMi\(\)\) return;/);
});

// ---------------------------------------------------------------------------
// BİRİNCİL TARAFI
// ---------------------------------------------------------------------------
test('birincil `csp` mesajını işler ve toplar', () => {
  assert.match(KUME, /m\.k === 'csp'/, 'santralde csp dalı yok');
  assert.match(KUME, /function cspIsle\(/);
  assert.match(KUME, /CSP\.toplam \+= 1/);
});

test('birleşik haritanın TAVANI var (şişirilemesin)', () => {
  const govde = /function cspIsle\([\s\S]*?\n  \}/.exec(KUME)[0];
  assert.match(govde, /CSP\.ozet\.size >= CSP_SINIR/, 'tavan yok');
  assert.match(govde, /CSP\.tasan \+= 1/, 'taşan sayılmıyor');
  // Tavan işçidekiyle AYNI olmalı; ikisi ayrışırsa panel yanıltır.
  const isciSinir = /const CSP_SINIR = (\d+)/.exec(SERVER);
  const birincilSinir = /const CSP_SINIR = (\d+)/.exec(KUME);
  assert.ok(isciSinir && birincilSinir, 'CSP_SINIR iki tarafta da olmalı');
  assert.equal(
    birincilSinir[1], isciSinir[1],
    'işçi ve birincil tavanları ayrışmış',
  );
});

test('birincil csp_ozet ve csp_sifirla RPC`lerine cevap verir', () => {
  assert.match(KUME, /m\.ad === 'csp_ozet'/);
  assert.match(KUME, /m\.ad === 'csp_sifirla'/);
  // Sıfırlama gerçekten temizlemeli.
  const dal = /m\.ad === 'csp_sifirla'[\s\S]*?\n      \}/.exec(KUME)[0];
  assert.match(dal, /CSP\.ozet\.clear\(\)/);
  assert.match(dal, /CSP\.toplam = 0/);
  assert.match(dal, /CSP\.tasan = 0/);
});

// ---------------------------------------------------------------------------
// OKUMA UCU
// ---------------------------------------------------------------------------
test('/admin/csp BİRLEŞİK özeti ister', () => {
  const govde = SERVER.slice(SERVER.indexOf("app.get('/admin/csp'"));
  assert.match(govde.slice(0, 2000), /await cspOzet\(\)/);
});

test('birincile ulaşılamazsa yerel sayaca düşer ama BUNU SÖYLER', () => {
  const govde = SERVER.slice(
    SERVER.indexOf("app.get('/admin/csp'"),
    SERVER.indexOf("app.post('/admin/csp/sifirla'"),
  );
  assert.match(govde, /kapsam: 'kume'/, 'birleşik yanıt kapsamı işaretlenmiyor');
  assert.match(govde, /kapsam: 'yerel'/, 'yerele düşüş işaretlenmiyor');
  // Sessizce eksik veri dönmek, tam da bu hatanın tekrarı olurdu.
  assert.match(
    govde,
    /UYARI: birincile ulaşılamadı/,
    'yerele düşerken uyarı yok — "0" görülüp enforce edilebilir',
  );
});

test('sıfırlama YEREL + BİRLEŞİK ikisini de temizler', () => {
  const govde = SERVER.slice(SERVER.indexOf("app.post('/admin/csp/sifirla'"));
  const blok = govde.slice(0, 800);
  assert.match(blok, /CSP_OZET\.clear\(\)/, 'yerel temizlenmiyor');
  assert.match(blok, /await cspSifirla\(\)/, 'küme temizlenmiyor');
  assert.match(blok, /kume: c \? 'sifirlandi' : 'ulasilamadi'/,
    'kümenin sıfırlanıp sıfırlanmadığı bildirilmiyor');
});

// ---------------------------------------------------------------------------
// SAF MANTIK — birincilin toplama işlevi kaynaktan ÇEKİLİP çalıştırılıyor
// ---------------------------------------------------------------------------
test('cspIsle: aynı anahtar birikir, farklı anahtar ayrı satır olur', () => {
  const m = /const CSP_SINIR = \d+;\s*const CSP = [\s\S]*?function cspIsle\([\s\S]*?\n  \}/
    .exec(KUME);
  assert.ok(m, 'cspIsle bloğu bulunamadı');
  const fn = new Function(`${m[0]}\nreturn { cspIsle, CSP };`)();

  fn.cspIsle({ anahtar: 'script-src|inline', ornekYol: '/akis' });
  fn.cspIsle({ anahtar: 'script-src|inline', ornekYol: '/kesfet' });
  fn.cspIsle({ anahtar: 'img-src|https://x.example', ornekYol: '/' });

  assert.equal(fn.CSP.toplam, 3);
  assert.equal(fn.CSP.ozet.size, 2);
  assert.equal(fn.CSP.ozet.get('script-src|inline').adet, 2);
  // İLK örnek yol korunur: sonraki raporlar onu ezmemeli (ilk görülen yer
  // hata ayıklamada daha değerli).
  assert.equal(fn.CSP.ozet.get('script-src|inline').ornekYol, '/akis');

  // Bozuk girdi sayacı kirletmemeli.
  fn.cspIsle(null);
  fn.cspIsle({});
  fn.cspIsle({ anahtar: '' });
  assert.equal(fn.CSP.toplam, 3);
});

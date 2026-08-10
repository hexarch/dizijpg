#!/usr/bin/env node
/**
 * dizi.jpg — rehber ekran görüntüsü boru hattı
 *
 * Emülatördeki kurulu APK'yı sürer, uygulama dilini uygulamanın KENDİ dil
 * seçicisinden değiştirir, tanımlı ekranlara gider, görüntü alır ve WebP'ye
 * çevirir.
 *
 * Kullanım:
 *   node araclar/rehber_gorsel.mjs cek --diller tr,en
 *   node araclar/rehber_gorsel.mjs cek --diller tr --ekranlar takvim,profil
 *   node araclar/rehber_gorsel.mjs cek --kuru            # kuru çalıştırma
 *   node araclar/rehber_gorsel.mjs cek --zorla           # var olanları da yenile
 *   node araclar/rehber_gorsel.mjs probe                 # ekranı incele (geliştirme)
 *   node araclar/rehber_gorsel.mjs giris                 # yalnız test hesabına gir
 *
 * NOT: Uygulama kodunu değiştirmez. Yalnız adb üzerinden sürer.
 */

import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, writeFile, mkdir, rm, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const calis = promisify(execFile);
const BURASI = path.dirname(fileURLToPath(import.meta.url));

// ─────────────────────────────────────────────────────────── ayarlar

const ADB = process.env.ADB_YOLU ||
  path.join(os.homedir(), 'Library/Android/sdk/platform-tools/adb');
const EMULATOR = process.env.EMULATOR_YOLU ||
  path.join(os.homedir(), 'Library/Android/sdk/emulator/emulator');
const AVD = process.env.REHBER_AVD || 'Medium_Phone_API_36.1';
const PAKET = 'com.dizijpg.dizijpg';
const ETKINLIK = `${PAKET}/.MainActivity`;
const CIKTI = path.join(BURASI, 'rehber-gorsel');
const GECICI = path.join(os.tmpdir(), 'dizijpg-rehber');

// Test hesabı. GERÇEK KULLANICI ASLA KULLANILMAZ.
const TEST_KULLANICI = process.env.REHBER_KULLANICI || 'testkullanici';
const TEST_SIFRE = process.env.REHBER_SIFRE || 'test1234';
const YASAK_KULLANICILAR = ['alcelik', 'emma.watches'];

// ─────────────────────────────────────────────────────────── günlük

const R = { sif: '\x1b[0m', kir: '\x1b[31m', yes: '\x1b[32m', sar: '\x1b[33m', mav: '\x1b[36m', gri: '\x1b[90m' };
const bilgi = (m) => console.log(`${R.mav}·${R.sif} ${m}`);
const tamam = (m) => console.log(`${R.yes}✓${R.sif} ${m}`);
const uyari = (m) => console.log(`${R.sar}!${R.sif} ${m}`);
const hata = (m) => console.log(`${R.kir}✗${R.sif} ${m}`);
const ayrinti = (m) => { if (AYRINTILI) console.log(`${R.gri}  ${m}${R.sif}`); };
let AYRINTILI = false;

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));

// ─────────────────────────────────────────────────────────── adb katmanı

/** Tek seferlik, KURTARMASIZ adb çağrısı. Nöbetçinin kendisi bunu kullanır. */
async function adbCiplak(args, encoding = 'utf8', maxBuffer = 64 * 1024 * 1024) {
  const { stdout } = await calis(ADB, args, { maxBuffer, encoding });
  return stdout;
}

// ── cihaz nöbetçisi ─────────────────────────────────────────
//
// 8 Ağu koşusunda emülatör 3. saatte kayboldu ve GERİYE KALAN 14 DİL (84
// görüntü) saniyeler içinde "adb: no devices/emulators found" ile atlandı:
// ilerleme dosyasındaki 90 hatanın 85'i tek bir cihaz kaybının yankısıydı.
// Betikte hiçbir kurtarma yoktu; ilk adb hatası tüm kuyruğu düşürüyordu.
// Artık cihaz kaybı GEÇİCİ bir arıza sayılır: adb sunucusu tazelenir, gerekirse
// AVD yeniden açılır, açılış beklenir, cihaz hazırlanır ve komut tekrarlanır.
const CIHAZ_KAYIP = /no devices\/emulators found|device (?:'[^']*' )?not found|device offline|device unauthorized|protocol fault|error: closed|cannot connect to daemon|daemon not running/i;

async function cihazVarMi() {
  try { return /\tdevice$/m.test(await adbCiplak(['devices'])); } catch { return false; }
}

async function acilisBekle(sure = 420000) {
  const bitis = Date.now() + sure;
  while (Date.now() < bitis) {
    if (await cihazVarMi()) {
      try {
        if ((await adbCiplak(['shell', 'getprop', 'sys.boot_completed'])).trim() === '1') {
          await bekle(5000);
          return true;
        }
      } catch { /* kabuk henüz hazır değil */ }
    }
    await bekle(5000);
  }
  return false;
}

/**
 * ANR/çökme diyalogları uiautomator'un önünü kesiyor. 8 Ağu koşusunda SystemUI
 * defalarca ANR verdi; "System UI isn't responding" penceresi odağı çalınca
 * ayarlar ekranı hiç okunamıyor ve `dilSec` "dil satırı bulunamadı" diyordu.
 * `hide_error_dialogs` bu pencereleri tamamen kaldırır (uygulama arkada devam
 * eder). Animasyonları da kapatıyoruz: hem hızlanır hem de yarım çizilmiş
 * geçiş karesi yakalama riski düşer.
 */
async function cihazHazirla() {
  const komutlar = [
    'settings put global hide_error_dialogs 1',
    'settings put secure anr_show_background 0',
    'settings put global window_animation_scale 0',
    'settings put global transition_animation_scale 0',
    'settings put global animator_duration_scale 0',
  ];
  for (const k of komutlar) await adbCiplak(['shell', k]).catch(() => {});
}

let _kurtariliyor = false;
async function cihazKurtar() {
  if (_kurtariliyor) { await bekle(15000); return cihazVarMi(); }
  _kurtariliyor = true;
  try {
    await calis(ADB, ['kill-server']).catch(() => {});
    await bekle(2000);
    await calis(ADB, ['start-server']).catch(() => {});
    await bekle(3000);
    if (!(await cihazVarMi())) {
      uyari(`emülatör yok — "${AVD}" yeniden başlatılıyor…`);
      const cocuk = spawn(EMULATOR, ['-avd', AVD, '-memory', '4096',
        '-no-snapshot-save', '-no-boot-anim', '-no-audio'], { detached: true, stdio: 'ignore' });
      cocuk.unref();
      await bekle(10000);
    }
    if (!(await acilisBekle())) return false;
    await cihazHazirla();
    await adbCiplak(['shell', `am start -n ${ETKINLIK}`]).catch(() => {});
    await bekle(8000);
    tamam('cihaz kurtarıldı');
    return true;
  } finally {
    _kurtariliyor = false;
  }
}

async function adbDene(args, encoding, maxBuffer) {
  for (let i = 0; ; i++) {
    try { return await adbCiplak(args, encoding, maxBuffer); } catch (e) {
      const ileti = `${e.message || ''}\n${e.stderr || ''}`;
      if (!CIHAZ_KAYIP.test(ileti) || i >= 2) throw e;
      uyari(`adb bağlantısı koptu — cihaz kurtarılıyor (${ileti.trim().split('\n').pop().slice(0, 90)})`);
      if (!(await cihazKurtar())) throw new Error(`Emülatör kurtarılamadı: ${ileti.trim().slice(0, 160)}`);
    }
  }
}

async function adb(...args) {
  return adbDene(args, 'utf8', 64 * 1024 * 1024);
}
async function kabuk(cmd) {
  return adb('shell', cmd);
}
/** Ham (binary) çıktı — screencap için. */
async function adbHam(...args) {
  return adbDene(args, 'buffer', 256 * 1024 * 1024);
}

async function emulatorVarMi() {
  if (!(await cihazVarMi()) && !(await cihazKurtar())) {
    throw new Error('Bağlı emülatör/cihaz yok ve başlatılamadı.');
  }
  const c = await adb('devices');
  const satirlar = c.split('\n').filter((s) => /\tdevice$/.test(s.trim()));
  if (!satirlar.length) throw new Error('Bağlı emülatör/cihaz yok (adb devices boş).');
  return satirlar[0].split('\t')[0];
}

async function odak() {
  const c = await kabuk('dumpsys window | grep -E "mCurrentFocus"');
  const m = c.match(/mCurrentFocus=Window\{[^ ]+ [^ ]+ ([^}]+)\}/);
  return m ? m[1].trim() : c.trim();
}

async function uygulamaOnde() {
  return (await odak()).includes(PAKET);
}

// ─────────────────────────────────────────────────────────── semantik ağaç
//
// Flutter, bir erişilebilirlik istemcisi (uiautomator) bağlandığında semantik
// ağacı yayınlar. Bu sayede metin/koordinat yerine ANLAM üzerinden gezinebiliriz;
// dil değişince kaymayan tek sağlam tutamak bu.

const OZNITELIK = /(\w[\w-]*)="([^"]*)"/g;

function xmlCoz(xml) {
  const dugumler = [];
  for (const parca of xml.split('<node ').slice(1)) {
    const govde = parca.split('>')[0];
    const o = {};
    let m;
    OZNITELIK.lastIndex = 0;
    while ((m = OZNITELIK.exec(govde))) o[m[1]] = m[2];
    const b = (o.bounds || '').match(/\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]/);
    if (!b) continue;
    const [x1, y1, x2, y2] = b.slice(1).map(Number);
    dugumler.push({
      desc: cozXmlKacis(o['content-desc'] || ''),
      metin: cozXmlKacis(o.text || ''),
      sinif: o.class || '',
      paket: o.package || '',
      tiklanabilir: o.clickable === 'true',
      secili: o.selected === 'true',
      odakli: o.focused === 'true',
      kaydirilabilir: o.scrollable === 'true',
      x1, y1, x2, y2,
      mx: Math.round((x1 + x2) / 2),
      my: Math.round((y1 + y2) / 2),
      en: x2 - x1,
      boy: y2 - y1,
    });
  }
  return dugumler;
}

function cozXmlKacis(s) {
  return s
    .replace(/&#10;/g, '\n').replace(/&amp;/g, '&').replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'");
}

/** Ekranın semantik ağacını al. uiautomator kararsızlıkta hata verir; tekrar dener. */
async function agac(deneme = 4) {
  for (let i = 0; i < deneme; i++) {
    try {
      const c = await kabuk('uiautomator dump /sdcard/dizijpg-ui.xml');
      if (!/dumped to/.test(c)) throw new Error(c.trim());
      const xml = await kabuk('cat /sdcard/dizijpg-ui.xml');
      const d = xmlCoz(xml);
      if (d.length) return d;
      throw new Error('boş ağaç');
    } catch (e) {
      ayrinti(`ağaç denemesi ${i + 1} başarısız: ${String(e.message).slice(0, 120)}`);
      await bekle(1200);
    }
  }
  throw new Error('Semantik ağaç alınamadı (uiautomator dump).');
}

/** Düğümün tüm aranabilir metni. */
const gövdeMetni = (d) => `${d.desc}\n${d.metin}`;

function ara(dugumler, desen, sec = {}) {
  const re = desen instanceof RegExp ? desen : new RegExp(desen);
  let liste = dugumler.filter((d) => re.test(gövdeMetni(d)));
  if (sec.tiklanabilir) liste = liste.filter((d) => d.tiklanabilir);
  if (sec.sinif) liste = liste.filter((d) => d.sinif.includes(sec.sinif));
  if (sec.enAz) liste = liste.filter((d) => d.en >= sec.enAz);
  return liste;
}

// ── kaydırarak arama ────────────────────────────────────────
//
// Kaydırmanın iki tuzağı var ve ikisi de 8 Ağu koşusunda görüntü kaybettirdi:
//  1) HIZLI sürükleme (≤400 ms) FIRLATMA sayılır; momentumla bir ekran boyundan
//     fazla gidip aranan satırı iki okuma arasında atlar.
//  2) Tek yönlü tarama, atlanan satırı bir daha göremez.
// Bu yüzden adımlar 450 px / 800 ms (momentumsuz) ve tarama önce aşağı, sonra
// yukarı. Liste dibe/başa dayandığında ağaç imzası donar; oradan yön değişir.

const KAYDIRMA_ADIMI = 450;
const KAYDIRMA_SURESI = 800;
const imzaAl = (d) => d.map((n) => `${n.y1}:${gövdeMetni(n).trim()}`).join('|');

/** Eşleşen düğümü bulana kadar listeyi yavaşça iki yöne tarar. */
async function tarayarakBul(esles, { enCok = 16, adim = KAYDIRMA_ADIMI } = {}) {
  for (const yon of ['asagi', 'yukari']) {
    let onceki = '';
    for (let i = 0; i < enCok; i++) {
      if (yon === 'asagi') await kaydir(540, 1500, 1500 - adim, KAYDIRMA_SURESI);
      else await kaydir(540, 1000, 1000 + adim, KAYDIRMA_SURESI);
      const d = await agac();
      const bulunan = d.find(esles);
      if (bulunan) { ayrinti(`tarama (${yon}) ${i + 1}. adımda buldu`); return bulunan; }
      const im = imzaAl(d);
      if (im === onceki) { ayrinti(`tarama (${yon}) dibe dayandı`); break; }
      onceki = im;
    }
  }
  return null;
}

/**
 * Bulunan düğümü DOKUNULABİLİR banda çeker. Ekranın en dibinde (gezinme
 * çubuğunun üstünde) duran bir satıra dokunmak sistem çubuğuna gidiyor;
 * alt sayfa açılmıyor ve hata bambaşka bir yerde patlıyordu.
 */
async function bandaGetir(esles, mevcut, { ust = 320, alt = 2050 } = {}) {
  let n = mevcut;
  for (let i = 0; i < 6; i++) {
    if (!n) return mevcut;
    if (n.my >= ust && n.my <= alt) return n;
    const fark = n.my > alt ? Math.min(700, n.my - alt + 250) : Math.min(700, ust - n.my + 250);
    if (n.my > alt) await kaydir(540, 1500, 1500 - fark, KAYDIRMA_SURESI);
    else await kaydir(540, 1000, 1000 + fark, KAYDIRMA_SURESI);
    n = (await agac()).find(esles) || null;
  }
  return n || mevcut;
}

/** Koşul sağlanana kadar ağacı yeniden okur. */
async function agacBekle(kosul, { sure = 15000, aralik = 900, ne = 'koşul' } = {}) {
  const bitis = Date.now() + sure;
  let son = null;
  while (Date.now() < bitis) {
    son = await agac();
    const sonuc = kosul(son);
    if (sonuc) return { dugumler: son, sonuc };
    await bekle(aralik);
  }
  throw new Error(`Zaman aşımı: ${ne}`);
}

// ─────────────────────────────────────────────────────────── girdi

async function dokunXY(x, y) {
  await kabuk(`input tap ${x} ${y}`);
  await bekle(450);
}
async function dokun(dugum) {
  ayrinti(`dokun → "${gövdeMetni(dugum).split('\n')[0]}" @${dugum.mx},${dugum.my}`);
  await dokunXY(dugum.mx, dugum.my);
}
async function yaz(metin) {
  // input text boşluk ve özel karakterleri sevmez
  const g = metin.replace(/(["`$\\])/g, '\\$1').replace(/ /g, '%s');
  await kabuk(`input text "${g}"`);
  await bekle(600);
}
async function tusla(tus) {
  await kabuk(`input keyevent ${tus}`);
  await bekle(500);
}
async function geri() { await tusla('KEYCODE_BACK'); }
async function klavyeKapat() {
  const c = await kabuk('dumpsys input_method | grep -E "mInputShown"');
  if (/mInputShown=true/.test(c)) { await geri(); await bekle(400); }
}
async function kaydir(x, y1, y2, sure = 400) {
  await kabuk(`input swipe ${x} ${y1} ${x} ${y2} ${sure}`);
  await bekle(900);
}

// ─────────────────────────────────────────────────────────── görüntü

let DONUSTURUCU = null;
async function donusturucuBul() {
  if (DONUSTURUCU) return DONUSTURUCU;
  for (const [ad, args] of [['cwebp', ['-version']], ['magick', ['-version']], ['convert', ['-version']]]) {
    try { await calis(ad, args); DONUSTURUCU = ad; break; } catch { /* yok */ }
  }
  if (!DONUSTURUCU) {
    try { await calis('sips', ['--help']); DONUSTURUCU = 'sips'; } catch { /* yok */ }
  }
  if (!DONUSTURUCU) throw new Error('WebP dönüştürücü yok (cwebp / magick / sips).');
  bilgi(`dönüştürücü: ${DONUSTURUCU}`);
  return DONUSTURUCU;
}

async function ekranGoruntusu(pngYolu) {
  const veri = await adbHam('exec-out', 'screencap', '-p');
  if (veri.length < 5000) throw new Error('screencap boş döndü');
  await writeFile(pngYolu, veri);
  return veri.length;
}

async function webpYap(png, webp, kalite = 82) {
  const d = await donusturucuBul();
  if (d === 'cwebp') {
    await calis('cwebp', ['-quiet', '-q', String(kalite), '-m', '6', png, '-o', webp]);
  } else if (d === 'magick' || d === 'convert') {
    await calis(d, [png, '-quality', String(kalite), webp]);
  } else {
    await calis('sips', ['-s', 'format', 'webp', '-s', 'formatOptions', String(kalite), png, '--out', webp]);
  }
  return (await stat(webp)).size;
}

// ─────────────────────────────────────────────────────────── durum çubuğu
//
// SystemUI "demo mode": saati 12:00'a sabitler, pili dolu, wifi tam gösterir.
// Neden: 276 görüntü ~6 saatte çekiliyor; demo mode olmadan her görüntüde saat
// farklı (19:41, 23:07, 01:22…), pil düşüyor, wifi'de "!" çıkıyordu. Rehberde
// yan yana duracak görüntülerin durum çubuğu AYNI olmalı.
// Uygulamayı DEĞİL, yalnız emülatörün kabuğunu etkiler; `cikis` ile geri alınır.

async function durumCubuguSabitle() {
  const yayin = async (...e) => {
    await kabuk(`am broadcast -a com.android.systemui.demo ${e.join(' ')}`).catch(() => {});
  };
  await kabuk('settings put global sysui_demo_allowed 1').catch(() => {});
  await yayin('-e command enter');
  await yayin('-e command clock -e hhmm 1200');
  await yayin('-e command battery -e level 100 -e plugged false');
  await yayin('-e command network -e wifi show -e level 4 -e fully true');
  await yayin('-e command network -e mobile hide');
  await yayin('-e command notifications -e visible false');
  await yayin('-e command status -e volume hide -e bluetooth hide -e location hide -e alarm hide -e sync hide -e tty hide -e eri hide -e mute hide -e speakerphone hide');
}

// ─────────────────────────────────────────────────────────── uygulama sürücüsü

async function uygulamaBaslat({ temiz = false } = {}) {
  if (temiz) await kabuk(`am force-stop ${PAKET}`).catch(() => {});
  await kabuk(`am start -n ${ETKINLIK}`);
  await bekle(temiz ? 6000 : 2500);
  await sistemDiyaloguGec();
}

/** Bildirim izni vb. sistem diyaloglarını geçer. */
async function sistemDiyaloguGec() {
  for (let i = 0; i < 3; i++) {
    const o = await odak();
    if (!/permissioncontroller|GrantPermissions/.test(o)) return;
    const d = await agac();
    const izin = d.find((n) => /permission_allow_button/.test(n.paket + n.sinif)) ||
      ara(d, /^(Allow|İzin ver|Permitir|Autoriser)$/i, { tiklanabilir: true })[0] ||
      d.filter((n) => n.tiklanabilir && n.sinif.includes('Button'))[0];
    if (izin) { await dokun(izin); await bekle(1500); } else return;
  }
}

/** Metinde sağdan-sola bir yazı sistemi var mı (Arapça, İbranice, Farsça, Urduca…). */
const SAGDAN_SOLA = /[֐-׿؀-ۿ܀-ݏݐ-ݿיִ-﷿ﹰ-﻿]/;

/**
 * Alt sekme çubuğunun 5 sekmesini bulur; dönen dizi HER ZAMAN mantıksal
 * sırada olur (0=Ana 1=Takvim 2=Akış 3=Keşfet 4=Profil).
 *
 * DİKKAT — RTL: ar/fa/ur/he'de çubuk AYNALANIR; Ana sayfa en SAĞDA, Profil en
 * SOLDA olur. Salt x'e göre sıralamak bu dillerde indeksleri ters çeviriyordu:
 * sekmeyeGit(4) Profil yerine Ana sayfaya dokunuyor, ardından "kullanıcı adı
 * okunamadı" ile boru hattı düşüyordu.
 *
 * Sağlam tutamak: Flutter her sekmeye kendi semantiğinde "Tab N of 5" sırasını
 * yazar (sözcükler yerelleşir, RAKAMLAR kalır). Sıra okunabiliyorsa ona güven;
 * okunamazsa RTL yazı sistemi tespitine, o da yoksa x sırasına düş.
 */
function sekmeler(dugumler) {
  const adaylar = dugumler.filter((d) => d.tiklanabilir && d.boy > 80 && d.boy < 220 && d.en > 100 && d.en < 400);
  if (!adaylar.length) return [];
  const enAlt = Math.max(...adaylar.map((d) => d.y1));
  const satir = adaylar.filter((d) => Math.abs(d.y1 - enAlt) < 40).sort((a, b) => a.x1 - b.x1);
  if (satir.length !== 5) return [];

  // 1) "… N … 5" kalıbından mantıksal sıra
  const sira = satir.map((n) => {
    const sayilar = [...n.desc.matchAll(/\d+/g)].map((m) => Number(m[0]));
    const i = sayilar.lastIndexOf(satir.length);
    return i > 0 ? sayilar[i - 1] : null;
  });
  if (sira.every((v) => v >= 1 && v <= satir.length) && new Set(sira).size === satir.length) {
    return satir.map((n, i) => ({ n, k: sira[i] })).sort((a, b) => a.k - b.k).map((o) => o.n);
  }

  // 2) Sıra okunamadı → yazı sisteminden yön tahmini
  if (SAGDAN_SOLA.test(dugumler.map(gövdeMetni).join(''))) {
    ayrinti('RTL düzen sezildi (sekme sırası okunamadı) — sekmeler ters çevrildi');
    return satir.slice().reverse();
  }
  return satir;
}

async function sekmeyeGit(indeks) {
  const { sonuc } = await agacBekle((d) => { const s = sekmeler(d); return s.length === 5 ? s : null; },
    { ne: 'alt sekme çubuğu' });
  await dokun(sonuc[indeks]);
  await bekle(1600);
}

// ── oturum ──────────────────────────────────────────────────

/** Şu an giriş yapmış kullanıcı adını profil sekmesinden okur (@ad). */
async function acikKullanici(deneme = 3) {
  for (let i = 0; i < deneme; i++) {
    try {
      await sekmeyeGit(4);
      const d = await agac();
      const m = d.map(gövdeMetni).join('\n').match(/@([a-z0-9._-]{2,30})/i);
      if (m) return m[1];
    } catch (e) {
      ayrinti(`kullanıcı okuma denemesi ${i + 1}: ${e.message}`);
    }
    await bekle(2000);
  }
  return null;
}

/**
 * Uygulama giriş ekranında mı, içeride mi? Tahmin ETMEZ.
 * Geçici bir ağaç okuma hatası yüzünden "giriş yapılmamış" sanıp giriş
 * denemesine kalkışmak, önceki turda boru hattını kilitledi.
 */
async function oturumDurumu() {
  for (let i = 0; i < 4; i++) {
    try {
      const d = await agac();
      if (sekmeler(d).length === 5) return 'ici';
      if (d.filter((n) => n.sinif.includes('EditText')).length >= 2) return 'giris';
    } catch (e) {
      ayrinti(`oturum durumu denemesi ${i + 1}: ${e.message}`);
    }
    await bekle(2500);
  }
  return 'bilinmiyor';
}

async function ayarlaraGit() {
  // Önceki ekran bizi tam sayfa bir rotada bırakmış olabilir (yorum yazma gibi);
  // sekme çubuğunu görene kadar geri çık.
  await tabanaDon();
  await sekmeyeGit(4);
  // Dişliyi ETİKETİNDEN bul: erişilebilirlik adı 46 dilden birinde "Ayarlar"
  // olan üst çubuk düğmesi.
  //
  // DİKKAT — RTL: eskiden "sağ üstteki küçük ikon" seçiliyordu. ar/fa/ur/he'de
  // üst çubuk da aynalanır; dişli SOL üste geçer, sağdaki ise "kişi ara"dır.
  // Konum yerine etiketle eşlemek hem dilden hem yönden bağımsız.
  const dislAdlari = await herDildeki('Ayarlar');
  const { sonuc } = await agacBekle((d) => {
    const ust = d.filter((n) => n.tiklanabilir && n.y2 < 400 && n.en < 200 && n.boy < 200);
    const etiketli = ust.find((n) => gövdeMetni(n).split('\n').some((s) => dislAdlari.has(s.trim())));
    if (etiketli) return etiketli;
    if (!ust.length) return null;
    // Etiket okunamazsa konuma düş — ama yönü doğru tahmin ederek.
    const rtl = SAGDAN_SOLA.test(d.map(gövdeMetni).join(''));
    return ust.sort((a, b) => (rtl ? a.x1 - b.x1 : b.x1 - a.x1))[0];
  }, { ne: 'ayarlar dişlisi' });
  await dokun(sonuc);
  await bekle(2200);
  return agac();
}

/** Bir Türkçe anahtarın TÜM dillerdeki karşılıkları — dil bilinmezken lazım. */
async function herDildeki(anahtar) {
  const kumme = new Set([anahtar]);
  await Promise.all(Object.keys(YEREL_ADLAR).map(async (k) => {
    try { kumme.add(cev(await ceviriYukle(k), anahtar)); } catch { /* dosya yoksa geç */ }
  }));
  return kumme;
}

async function cikisYap() {
  bilgi('mevcut oturum kapatılıyor…');
  // Uygulamanın o an hangi dilde olduğunu bilmiyoruz → 46 dilin hepsindeki
  // "Çıkış Yap" karşılığını kabul et.
  const adaylar = await herDildeki('Çıkış Yap');
  const d0 = await ayarlaraGit();
  const cikisMi = (n) => n.tiklanabilir &&
    gövdeMetni(n).split('\n').some((s) => adaylar.has(s.trim()));
  // Fırlatma yerine yavaş, çift yönlü tarama — bkz. tarayarakBul.
  let cikis = d0.find(cikisMi) || await tarayarakBul(cikisMi, { enCok: 18 });
  if (!cikis) throw new Error('Ayarlarda "Çıkış Yap" bulunamadı.');
  cikis = await bandaGetir(cikisMi, cikis);
  await dokun(cikis);
  await bekle(3000);
  return true;
}

async function girisYap() {
  bilgi(`test hesabına giriş: ${TEST_KULLANICI}`);
  const { sonuc } = await agacBekle((d) => {
    const alanlar = d.filter((n) => n.sinif.includes('EditText')).sort((a, b) => a.y1 - b.y1);
    return alanlar.length >= 2 ? alanlar : null;
  }, { sure: 20000, ne: 'giriş alanları' });

  await dokun(sonuc[0]);
  await kabuk('input keyevent KEYCODE_MOVE_END');
  for (let i = 0; i < 40; i++) await kabuk('input keyevent KEYCODE_DEL');
  await yaz(TEST_KULLANICI);
  await klavyeKapat();

  const d2 = await agac();
  const alanlar2 = d2.filter((n) => n.sinif.includes('EditText')).sort((a, b) => a.y1 - b.y1);
  await dokun(alanlar2[1]);
  await yaz(TEST_SIFRE);
  await klavyeKapat();

  // Giriş düğmesi: şifre alanının altındaki ilk geniş tıklanabilir öğe
  const d3 = await agac();
  const sifreY = alanlar2[1].y2;
  const dugme = d3.filter((n) => n.tiklanabilir && n.y1 >= sifreY && n.en > 500 && n.boy < 200)
    .sort((a, b) => a.y1 - b.y1)[0];
  if (!dugme) throw new Error('Giriş düğmesi bulunamadı.');
  await dokun(dugme);
  await bekle(6000);
  await sistemDiyaloguGec();
}

async function oturumHazirla({ kuru = false } = {}) {
  await uygulamaBaslat({ temiz: true });

  const durum = await oturumDurumu();
  if (durum === 'bilinmiyor') throw new Error('Uygulamanın oturum durumu okunamadı (ne sekme çubuğu ne giriş alanı bulundu).');
  if (durum === 'giris') {
    if (kuru) { bilgi('[kuru] giriş atlandı'); return; }
    await girisYap();
    const y = await acikKullanici();
    if (!y || y.toLowerCase() !== TEST_KULLANICI.toLowerCase()) throw new Error(`Giriş doğrulanamadı (bulunan @${y}).`);
    tamam(`giriş doğrulandı: @${y}`);
    return;
  }

  const ad = await acikKullanici();
  if (!ad) throw new Error('İçeridesin ama kullanıcı adı okunamadı — elle bak.');

  if (ad.toLowerCase() === TEST_KULLANICI.toLowerCase()) {
    tamam(`zaten test hesabı açık: @${ad}`);
    return;
  }
  if (ad) {
    if (YASAK_KULLANICILAR.includes(ad.toLowerCase())) uyari(`yasak/gerçek hesap açık: @${ad} — çıkış yapılıyor`);
    else uyari(`beklenmeyen hesap açık: @${ad} — çıkış yapılıyor`);
    if (kuru) { bilgi('[kuru] çıkış + giriş atlandı'); return; }
    await cikisYap();
    await bekle(2000);
  }
  if (kuru) { bilgi('[kuru] giriş atlandı'); return; }
  await girisYap();

  const yeni = await acikKullanici();
  if (!yeni || yeni.toLowerCase() !== TEST_KULLANICI.toLowerCase()) {
    throw new Error(`Giriş doğrulanamadı (beklenen @${TEST_KULLANICI}, bulunan @${yeni}).`);
  }
  tamam(`giriş doğrulandı: @${yeni}`);
}

// ── dil ─────────────────────────────────────────────────────

/**
 * Uygulama dilini uygulamanın kendi seçicisinden değiştirir.
 *
 * Neden UI? SharedPreferences'a doğrudan yazmak (`dil` anahtarı) çok daha hızlı
 * olurdu ama kurulu APK debuggable DEĞİL ve emülatör production build olduğu
 * için `adb root` da `run-as` da /data/data altına erişemiyor. Erişilebilseydi
 * bile Ceviri.dil bir ValueNotifier; süreç ayaktayken dosyayı değiştirmek
 * uygulamayı etkilemez, yeniden başlatma gerekirdi. Dolayısıyla UI tek yol.
 *
 * Dilden bağımsızlık: dil listesindeki adlar YEREL adlardır ('Türkçe',
 * 'English', '中文'), arayüz dili ne olursa olsun aynı yazılır. Ayarlardaki dil
 * satırının başlığı da o anki dilin yerel adıdır. Yani hem hedefi hem mevcut
 * durumu dilden bağımsız eşleyebiliyoruz.
 */
const YEREL_ADLAR = {
  tr: 'Türkçe', en: 'English', zh: '中文', hi: 'हिन्दी', es: 'Español', fr: 'Français',
  ar: 'العربية', bn: 'বাংলা', pt: 'Português', ru: 'Русский', ur: 'اردو',
  id: 'Bahasa Indonesia', de: 'Deutsch', ja: '日本語', sw: 'Kiswahili', mr: 'मराठी',
  te: 'తెలుగు', vi: 'Tiếng Việt', ko: '한국어', ta: 'தமிழ்', it: 'Italiano', fa: 'فارسی',
  pl: 'Polski', uk: 'Українська', ro: 'Română', nl: 'Nederlands', th: 'ไทย',
  gu: 'ગુજરાતી', kn: 'ಕನ್ನಡ', ml: 'മലയാളം', pa: 'ਪੰਜਾਬੀ', ms: 'Bahasa Melayu',
  my: 'မြန်မာ', am: 'አማርኛ', az: 'Azərbaycanca', el: 'Ελληνικά', hu: 'Magyar',
  cs: 'Čeština', sv: 'Svenska', he: 'עברית', fil: 'Filipino', sr: 'Српски',
  bg: 'Български', da: 'Dansk', fi: 'Suomi', nb: 'Norsk',
};

const kacis = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// ── çeviri sözlüğü (uygulamanın KENDİ tablosundan) ──────────
//
// Seçicileri "Yorum", "Ayarlar" gibi TÜRKÇE ÇEVİRİ ANAHTARLARI ile yazıyoruz;
// betik çalışırken lib/diller/dil_<kod>.dart dosyasını okuyup hedef dildeki
// karşılığını buluyor. Böylece veri dosyasında tek bir seçici var ama 46 dilde
// doğru metni arıyoruz. Sabit koordinat da, dile gömülü regex de gerekmiyor.
const DILLER_DIZINI = path.join(BURASI, '..', 'app', 'lib', 'diller');
const _ceviriOnbellek = new Map();

async function ceviriYukle(kod) {
  if (_ceviriOnbellek.has(kod)) return _ceviriOnbellek.get(kod);
  let harita = new Map();
  if (kod !== 'tr') {
    const yol = path.join(DILLER_DIZINI, `dil_${kod}.dart`);
    const kaynak = await readFile(yol, 'utf8');
    // 'anahtar': 'değer',   (değer bir sonraki satırda da olabilir)
    const re = /'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'\s*,/gs;
    let m;
    while ((m = re.exec(kaynak))) {
      harita.set(dartCoz(m[1]), dartCoz(m[2]));
    }
    if (!harita.size) throw new Error(`Çeviri okunamadı: ${yol}`);
  }
  _ceviriOnbellek.set(kod, harita);
  return harita;
}
const dartCoz = (s) => s.replace(/\\'/g, "'").replace(/\\\\/g, '\\').replace(/\\n/g, '\n');

/** Türkçe anahtarın verilen dildeki karşılığı (yoksa anahtarın kendisi). */
function cev(harita, anahtar) {
  return harita.get(anahtar) ?? anahtar;
}

// ── demo içeriğinin dili ────────────────────────────────────
//
// Arayüzü İspanyolca'ya çevirmek yetmiyor: kullanıcı İspanyolca karede
// profildeki BİYOGRAFİNİN ve ÜLKENİN hâlâ Türkçe olduğunu fark etti. Üç
// içerik parçasının üçü de farklı yoldan hizalanıyor:
//   • ülke  → app/lib/diller/ulkeler.dart (ham değer ISO koduna indirgenip
//             görünen ad o dilde yazılıyor) — uygulama kendi hallediyor.
//   • yorum → sunucudaki `metin_cevirileri` önbelleği. GET /ceviri/:id?dil=xx
//             ile 46 dil için önceden ısıtıldı; `ceviriUygula` hazır çeviriyi
//             kendiliğinden uyguluyor (backend/server.js:4627).
//   • bio   → burada. Sunucuda tek bir serbest metin alanı; her dil turundan
//             önce o dildeki karşılığıyla değiştiriliyor.
const API_TABAN = process.env.REHBER_API || 'https://dizijpg.com/api';
const BIO_DOSYA = path.join(BURASI, 'rehber-bio.json');
let _biolar = null;
let _jeton = null;

async function jetonAl() {
  if (_jeton) return _jeton;
  const c = await fetch(`${API_TABAN}/auth/giris`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: TEST_KULLANICI, sifre: TEST_SIFRE }),
  });
  const d = await c.json().catch(() => ({}));
  if (!c.ok || !d.token) throw new Error(`API girişi başarısız (${c.status}): ${d.hata || ''}`);
  _jeton = d.token;
  return _jeton;
}

/** Demo hesabın biyografisini hedef dile çevirir. Başarısızlık koşuyu düşürmez. */
async function demoBioAyarla(kod) {
  if (!_biolar) {
    _biolar = JSON.parse(await readFile(BIO_DOSYA, 'utf8'));
  }
  const bio = _biolar[kod];
  if (!bio) { uyari(`${kod}: rehber-bio.json'da bio yok — bio değiştirilmedi`); return; }
  const jeton = await jetonAl();
  const c = await fetch(`${API_TABAN}/profilim`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${jeton}` },
    body: JSON.stringify({ bio }),
  });
  if (!c.ok) throw new Error(`bio yazılamadı (${c.status})`);
  ayrinti(`bio → ${bio.slice(0, 48)}…`);
}

async function dilSec(kod) {
  const hedef = YEREL_ADLAR[kod];
  if (!hedef) throw new Error(`Bilinmeyen dil kodu: ${kod}`);
  const tumAdlar = Object.values(YEREL_ADLAR);

  const d0 = await ayarlaraGit();

  // Dil satırı: başlığı bir YEREL dil adı olan tıklanabilir satır.
  //
  // KÖK NEDEN (8 Ağu: ru ve bg "Ayarlarda dil satırı bulunamadı" ile düştü):
  // burası eskiden 900 px'i 400 ms'de alan FIRLATMALARLA yalnız AŞAĞI tarıyordu.
  // Fırlatmanın momentumu bir ekran boyundan fazla kaydırabildiği için Dil
  // satırı iki ağaç okuması ARASINDA atlanabiliyor; döngü hiç yukarı dönmediği
  // için satır bir daha görülmüyordu. Nereden başlandığı bir önceki dilin metin
  // uzunluklarına bağlı olduğundan hata dile göre değişiyor ve rastgele
  // görünüyordu. Çözüm: yavaş (momentumsuz) küçük adımlar + ÇİFT YÖNLÜ tarama +
  // liste dibe dayandığında yön değiştirme.
  const dilSatiriMi = (n) => n.tiklanabilir && !n.sinif.includes('EditText') &&
    tumAdlar.includes(gövdeMetni(n).trim());
  let satir = d0.find(dilSatiriMi) || await tarayarakBul(dilSatiriMi);
  if (!satir) throw new Error('Ayarlarda dil satırı bulunamadı.');
  // Satır ekranın en dibinde (gezinme çubuğu bandında) kalmış olabilir; oraya
  // dokunmak sistem çubuğuna gider ve alt sayfa hiç açılmaz.
  satir = await bandaGetir(dilSatiriMi, satir);

  const mevcut = gövdeMetni(satir).trim();
  if (mevcut === hedef) { tamam(`dil zaten ${hedef} (${kod})`); await geri(); await bekle(1200); return; }

  await dokun(satir);
  await bekle(1500);

  // Alt sayfadaki arama kutusunu KULLANMIYORUZ, listeyi kaydırıyoruz. İki neden:
  //  1) `adb shell input text` yalnız ASCII yazabilir; 46 dilin çoğunun yerel adı
  //     (中文, हिन्दी, العربية…) yazılamaz.
  //  2) Kutunun onChanged'i her tuşta alt sayfayı yeniden kuruyor; hızlı gelen
  //     karakterler bozuluyor ("English" yerine "EEn" yazıldı, liste boş kaldı).
  // Liste 46 satır; birkaç kaydırmayla her dil bulunuyor.
  //
  // DİKKAT: arama kutusunun metni de bir dil adı olabilir. EditText'leri
  // ELEMEZSEK betik kutuya dokunup dili değiştirmeden "değişti" sanır.
  //
  // Kaydırma burada da YAVAŞ ve ÇİFT YÖNLÜ: 46 satırlık listede 650 px'lik
  // fırlatma bir ekranı aşıp hedef dili atlayabiliyordu ve döngü yalnız aşağı
  // gittiği için dil bir daha görünmüyordu ("Dil listesi sonuna gelindi").
  const listeOgesi = (n) => n.tiklanabilir && !n.sinif.includes('EditText');
  const secenekMi = (n) => listeOgesi(n) && gövdeMetni(n).trim() === hedef;
  let secenek = (await agac()).find(secenekMi) || await tarayarakBul(secenekMi, { enCok: 26 });
  if (!secenek) throw new Error(`Dil listesinde "${hedef}" bulunamadı.`);
  secenek = await bandaGetir(secenekMi, secenek, { ust: 420 });
  await dokun(secenek);
  await bekle(2500);

  // Doğrula — İKİ bağımsız kanıt istiyoruz:
  //  1) alt sayfa kapandı ve ayarlardaki dil satırı hedef yerel adı gösteriyor,
  //  2) ayarlar ekranındaki "Tema" başlığı HEDEF DİLDE yazılmış
  //     (yani arayüz gerçekten yeniden kuruldu, yalnız satır metni değişmedi).
  const hedefTema = cev(await ceviriYukle(kod), 'Tema');
  await agacBekle((d) => {
    const govde = d.map(gövdeMetni).join('\n');
    const satir = d.find((n) => listeOgesi(n) && tumAdlar.includes(gövdeMetni(n).trim()));
    const kutuVar = d.some((n) => n.sinif.includes('EditText') && tumAdlar.includes(gövdeMetni(n).trim()));
    return (!kutuVar && satir && gövdeMetni(satir).trim() === hedef && govde.includes(hedefTema)) ? satir : null;
  }, { sure: 20000, ne: `dil doğrulaması (satır "${hedef}" + "Tema"→"${hedefTema}")` });

  tamam(`dil → ${hedef} (${kod})`);
  await geri();
  await bekle(1500);
}

// ─────────────────────────────────────────────────────────── adım yorumlayıcı

async function adimUygula(adim, baglam) {
  switch (adim.tur) {
    case 'sekme':
      await sekmeyeGit(adim.indeks);
      return;
    case 'ayarlar':
      await ayarlaraGit();
      return;
    case 'geri':
      await geri();
      await bekle(adim.ms ?? 1200);
      return;
    case 'bekle':
      await bekle(adim.ms ?? 1500);
      return;
    case 'kaydir':
      await kaydir(adim.x ?? 540, adim.y1 ?? 1600, adim.y2 ?? 900, adim.sure ?? 400);
      return;
    case 'yaz':
      await yaz(adim.metin);
      await klavyeKapat();
      return;
    case 'dokunCeviri': {
      // Türkçe anahtarın hedef dildeki karşılığını taşıyan tıklanabilir öğe.
      const hedef = cev(baglam.ceviri, adim.anahtar);
      ayrinti(`çeviri "${adim.anahtar}" → "${hedef}"`);
      const bul = (d) => {
        // Yalnız TAM satır eşleşmesi: "Yorum" ararken "Yorumlar"a dokunmayalım.
        let liste = d.filter((n) => n.tiklanabilir && gövdeMetni(n).split('\n').some((s) => s.trim() === hedef));
        if (!liste.length && adim.gevsek) liste = d.filter((n) => n.tiklanabilir && gövdeMetni(n).includes(hedef));
        return liste[adim.sira ?? 0] || null;
      };
      let dugum = null;
      const tur = adim.kaydirarak ?? 0;
      for (let i = 0; i <= tur && !dugum; i++) {
        dugum = bul(await agac());
        if (!dugum && i < tur) await kaydir(540, adim.kY1 ?? 1900, adim.kY2 ?? 900, 350);
      }
      if (!dugum) {
        const { sonuc } = await agacBekle(bul, { sure: adim.sure ?? 10000, ne: `çeviri öğesi "${hedef}"` });
        dugum = sonuc;
      }
      await dokun(dugum);
      await bekle(adim.ms ?? 1800);
      return;
    }
    case 'tazele': {
      // Aşağı çekip yenile (RefreshIndicator).
      //
      // NEDEN GEREKLİ: uygulamanın önbellek anahtarları dile göre ayrılmamış
      // (ör. lib/ekranlar/takvim.dart → Onbellek.okuKayit('takvim')). Dil
      // değişince ekran ÖNCE eski dildeki önbelleği boyuyor, arka planda taze
      // veri gelince düzeliyor. Yenilemeden çekilen görüntüde arayüz İngilizce
      // ama bölüm adları Türkçe kalıyordu. Bu uygulama tarafında bir kusur;
      // burada yalnız telafi ediyoruz (app/lib bu turda değiştirilmiyor).
      await kabuk(`input swipe 540 ${adim.y1 ?? 700} 540 ${adim.y2 ?? 1900} ${adim.sure ?? 500}`);
      await bekle(adim.ms ?? 5000);
      return;
    }
    case 'dokunGoreli': {
      // Çevrilmiş bir öğeyi çıpa alıp ona GÖRE bir noktaya dokun.
      // Gerekçe: Flutter'ın TextField'ı odaklanana kadar semantik ağaçta
      // görünmüyor; ama yerini komşusundan (fotoğraf ekle düğmesi) biliyoruz.
      const hedef = cev(baglam.ceviri, adim.anahtar);
      const { sonuc } = await agacBekle(
        (d) => d.find((n) => gövdeMetni(n).split('\n').some((s) => s.trim() === hedef)) || null,
        { sure: adim.sure ?? 10000, ne: `çıpa "${hedef}"` });
      const x = adim.x ?? sonuc.mx;
      const y = adim.ofsetY != null ? sonuc.y1 + adim.ofsetY : sonuc.my;
      ayrinti(`çıpa "${hedef}" @${sonuc.x1},${sonuc.y1} → dokun ${x},${y}`);
      await dokunXY(x, y);
      await bekle(adim.ms ?? 1200);
      return;
    }
    case 'kaydirHedef': {
      // Çevrilmiş bir öğe kadrajın İSTENEN BANDINA gelene kadar kaydır.
      // Gerekçe: Ayarlar ekranının amacı "dil nerede seçilir"i göstermek ama
      // Dil satırı sayfanın altında; sabit kaydırma da 46 dilde farklı yere
      // düşüyor (metin uzunlukları değişik). Öğeyi çıpalayıp bandına oturtmak
      // dilden bağımsız tek güvenilir yol.
      const hedef = cev(baglam.ceviri, adim.anahtar);
      const ust = adim.ustSinir ?? 400;
      const alt = adim.altSinir ?? 1000;
      const yeri = async () => {
        const d = await agac();
        const n = d.find((x) => gövdeMetni(x).split('\n').some((s) => s.trim() === hedef));
        return n ? n.y1 : null;
      };
      for (let i = 0; i < (adim.enCok ?? 12); i++) {
        const y = await yeri();
        // Kaydırma bir FIRLATMA'dır: momentum sürerken okunan konum yalancıdır.
        // İlk ölçümde bandda görünüp, görüntü alınana kadar liste geri yaylanıp
        // hedefi ekranın dibine bırakıyordu (ölçüm y=636, görüntüde y≈2030).
        // Bu yüzden konumun OTURDUKTAN SONRA da bandda olmasını şart koşuyoruz.
        if (y != null && y >= ust && y <= alt) {
          await bekle(1400);
          const y2 = await yeri();
          if (y2 != null && y2 >= ust && y2 <= alt) { ayrinti(`çıpa "${hedef}" bandında (y=${y2}, oturdu)`); return; }
          ayrinti(`çıpa "${hedef}" oturmadı (${y}→${y2}) — kaydırma sürüyor`);
          continue;
        }
        const n = y == null ? null : { y1: y };
        // Öğe bandın altındaysa yukarı kaydır, üstündeyse aşağı.
        // Yavaş (900 ms) sürükleme momentumu en aza indirir; firlatma olmasın.
        const yukari = !n || n.y1 > alt;
        if (yukari) await kaydir(540, adim.kY1 ?? 1700, adim.kY2 ?? 1250, 900);
        else await kaydir(540, adim.kY2 ?? 1250, adim.kY1 ?? 1700, 900);
      }
      uyari(`"${hedef}" istenen banda getirilemedi — doğrulama karar verecek`);
      return;
    }
    case 'dokunGeo': {
      // Salt geometrik seçim: metinden tamamen bağımsız (arama çubuğu vb.).
      const { sonuc } = await agacBekle((d) => {
        let l = d.filter((n) => n.tiklanabilir);
        if (adim.ustte != null) l = l.filter((n) => n.y2 <= adim.ustte);
        if (adim.altta != null) l = l.filter((n) => n.y1 >= adim.altta);
        if (adim.enAz != null) l = l.filter((n) => n.en >= adim.enAz);
        if (adim.enCok != null) l = l.filter((n) => n.en <= adim.enCok);
        if (adim.boyEnAz != null) l = l.filter((n) => n.boy >= adim.boyEnAz);
        l.sort((a, b) => (a.y1 - b.y1) || (a.x1 - b.x1));
        return l[adim.sira ?? 0] || null;
      }, { sure: adim.sure ?? 12000, ne: 'geometrik öğe' });
      await dokun(sonuc);
      await bekle(adim.ms ?? 1500);
      return;
    }
    case 'yazAscii': {
      // Dil başına örnek metin. `input text` ASCII dışını yazamaz; ASCII
      // olmayan metinler sessizce atlanır (uyarı ile).
      // DİKKAT: metin yazılmasa bile klavye KAPATILMALI. Yazma atlandığında
      // klavye açık kalıyor ve ekranın yarısını kaplıyordu; tr/en görüntüleri
      // (metin yazılıp klavye kapandığı için) diğer 44 dilden farklı çıkıyordu.
      const metin = adim.metinler?.[baglam.dil] ?? adim.metin;
      if (!metin) { await klavyeKapat(); return; }
      if (!/^[\x20-\x7E]*$/.test(metin)) {
        uyari(`"${baglam.dil}" örnek metni ASCII değil, yazılmadı (adb input text sınırı)`);
        await klavyeKapat();
        return;
      }
      await yaz(metin);
      await klavyeKapat();
      return;
    }
    case 'dokunDesen': {
      const { sonuc } = await agacBekle((d) => {
        let liste = ara(d, new RegExp(adim.desen, adim.bayrak || ''), { tiklanabilir: adim.tiklanabilir !== false });
        if (adim.enAz) liste = liste.filter((n) => n.en >= adim.enAz);
        if (adim.ustte) liste = liste.filter((n) => n.y2 <= adim.ustte);
        return liste[adim.sira ?? 0] || null;
      }, { sure: adim.sure ?? 15000, ne: `dokunulacak öğe /${adim.desen}/` });
      await dokun(sonuc);
      await bekle(adim.ms ?? 1500);
      return;
    }
    case 'dokunAlan': {
      // metin girişi alanı (EditText), üstten sıraya göre
      const { sonuc } = await agacBekle((d) => {
        const a = d.filter((n) => n.sinif.includes('EditText')).sort((x, y) => x.y1 - y.y1);
        return a[adim.sira ?? 0] || null;
      }, { sure: adim.sure ?? 12000, ne: 'metin alanı' });
      await dokun(sonuc);
      return;
    }
    case 'ilkKart': {
      // İçerik ızgarasındaki ilk poster kartı: puan+başlık biçimli content-desc
      const { sonuc } = await agacBekle((d) => {
        const kartlar = d.filter((n) => n.tiklanabilir && /^\d+([.,]\d+)?\n.+/s.test(n.desc) && n.boy > 150)
          .sort((a, b) => (a.y1 - b.y1) || (a.x1 - b.x1));
        return kartlar[adim.sira ?? 0] || null;
      }, { sure: adim.sure ?? 15000, ne: 'içerik kartı' });
      baglam.kartBasligi = sonuc.desc.split('\n').slice(1).join(' ').trim();
      ayrinti(`kart: ${baglam.kartBasligi}`);
      await dokun(sonuc);
      await bekle(adim.ms ?? 3000);
      return;
    }
    default:
      throw new Error(`Bilinmeyen adım türü: ${adim.tur}`);
  }
}

// ─────────────────────────────────────────────────────────── doğrulama

/**
 * Doğru ekranda mıyız? Üç katman:
 *  1) uygulama önde mi (yabancı Activity'ye kaçmadık mı),
 *  2) `gerekli` desenlerinin HEPSİ semantik ağaçta var mı,
 *  3) `olmamali` desenlerinden HİÇBİRİ yok mu (yanlış ekran ayırt edici).
 * Desenler dilden bağımsız olacak şekilde seçilir (yapısal ipuçları, sayılar,
 * içerik başlıkları, ikon etiketleri değil).
 */
async function dogrula(ekran, dugumler, baglam, izinliKullanicilar = []) {
  const sorunlar = [];
  if (!(await uygulamaOnde())) sorunlar.push(`odak uygulamada değil: ${await odak()}`);

  const govde = dugumler.map(gövdeMetni).join('\n');

  // (a) Dilden bağımsız yapısal/içerik desenleri
  for (const desen of ekran.dogrula?.gerekli || []) {
    if (!new RegExp(desen, 's').test(govde)) sorunlar.push(`beklenen desen yok: /${desen}/`);
  }
  // (b) Çeviri anahtarları: HEDEF DİLDEKİ karşılığı ekranda olmalı.
  //     Bu aynı anda "doğru ekran mı" VE "dil gerçekten değişti mi" testidir.
  for (const anahtar of ekran.dogrula?.ceviriGerekli || []) {
    const hedef = cev(baglam.ceviri, anahtar);
    if (!govde.includes(hedef)) sorunlar.push(`"${anahtar}" → "${hedef}" ekranda yok`);
  }
  // (c) Ayırt edici olumsuzlar: yanlış ekrandaysak bunlar görünür.
  for (const desen of ekran.dogrula?.olmamali || []) {
    if (new RegExp(desen, 's').test(govde)) sorunlar.push(`olmaması gereken desen var: /${desen}/`);
  }
  for (const anahtar of ekran.dogrula?.ceviriOlmamali || []) {
    const hedef = cev(baglam.ceviri, anahtar);
    if (govde.includes(hedef)) sorunlar.push(`"${anahtar}" → "${hedef}" ekranda OLMAMALIYDI`);
  }
  // (c2) TÜRKÇE KALINTI — arayüz çevrildi ama İÇERİK eski dilde kaldıysa.
  // Uygulamanın önbellek anahtarları dile göre ayrılmadığı için ekran önce
  // eski dildeki veriyi boyuyor. ar/takvim görüntüsünde arayüz Arapça, bölüm
  // adları "8. Bölüm" (Türkçe) çıkmıştı; üstelik yenileme çarkı hâlâ dönüyordu.
  // Bu desenler tr DIŞINDAKİ dillerde görünürse görüntü kaydedilmez, yeniden
  // denenir — yani tazelemeye fazladan bir tur daha verilmiş olur.
  if (baglam.dil !== 'tr') {
    for (const desen of ekran.dogrula?.trOlmamali || []) {
      if (new RegExp(desen, 's').test(govde)) sorunlar.push(`Türkçe kalıntı (önbellek tazelenmemiş): /${desen}/`);
    }
  }
  // (d) Alt sekme çubuğu beklentisi (tam sayfa rotalarda yoktur)
  const sekmeVar = sekmeler(dugumler).length === 5;
  if (ekran.dogrula?.sekmeCubugu === true && !sekmeVar) sorunlar.push('alt sekme çubuğu yok (tam sayfa rotadayız)');
  if (ekran.dogrula?.sekmeCubugu === false && sekmeVar) sorunlar.push('alt sekme çubuğu VAR (kök sekmedeyiz, hedef ekranda değiliz)');
  // (e) Seçili sekme indeksi
  if (ekran.dogrula?.seciliSekme != null && sekmeVar) {
    const s = sekmeler(dugumler);
    const secili = s.findIndex((n) => n.secili);
    if (secili !== ekran.dogrula.seciliSekme) sorunlar.push(`seçili sekme ${secili}, beklenen ${ekran.dogrula.seciliSekme}`);
  }

  const enAz = ekran.dogrula?.enAzDugum ?? 8;
  if (dugumler.length < enAz) sorunlar.push(`ağaç çok küçük (${dugumler.length} < ${enAz}) — ekran yüklenmemiş olabilir`);

  // Gizlilik: test hesabı ve izinli hesaplar dışında bir @kullanıcı görünüyorsa uyar.
  const izinli = new Set([TEST_KULLANICI.toLowerCase(), ...izinliKullanicilar.map((s) => s.toLowerCase())]);
  const kullanicilar = [...govde.matchAll(/@([a-z0-9._-]{2,30})/gi)].map((m) => m[1].toLowerCase());
  const yabanci = [...new Set(kullanicilar)].filter((u) => !izinli.has(u));
  return { sorunlar, yabanci };
}

// ─────────────────────────────────────────────────────────── ana akış

// ─────────────────────────────────────────────────────────── ilerleme dosyası
//
// 46 dil × 6 ekran uzun bir koşu (~5-7 saat). Koşu arkaplanda dönerken nerede
// olduğunu görebilmek için her ekrandan sonra tek bir JSON'a durum yazılır.
// Betik ayrıca KALDIĞI YERDEN devam eder (var olan .webp atlanır), bu yüzden
// kesilirse dosya silinmez; yeni koşu üstüne yazar.

const ILERLEME = path.join(CIKTI, '_ilerleme.json');

async function ilerlemeYaz(durum) {
  try {
    await writeFile(ILERLEME, JSON.stringify({ ...durum, guncellendi: new Date().toISOString() }, null, 2));
  } catch { /* ilerleme yazımı koşuyu düşürmesin */ }
}

async function ekranlariOku(ozelYol) {
  const yol = ozelYol ? path.resolve(ozelYol) : path.join(BURASI, 'rehber-ekranlar.json');
  return JSON.parse(await readFile(yol, 'utf8'));
}

async function cek(sec) {
  const veri = await ekranlariOku(sec.veri);
  const diller = sec.diller;
  const ekranlar = veri.ekranlar.filter((e) => !sec.ekranlar || sec.ekranlar.includes(e.ad));
  if (!ekranlar.length) throw new Error('Eşleşen ekran yok.');

  await donusturucuBul();
  const cihaz = await emulatorVarMi();
  bilgi(`cihaz: ${cihaz}  |  ${diller.length} dil × ${ekranlar.length} ekran = ${diller.length * ekranlar.length} görüntü`);
  if (sec.kuru) uyari('KURU ÇALIŞTIRMA — dosya yazılmayacak, uygulama sürülmeyecek');

  await mkdir(GECICI, { recursive: true });
  const rapor = [];

  if (!sec.kuru) { await cihazHazirla(); bilgi('cihaz hazırlandı (hata diyalogları kapalı, animasyon yok)'); }
  if (!sec.kuru && !sec.demoYok) { await durumCubuguSabitle(); bilgi('durum çubuğu sabitlendi (12:00, pil dolu, wifi tam)'); }
  if (!sec.kuru) await oturumHazirla({ kuru: sec.kuru });
  else bilgi('[kuru] oturum hazırlığı atlandı');

  const basladi = Date.now();
  const sayac = { dogrulamaRed: 0, gizlilikUyarisi: [] };
  const dilDurum = {};
  const durumYaz = () => ilerlemeYaz({
    basladi: new Date(basladi).toISOString(),
    gecenDk: Number(((Date.now() - basladi) / 60000).toFixed(1)),
    hedef: { dil: diller.length, ekran: ekranlar.length, gorsel: diller.length * ekranlar.length },
    tamamlanan: rapor.filter((r) => !r.hata).length,
    basarisiz: rapor.filter((r) => r.hata).length,
    dogrulamaReddi: sayac.dogrulamaRed,
    gizlilikUyarisi: sayac.gizlilikUyarisi,
    diller: dilDurum,
    hatalar: rapor.filter((r) => r.hata).map((r) => `${r.dil}/${r.ekran}: ${r.hata}`),
  });

  for (const dil of diller) {
    const klasor = path.join(CIKTI, dil);
    await mkdir(klasor, { recursive: true });

    const eksik = ekranlar.filter((e) => sec.zorla || !existsSync(path.join(klasor, `${e.ad}.webp`)));
    if (!eksik.length) { tamam(`${dil}: hepsi zaten var, atlanıyor`); dilDurum[dil] = 'zaten var'; await durumYaz(); continue; }

    console.log(`\n${R.mav}━━ dil: ${dil} (${YEREL_ADLAR[dil]}) — ${eksik.length} ekran ━━${R.sif}`);
    if (sec.kuru) {
      for (const e of eksik) console.log(`  [kuru] ${dil}/${e.ad}.webp  ← ${e.aciklama}`);
      continue;
    }

    dilDurum[dil] = 'işleniyor';
    await durumYaz();
    // SystemUI yeniden başlarsa demo mode düşer; dil başına yeniden uygula.
    if (!sec.demoYok) await durumCubuguSabitle();

    // TEK DİL DÜŞSE DE KOŞU DEVAM EDER.
    // Eskiden dilSec() ve ceviriYukle() döngünün İÇİNDE ama try'ın DIŞINDAydı;
    // 40. dilde bir dil seçici hatası tüm koşuyu düşürüp önceki 39 dilin
    // özetini de yazdırmadan çıkıyordu. 46 dilin 45'ini bitirmek, hiçbirini
    // bitirmemekten iyidir.
    let ceviri;
    try {
      let dilHatasi = null;
      for (let d = 0; d < 2; d++) {
        try { await dilSec(dil); dilHatasi = null; break; } catch (e) {
          dilHatasi = e;
          uyari(`${dil}: dil seçilemedi (${e.message}) — uygulama yeniden başlatılıp tekrar denenecek`);
          await uygulamaBaslat({ temiz: true }).catch(() => {});
        }
      }
      if (dilHatasi) throw dilHatasi;

      // Bio'yu SOĞUK BAŞLATMADAN ÖNCE yaz ki uygulama açılışta zaten hedef
      // dildeki metni çeksin (profil ayrıca `tazele` ile bir kez daha yeniler).
      if (!sec.icerikYok) {
        await demoBioAyarla(dil).catch((e) => uyari(`${dil}: bio ayarlanamadı — ${e.message}`));
      }

      // DİL DEĞİŞİMİNDEN SONRA SOĞUK BAŞLATMA — şart.
      // Uygulama kabuğu (üst bardaki arama hapı) çalışırken dil değişince
      // YENİDEN KURULMUYOR: 'Arama'.c eski dilde donup kalıyor. Kanıt: tr, ar
      // ve ja ana sayfa görüntülerinin ÜÇÜNDE de hap "Search" yazıyordu
      // (Türkçede "Arama" olmalıydı). force-stop sonrası açılışta doğru
      // geliyor ("検索"). Kabuk her görüntüde kadrajda olduğu için bu, 46 dilin
      // ana sayfa görselini birden bozuyordu.
      await uygulamaBaslat({ temiz: true });
      ceviri = await ceviriYukle(dil);
    } catch (e) {
      hata(`${dil}: ATLANDI — ${e.message}`);
      dilDurum[dil] = `ATLANDI: ${e.message}`;
      for (const ek of eksik) rapor.push({ dil, ekran: ek.ad, hata: `dil kurulamadı: ${e.message}` });
      await uygulamaBaslat({ temiz: true }).catch(() => {});
      await durumYaz();
      continue;
    }

    for (const ekran of eksik) {
      const etiket = `${dil}/${ekran.ad}`;
      let denendi = 0;
      while (true) {
        denendi++;
        try {
          bilgi(`${etiket} — gidiliyor…`);
          // Her ekran bilinen bir kökten başlar: uygulamayı tabana çek
          await tabanaDon();
          const baglam = { dil, ceviri };
          for (const adim of ekran.git) await adimUygula(adim, baglam);
          await bekle(ekran.bekle ?? 1200);

          const dugumler = await agac();
          const { sorunlar, yabanci } = await dogrula(ekran, dugumler, baglam, veri.izinliKullanicilar || []);
          if (sorunlar.length) { sayac.dogrulamaRed++; throw new Error(`doğrulama başarısız → ${sorunlar.join(' | ')}`); }
          // GİZLİLİK — SERT RED. Bu görüntüler sunucuda YAYIMLANIYOR; kadraja
          // giren her @ad tüm kullanıcılara gösterilecek demektir. Eskiden
          // yalnız uyarı basılıp kare yine de kaydediliyordu; "sonra gözden
          // geçiririm" 276 karede işlemez. Artık kare atılır ve yeniden denenir.
          if (yabanci.length) {
            sayac.gizlilikUyarisi.push(`${etiket}: @${yabanci.join(', @')}`);
            throw new Error(`GİZLİLİK: kadrajda izinsiz hesap (@${yabanci.join(', @')}) — kare atıldı`);
          }

          const png = path.join(GECICI, `${dil}-${ekran.ad}.png`);
          const pngBoyut = await ekranGoruntusu(png);
          const webp = path.join(klasor, `${ekran.ad}.webp`);
          const webpBoyut = await webpYap(png, webp, veri.kalite ?? 82);
          await rm(png, { force: true });
          tamam(`${etiket}.webp — ${(webpBoyut / 1024).toFixed(1)} KB (png ${(pngBoyut / 1024).toFixed(0)} KB)`);
          rapor.push({ dil, ekran: ekran.ad, yol: webp, boyut: webpBoyut, yabanci });
          break;
        } catch (e) {
          if (denendi >= (sec.deneme ?? 2)) { hata(`${etiket}: ${e.message}`); rapor.push({ dil, ekran: ekran.ad, hata: e.message }); break; }
          uyari(`${etiket}: ${e.message} — yeniden deneniyor (${denendi})`);
          await uygulamaBaslat({ temiz: true }).catch(() => {});
        }
      }
      await durumYaz();
    }

    const dilHata = rapor.filter((r) => r.dil === dil && r.hata).length;
    dilDurum[dil] = dilHata ? `bitti (${dilHata} hata)` : 'bitti';
    await durumYaz();
  }

  await durumYaz();

  if (!sec.kuru) ozet(rapor, sayac, basladi);
  return rapor;
}

/** Bilinen köke dön: uygulamayı öne al, açık sayfa/sheet varsa kapat, ana sekme. */
/**
 * ANR/çökme penceresi odağı çalmışsa kapatır. `hide_error_dialogs` bunları
 * normalde hiç göstermiyor ama SystemUI kendini yeniden kurduğunda ayar
 * sıfırlanabiliyor; o zaman uiautomator uygulamayı değil diyaloğu okuyor.
 */
async function anrGec() {
  const o = await odak().catch(() => '');
  if (!/Not Responding|has stopped|keeps stopping/i.test(o)) return false;
  uyari(`hata penceresi açık (${o.slice(0, 60)}) — kapatılıyor`);
  await cihazHazirla();
  const d = await agac().catch(() => []);
  const dugme = d.find((n) => n.tiklanabilir && /^(Wait|Bekle|Close app|Uygulamayı kapat|OK|Tamam)$/i.test(gövdeMetni(n).trim()));
  if (dugme) await dokun(dugme); else await geri();
  await bekle(1500);
  return true;
}

async function tabanaDon() {
  await anrGec();
  if (!(await uygulamaOnde())) await uygulamaBaslat({ temiz: false });
  for (let i = 0; i < 6; i++) {
    const d = await agac().catch(() => []);
    if (sekmeler(d).length === 5) return;
    await geri();
    await bekle(700);
    if (!(await uygulamaOnde())) await uygulamaBaslat({ temiz: false });
  }
}

function ozet(rapor, sayac, basladi) {
  const ok = rapor.filter((r) => !r.hata);
  const kotu = rapor.filter((r) => r.hata);
  const toplam = ok.reduce((a, r) => a + r.boyut, 0);
  console.log(`\n${R.mav}━━ özet ━━${R.sif}`);
  for (const r of kotu) console.log(`  ${R.kir}${r.dil}/${r.ekran} — ${r.hata}${R.sif}`);
  console.log(`  ${ok.length} görüntü, toplam ${(toplam / 1024 / 1024).toFixed(2)} MB` + (kotu.length ? `, ${kotu.length} HATA` : ''));
  if (sayac) {
    console.log(`  doğrulama reddi: ${sayac.dogrulamaRed} (görüntü kaydedilmedi, yeniden denendi)`);
    console.log(`  gizlilik uyarısı: ${sayac.gizlilikUyarisi.length ? sayac.gizlilikUyarisi.join(' ; ') : 'yok'}`);
  }
  if (basladi) console.log(`  süre: ${((Date.now() - basladi) / 60000).toFixed(1)} dk`);
}

// ─────────────────────────────────────────────────────────── probe (geliştirme)

async function probe(sec) {
  const d = await agac();
  console.log(`odak: ${await odak()}`);
  console.log(`düğüm: ${d.length}`);
  const suz = sec.desen ? new RegExp(sec.desen, 'i') : null;
  for (const n of d) {
    const t = gövdeMetni(n).trim();
    if (!t) continue;
    if (suz && !suz.test(t)) continue;
    console.log(`  [${n.x1},${n.y1}-${n.x2},${n.y2}] ${n.tiklanabilir ? 'TIK ' : '    '}${n.sinif.split('.').pop()} :: ${JSON.stringify(t).slice(0, 200)}`);
  }
  const s = sekmeler(d);
  if (s.length) console.log(`sekmeler: ${s.map((n, i) => `${i}@${n.mx},${n.my}`).join('  ')}`);
}

// ─────────────────────────────────────────────────────────── CLI

function argCoz(argv) {
  const sec = { diller: ['tr', 'en'], kuru: false, zorla: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--diller') sec.diller = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--ekranlar') sec.ekranlar = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--kuru') sec.kuru = true;
    else if (a === '--zorla') sec.zorla = true;
    else if (a === '--ayrintili') AYRINTILI = true;
    else if (a === '--desen') sec.desen = argv[++i];
    else if (a === '--veri') sec.veri = argv[++i];
    else if (a === '--cikti') sec.cikti = argv[++i];
    else if (a === '--deneme') sec.deneme = Number(argv[++i]);
    else if (a === '--demoyok') sec.demoYok = true;
    else if (a === '--icerikyok') sec.icerikYok = true;
  }
  return sec;
}

const komut = process.argv[2] || 'cek';
const sec = argCoz(process.argv.slice(3));

try {
  if (komut === 'cek') await cek(sec);
  else if (komut === 'probe') await probe(sec);
  else if (komut === 'giris') { await oturumHazirla({}); }
  else if (komut === 'dil') { await dilSec(sec.diller[0]); }
  else { console.log('komutlar: cek | probe | giris | dil'); process.exit(1); }
} catch (e) {
  hata(e.message);
  if (AYRINTILI) console.error(e);
  process.exit(1);
}

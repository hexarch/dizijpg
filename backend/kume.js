// dizi.jpg — küme girişi (yapilacaklar2 D1): 16 çekirdekli makinede tek Node
// süreci yerine N işçi.
//
// MİMARİ:
//   · BİRİNCİL (bu dosya): HTTP DİNLEMEZ, veritabanına DOKUNMAZ. Üç işi var:
//     fork + gözetim (ölen işçiyi yeniden doğurma, hızlı-ölüm freni), işçiler
//     arası mesaj santrali (yayın/RPC/telemetri — sözleşme kume_ipc.js
//     başında) ve SIGTERM'i işçilere iletip hepsinin zarif kapanmasını
//     beklemek.
//   · İŞÇİLER: server.js'in kendisi. `cluster.fork` bu dosyayı yeniden
//     çalıştırır; işçi dalı tek satırda server.js'i yükler. app.listen(PORT)
//     cluster tarafından paylaşılır (SCHED_RR: bağlantılar sırayla dağıtılır).
//   · ARAMA SAHİPLİĞİ: SDP/ICE sinyalleşmesi BİLEREK bellekte (arama.js
//     "İÇERİK KAYDI YOK" mutlak kuralı — diske/PG'ye taşımak o mimari kararı
//     bozar). Round-robin bunu KIRACAĞI için tüm /arama/* trafiği sıra-1
//     işçisinde toplanır: diğer işçiler istekleri 127.0.0.1'deki iç porta
//     vekiller (ayrıntı server.js "ARAMA SAHİPLİĞİ" bloğunda).
//
// KAÇIŞ YOLLARI:
//   · NODE_ISCI=0 → forksuz, server.js doğrudan bu süreçte (bugünkü davranış).
//   · `node server.js` de aynen çalışmaya devam eder (testler bunu yapıyor).
//
// Ortam değişkenleri: NODE_ISCI (işçi sayısı, varsayılan min(4, çekirdek)),
// PG_HAVUZ_MAX (işçi başına havuz tavanı — kume_yardimci.havuzMax kırpar),
// ARAMA_IC_PORT (arama sahibinin iç portu, varsayılan PORT+1).

import cluster from 'node:cluster';
import os from 'node:os';
import { yaz as logYaz, olumcul as logOlumcul } from './gunluk.js';
import {
  isciSayisi, havuzMax, frenMs, HIZLI_OLUM_MS,
} from './kume_yardimci.js';

const CEKIRDEK = os.cpus().length;
const ISCI_ADET = isciSayisi(process.env, CEKIRDEK);

if (!cluster.isPrimary || ISCI_ADET === 0) {
  // İşçi dalı (ya da NODE_ISCI=0 kaçış yolu): sunucunun kendisi.
  await import('./server.js');
} else {
  birincil();
}

function birincil() {
  // -------------------------------------------------------------------------
  // Birincil süreç durumu — TAMAMI bellek içi ve birincile özel.
  // -------------------------------------------------------------------------
  let kapaniyor = false;

  // Hız limiti sayaçları (kume_ipc.sayacArtir): server.js'teki hizLimiti ile
  // AYNI pencere kuralı — anahtar başına saatlik pencere, taşınca süresi
  // dolanlar süpürülür.
  const sayaclar = new Map(); // anahtar -> {sayi, sifirlama}
  function sayacArtir(anahtar) {
    const simdi = Date.now();
    let kayit = sayaclar.get(anahtar);
    if (!kayit || simdi > kayit.sifirlama) {
      kayit = { sayi: 0, sifirlama: simdi + 3600_000 };
      sayaclar.set(anahtar, kayit);
    }
    kayit.sayi += 1;
    if (sayaclar.size > 20000) {
      for (const [k, v] of sayaclar) if (simdi > v.sifirlama) sayaclar.delete(k);
    }
    return kayit.sayi;
  }

  // Birleşik istek telemetrisi — server.js'teki ISTEK yapısının aynısı,
  // aynı tavanlarla (halka 400, dakika penceresi 120 dk).
  const ISTEK_SINIR = 400;
  const ISTEK = { son: [], toplam: 0, ulke: new Map(), dakika: new Map() };
  function istekIsle(kayit) {
    if (!kayit || typeof kayit !== 'object') return;
    const dk = Math.floor((Number(kayit.ts) || Date.now()) / 60000);
    ISTEK.toplam += 1;
    ISTEK.dakika.set(dk, (ISTEK.dakika.get(dk) || 0) + 1);
    for (const k of ISTEK.dakika.keys()) if (k < dk - 120) ISTEK.dakika.delete(k);
    if (kayit.ulke) ISTEK.ulke.set(kayit.ulke, (ISTEK.ulke.get(kayit.ulke) || 0) + 1);
    ISTEK.son.unshift(kayit);
    if (ISTEK.son.length > ISTEK_SINIR) ISTEK.son.length = ISTEK_SINIR;
  }

  // CSP İHLAL ÖZETİ — KÜME GENELİ (19 Ağu 2026).
  //
  // NEDEN BURAYA TAŞINDI: sayaç işçilerin BELLEĞİNDEYDİ ve her işçinin ayrı
  // kopyası vardı. `/admin/csp` isteği hangi işçiye düşerse onun rakamını
  // veriyordu — ölçüldü: aynı uç peş peşe 2, 3, 8, 1 döndü. Oysa o ucun tek
  // işi "toplam 0 mı?" sorusuna cevap vermek ve o cevaba bakıp CSP'yi ZORUNLU
  // moda almak. Dörtte bir görüşe bakıp "0" demek, enforce'a geçip özelliği
  // kırmanın en kolay yoluydu.
  //
  // TAVAN İŞÇİDEKİYLE AYNI (CSP_SINIR 200): birleşik harita da sınırsız
  // büyümemeli, bozuk/saldırgan bir istemci onu şişirebilir.
  const CSP_SINIR = 200;
  const CSP = { ozet: new Map(), toplam: 0, tasan: 0 };
  function cspIsle(k) {
    if (!k || typeof k !== 'object') return;
    const anahtar = String(k.anahtar || '').slice(0, 200);
    if (!anahtar) return;
    CSP.toplam += 1;
    const v = CSP.ozet.get(anahtar);
    if (v) { v.adet += 1; v.son = Date.now(); return; }
    if (CSP.ozet.size >= CSP_SINIR) { CSP.tasan += 1; return; }
    CSP.ozet.set(anahtar, {
      adet: 1, ilk: Date.now(), son: Date.now(),
      ornekYol: String(k.ornekYol || '').slice(0, 120),
    });
  }

  // -------------------------------------------------------------------------
  // Mesaj santrali
  // -------------------------------------------------------------------------
  function mesajIsle(gonderen, m) {
    if (!m || typeof m !== 'object') return; // cluster iç mesajları vb.
    if (m.k === 'yayin') {
      // Gönderen HARİÇ dağıt: o zaten yerel uygulamıştır (kume_ipc sözleşmesi).
      for (const id in cluster.workers) {
        const w = cluster.workers[id];
        if (!w || w === gonderen) continue;
        try { w.send({ k: 'yayin', konu: m.konu, veri: m.veri }); } catch { /* ölmekte olan işçi */ }
      }
    } else if (m.k === 'istek') {
      istekIsle(m.veri);
    } else if (m.k === 'csp') {
      cspIsle(m.veri);
    } else if (m.k === 'rpc') {
      let veri = null;
      if (m.ad === 'sayac' && m.veri && typeof m.veri.a === 'string') {
        veri = { sayi: sayacArtir(m.veri.a) };
      } else if (m.ad === 'csp_ozet') {
        veri = {
          toplam: CSP.toplam,
          tasan: CSP.tasan,
          ozet: [...CSP.ozet].map(([anahtar, v]) => ({ anahtar, ...v })),
        };
      } else if (m.ad === 'csp_sifirla') {
        CSP.ozet.clear(); CSP.toplam = 0; CSP.tasan = 0;
        veri = { durum: 'ok' };
      } else if (m.ad === 'istek_ozet') {
        veri = {
          toplam: ISTEK.toplam,
          ulke: [...ISTEK.ulke],
          dakika: [...ISTEK.dakika],
          son: ISTEK.son,
        };
      }
      try { gonderen.send({ k: 'rpc_cevap', id: m.id, veri }); } catch { /* işçi öldü */ }
    }
  }

  // -------------------------------------------------------------------------
  // Fork + gözetim
  // -------------------------------------------------------------------------
  // Sıra SLOT'a bağlıdır ve işçi ölünce AYNI sırayla yeniden doğar: sıra 1
  // arama sahibi + periyodik görevlerin (durumlariTara/tablolariBuda) tek
  // koşucusudur; sıranın kayması sahipliği kaybettirirdi.
  const slotFren = new Array(ISCI_ADET + 1).fill(0); // sıra -> art arda hızlı ölüm

  function dogur(sira) {
    const w = cluster.fork({
      ISCI_SIRA: String(sira),
      ISCI_SAYISI: String(ISCI_ADET),
    });
    w.isciSira = sira;
    w.dogum = Date.now();
    w.on('message', (m) => mesajIsle(w, m));
    logYaz({
      seviye: 'bilgi', olay: 'isci_dogdu', sira, pid: w.process.pid,
    });
  }

  cluster.on('exit', (w, cikisKodu, sinyal) => {
    const sira = w.isciSira || 0;
    const omurMs = Date.now() - (w.dogum || 0);
    logYaz({
      seviye: kapaniyor ? 'bilgi' : 'hata', olay: 'isci_oldu',
      sira, pid: w.process.pid, cikis: cikisKodu, sinyal: sinyal || null,
      omur_ms: omurMs, kapanma: kapaniyor,
    });
    if (kapaniyor) return; // zarif kapanışta yeniden doğurma YOK

    // Hızlı-ölüm freni: açılışta çöken kötü bir dağıtım fork fırtınası yapmasın.
    slotFren[sira] = omurMs < HIZLI_OLUM_MS ? slotFren[sira] + 1 : 0;
    const bekleme = frenMs(slotFren[sira]);
    if (bekleme > 0) {
      logYaz({
        seviye: 'hata', olay: 'isci_fren', sira,
        art_arda: slotFren[sira], bekleme_ms: bekleme,
      });
    }
    // unref YOK: tüm işçiler öldüyse bile birincil bu zamanlayıcı için
    // hayatta kalmalı — yoksa süreç çıkar ve Docker restart'a kalır.
    setTimeout(() => { if (!kapaniyor) dogur(sira); }, bekleme);
  });

  // -------------------------------------------------------------------------
  // Zarif kapanma: SIGTERM işçilere İLETİLİR, hepsi kapanınca çıkılır.
  // -------------------------------------------------------------------------
  // Docker stop → SIGTERM (PID 1 = bu süreç) → her işçi kendi kapan()'ını
  // koşar (uçuştaki istekleri bitirir, arama üstverisini yazar, havuzu
  // kapatır; server.js B2). Bütçe: işçi başına KAPANMA_AZAMI_MS (15 sn) +
  // buradaki 25 sn'lik üst sınır < stop_grace_period (30 sn) SIGKILL tavanı.
  const KUME_KAPANMA_AZAMI_MS = Number(process.env.KUME_KAPANMA_AZAMI_MS || 25_000);

  function kapat(sebep) {
    if (kapaniyor) return;
    kapaniyor = true;
    logYaz({ seviye: 'bilgi', olay: 'kume_kapaniyor', sebep, isci: ISCI_ADET });
    for (const id in cluster.workers) {
      try { cluster.workers[id]?.process.kill('SIGTERM'); } catch { /* zaten ölü */ }
    }
    const zorla = setTimeout(() => {
      logOlumcul({ olay: 'kume_kapanma_zaman_asimi', sebep, ms: KUME_KAPANMA_AZAMI_MS });
      for (const id in cluster.workers) {
        try { cluster.workers[id]?.process.kill('SIGKILL'); } catch { /* boş */ }
      }
      process.exit(1);
    }, KUME_KAPANMA_AZAMI_MS);
    zorla.unref?.();

    const kontrol = setInterval(() => {
      if (Object.keys(cluster.workers).length > 0) return;
      clearInterval(kontrol);
      clearTimeout(zorla);
      logOlumcul({ seviye: 'bilgi', olay: 'kume_kapandi', sebep });
      process.exit(0);
    }, 200);
  }

  process.on('SIGTERM', () => kapat('SIGTERM'));
  process.on('SIGINT', () => kapat('SIGINT'));

  // Birincilde beklenmedik hata: kayıt düş ve çık — Docker yeniden başlatır,
  // işçiler PID 1 ölünce konteynerle birlikte gider. (B1'deki işçi kalkanının
  // aksine burada zarif yol denenmez: santral güvenilmez hâldeyken işçileri
  // yönetmeye çalışmak asılı bir yarı-küme bırakabilir.)
  process.on('uncaughtException', (hata) => {
    logOlumcul({ olay: 'kume_istisna', hata });
    process.exit(1);
  });
  process.on('unhandledRejection', (sebep) => {
    logOlumcul({ olay: 'kume_reddetme', hata: sebep });
    process.exit(1);
  });

  logYaz({
    seviye: 'bilgi', olay: 'kume_basladi',
    isci: ISCI_ADET, cekirdek: CEKIRDEK,
    havuz_isci_basina: havuzMax(process.env, ISCI_ADET),
    havuz_toplam: havuzMax(process.env, ISCI_ADET) * ISCI_ADET,
  });
  for (let sira = 1; sira <= ISCI_ADET; sira++) dogur(sira);
}

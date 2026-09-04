// dizi.jpg — İZLEME ODASI VİDEO HAZIRLAMA: SAF karar ve argüman modülü.
//
// `video_kare.js` / `oda.js` / `disk.js` ile aynı disiplin: burada süreç
// açılmaz, dosya okunmaz, `pg` ve Express bilinmez. Her fonksiyon girdisini
// parametreden alır. Böylece `test/video_hazirla.test.js` tek bir ffmpeg
// çağırmadan tüm karar tablosunu sınayabilir.
//
// ===========================================================================
// NEDEN VAR — 4 Eyl 2026'da ölçülen sessiz hata
// ===========================================================================
// Oda videosu yüklemesi sihirli baytlara bakıyor: `ftyp` -> mp4,
// `1A 45 DF A3` -> webm. **Matroska (.mkv) ile WebM AYNI EBML imzasını
// taşır.** Sonuç: MKV sessizce kabul ediliyor ve diske `.webm` adıyla
// yazılıyordu. Ama film MKV'lerinin tipik içeriği H.264 + AC3'tür:
//   · tarayıcı: WebM kabında H.264 kabul etmez -> HİÇ açılmaz,
//   · Android: kabı okur, AC3'ü çözemez -> GÖRÜNTÜ VAR SES YOK.
// İndirilen filmlerin çoğu MKV olduğu için, "birlikte film izleyelim"
// senaryosunun EN OLASI dosyası sessizce bozuktu.
//
// ===========================================================================
// KARARI KAP ADI DEĞİL KODEK VERİR — ölçülmüş gerçek
// ===========================================================================
// `ffprobe` MKV ve WebM için AYNI `format_name` değerini döndürür:
// `matroska,webm` (4 Eyl 2026'da ffmpeg 8.x ile ölçüldü). Yani "bu dosya MKV
// mi WebM mi" sorusunun ffprobe'da cevabı YOKTUR ve olmasına da gerek yok:
// bir dosyanın oynayıp oynamayacağını KAP değil KODEK belirler. H.264+AC3
// taşıyan bir "webm" gerçekte MKV'dir; VP9+Opus taşıyan bir "mkv" gerçekte
// WebM'dir. Bu modül bu yüzden kap adını YOK SAYAR ve yalnız kodeklere bakar.
//
// ===========================================================================
// NEDEN H.265 YENİDEN KODLANMIYOR (bilinçli karar)
// ===========================================================================
// HEVC iOS'ta ve modern Android'de zaten oynar; YALNIZ tarayıcıda oynamaz.
// 2 saatlik bir filmi x264'e çevirmek 16 çekirdekte 20-40 dakika sürer —
// odanın 12 saatlik ömrünün önemli bir kısmı ve PAYLAŞIMLI makinenin (host
// Postgres, Postfix, başka projeler) CPU'su. Bedel kazanca değmiyor: dosya
// olduğu gibi bırakılır, telefonda sorunsuz oynar, tarayıcıda kullanıcıya
// AÇIK bir cümle gösterilir ve sahibi isterse çevrimi ELLE tetikler.

// ---------------------------------------------------------------------------
// KODEK SINIFLARI
// ---------------------------------------------------------------------------

/** MP4 kabında taşınabilen ve her yerde çözülen görüntü kodeki. */
export const MP4_GORUNTU = new Set(['h264']);

/**
 * MP4 kabında taşınır ama TARAYICIDA çözülmez. Telefonda (iOS + modern
 * Android) oynar; web için elle çevrim gerekir.
 */
export const MP4_GORUNTU_WEBSIZ = new Set(['hevc']);

/** WebM kabının kendi görüntü kodekleri. MP4'e KONMAZ. */
export const WEBM_GORUNTU = new Set(['vp8', 'vp9', 'av1']);

/** MP4 kabında sorunsuz çözülen ses. */
export const MP4_SES = new Set(['aac', 'mp3']);

/** WebM kabında sorunsuz çözülen ses. */
export const WEBM_SES = new Set(['opus', 'vorbis']);

/**
 * Ses hedef bit hızı ve kanal sayısı.
 *
 * STEREOYA İNDİRİLİR (`-ac 2`) — bilinçli. Telefon hoparlörü zaten stereo ve
 * 5.1 AAC bazı Android çözücülerinde sessiz kalıyor. 5.1'i korumak, kimsenin
 * duyamayacağı bir kanal düzeni için sessizlik riskine girmek olurdu.
 */
export const SES_BIT_HIZI = '192k';
export const SES_KANAL = 2;

/**
 * Elle çevrimde kullanılan iş parçacığı tavanı.
 *
 * Makine 16 çekirdekli ve PAYLAŞIMLI. Sınırsız bırakılırsa x264 hepsini alır
 * ve host Postgres/Postfix'in yanıt süresi bozulur — kullanıcı odayı izlerken
 * SİTENİN TAMAMI yavaşlar. Yarısı, çevrimi kabul edilebilir sürede bitirirken
 * makineye nefes bırakır.
 */
export const CEVRIM_THREAD = 8;

/** x264 ön ayarı ve kalitesi: hız/kalite dengesinde 1080p için makul orta. */
export const CEVRIM_PRESET = 'veryfast';
export const CEVRIM_CRF = '23';

// ---------------------------------------------------------------------------
// FFPROBE ÇIKTISINI OKUMA
// ---------------------------------------------------------------------------

/**
 * ffprobe JSON'undan ilk GERÇEK görüntü akışını seçer.
 *
 * `attached_pic` olan akış ATLANIR: MKV/MP3 dosyalarına gömülü kapak resmi de
 * `codec_type: video` görünür (genelde mjpeg/png). Onu görüntü sanmak, müzik
 * dosyasını "desteklenmeyen kodek" diye reddetmeye ya da kapak resmini
 * kopyalamaya çalışmaya yol açardı.
 */
export function goruntuAkisi(probe) {
  const akislar = Array.isArray(probe?.streams) ? probe.streams : [];
  return akislar.find((s) => s.codec_type === 'video'
    && !(s.disposition && s.disposition.attached_pic)) || null;
}

/** İlk ses akışı; yoksa null (sessiz video geçerlidir). */
export function sesAkisi(probe) {
  const akislar = Array.isArray(probe?.streams) ? probe.streams : [];
  return akislar.find((s) => s.codec_type === 'audio') || null;
}

/** Süre (ms). Bilinmiyorsa null — ilerleme yüzdesi o zaman hesaplanamaz. */
export function sureMs(probe) {
  const sn = Number.parseFloat(probe?.format?.duration);
  return Number.isFinite(sn) && sn > 0 ? Math.round(sn * 1000) : null;
}

// ---------------------------------------------------------------------------
// MP4 FASTSTART — saf atom yürüyüşü
// ---------------------------------------------------------------------------

/**
 * MP4'ün `moov` atomu `mdat`tan ÖNCE mi (faststart) — dosyanın BAŞINDAN
 * okunmuş bir tampondan karar verir.
 *
 * NEDEN ÖNEMLİ: `moov` sonda ise oynatıcı dosyanın TAMAMINI indirmeden
 * başlayamaz. 5 GB'lık bir odada bu "video hiç açılmıyor" demektir. ffmpeg
 * varsayılan olarak `moov`u SONA yazar (4 Eyl 2026'da ölçüldü:
 * `ftyp, free, mdat, moov`), `-movflags +faststart` ile başa alır
 * (`ftyp, moov, free, mdat`).
 *
 * NEDEN FFPROBE DEĞİL: ffprobe atom sırasını raporlamaz; öğrenmek için `-v
 * trace` çıktısını ayrıştırmak gerekirdi ki o sürüme göre değişen kırılgan bir
 * yüzeydir. Üst düzey atom başlıklarını yürümek 20 satır ve TAM.
 *
 * @param {Buffer|Uint8Array} bas dosyanın başından okunmuş tampon
 * @returns {boolean|null} true=faststart · false=moov sonda · null=kararsız
 *   (tampon yetmedi; çağıran güvenli tarafa düşüp yeniden paketlemeli)
 */
export function mp4FaststartVar(bas) {
  if (!bas || bas.length < 8) return null;
  let ofset = 0;
  // Üst düzey atomlar azdır (ftyp/free/wide/moov/mdat); 32 adım fazlasıyla yeter
  // ve bozuk bir dosyada sonsuz döngüyü imkânsız kılar.
  for (let adim = 0; adim < 32; adim++) {
    if (ofset + 8 > bas.length) return null;
    let boy = (bas[ofset] << 24 >>> 0) + (bas[ofset + 1] << 16)
      + (bas[ofset + 2] << 8) + bas[ofset + 3];
    const ad = String.fromCharCode(
      bas[ofset + 4], bas[ofset + 5], bas[ofset + 6], bas[ofset + 7]);
    if (ad === 'moov') return true;
    if (ad === 'mdat') return false;
    let baslik = 8;
    if (boy === 1) {
      // 64-bit boyut: 8 baytlık genişletilmiş alan başlığın hemen ardında.
      if (ofset + 16 > bas.length) return null;
      // Üst 32 bit pratikte 0; yalnız alt 32 biti okumak 4 GB'ı aşan TEK bir
      // üst düzey atomda yanılır — o durumda zaten `mdat`tayızdır ve yukarıda
      // dönmüşüzdür.
      boy = (bas[ofset + 12] << 24 >>> 0) + (bas[ofset + 13] << 16)
        + (bas[ofset + 14] << 8) + bas[ofset + 15];
      baslik = 16;
    }
    // `boy === 0` = "dosyanın sonuna kadar" (yalnız son atomda olur).
    if (boy === 0) return null;
    if (boy < baslik) return null; // bozuk
    ofset += boy;
  }
  return null;
}

// ---------------------------------------------------------------------------
// KARAR
// ---------------------------------------------------------------------------

/**
 * Hazırlık kararı.
 *
 * @param {object} probe ffprobe `-show_format -show_streams` JSON çıktısı
 * @param {boolean|null} faststart [mp4FaststartVar] sonucu (MP4 değilse yok sayılır)
 * @returns {{
 *   eylem: 'yok'|'remux'|'ses'|'elle'|'red',
 *   hedefUzanti: 'mp4'|'webm'|null,
 *   videoKodek: string|null, sesKodek: string|null,
 *   uyumsuz: string[], sebep: string|null, sureMs: number|null,
 * }}
 *
 * `eylem` YALNIZ OTOMATİK İŞİ anlatır; `uyumsuz` platform sınırını ayrı
 * taşır. İkisi bağımsız eksendir: HEVC bir MKV'de hem `remux` gerektirir hem
 * de web'de oynamaz. Tek alana sıkıştırılsaydı biri ötekini gizlerdi.
 * `'elle'` = otomatik yapılacak iş YOK ama dosya her yerde oynamıyor; sahibi
 * dilerse çevrimi kendisi tetikler.
 */
export function hazirlikKarari(probe, faststart = null) {
  const v = goruntuAkisi(probe);
  const a = sesAkisi(probe);
  const vk = v?.codec_name || null;
  const sk = a?.codec_name || null;
  const sure = sureMs(probe);
  const temel = { videoKodek: vk, sesKodek: sk, sureMs: sure, uyumsuz: [], sebep: null };

  if (!v) {
    return { ...temel, eylem: 'red', hedefUzanti: null, sebep: 'goruntu_yok' };
  }

  const mp4Hedef = MP4_GORUNTU.has(vk) || MP4_GORUNTU_WEBSIZ.has(vk);
  const webmHedef = WEBM_GORUNTU.has(vk);
  if (!mp4Hedef && !webmHedef) {
    // MPEG-4 Part 2 (DivX/Xvid), Theora, WMV3, MPEG-2, VC-1 ... Bunlar MP4'e
    // yeniden paketlenebilse bile hiçbir hedef platformda çözülmez; yeniden
    // KODLAMAK ise H.265 için reddettiğimiz maliyetin aynısı.
    return { ...temel, eylem: 'red', hedefUzanti: null, sebep: 'goruntu_kodek' };
  }

  const hedefUzanti = mp4Hedef ? 'mp4' : 'webm';
  const sesUygun = sk == null
    || (mp4Hedef ? MP4_SES.has(sk) : WEBM_SES.has(sk));

  // Platform sınırları — otomatik işten BAĞIMSIZ.
  const uyumsuz = [];
  if (MP4_GORUNTU_WEBSIZ.has(vk)) uyumsuz.push('web');
  // VP8/VP9/AV1 iOS'ta AVFoundation tarafından çözülmez (`video_player` orada
  // AVFoundation kullanır). Android ve tarayıcı oynar.
  if (webmHedef) uyumsuz.push('ios');

  // Kap uygun mu? ffprobe MKV ile WebM'i ayırt EDEMEDİĞİ için kap adına
  // güvenilmez; hedef MP4 ise dosyanın gerçekten MP4 olup olmadığını
  // `format_name` üzerinden anlarız (mov/mp4 ailesi ayrı bir addır).
  const kapAdi = String(probe?.format?.format_name || '');
  const mp4Kabi = kapAdi.includes('mp4') || kapAdi.includes('mov');
  const matroskaKabi = kapAdi.includes('matroska') || kapAdi.includes('webm');

  if (hedefUzanti === 'webm') {
    // VP8/VP9/AV1 zaten Matroska/WebM ailesinde; kap değişimine gerek yok.
    if (!sesUygun) {
      return { ...temel, uyumsuz, eylem: 'ses', hedefUzanti, sebep: 'ses_kodek' };
    }
    return { ...temel, uyumsuz, eylem: 'yok', hedefUzanti };
  }

  // hedefUzanti === 'mp4'
  if (!sesUygun) {
    return { ...temel, uyumsuz, eylem: 'ses', hedefUzanti, sebep: 'ses_kodek' };
  }
  if (matroskaKabi && !mp4Kabi) {
    // Gerçek MKV: H.264/HEVC taşıyor, MP4'e yeniden paketlenmeli.
    return { ...temel, uyumsuz, eylem: 'remux', hedefUzanti, sebep: 'kap' };
  }
  if (mp4Kabi && faststart === false) {
    return { ...temel, uyumsuz, eylem: 'remux', hedefUzanti, sebep: 'faststart' };
  }
  if (mp4Kabi && faststart == null) {
    // Kararsız: güvenli taraf yeniden paketlemek. `moov` sondaysa dosya hiç
    // açılmaz; gereksiz bir remux ise yalnız bir kopyalama maliyetidir.
    return { ...temel, uyumsuz, eylem: 'remux', hedefUzanti, sebep: 'faststart_bilinmiyor' };
  }
  // Otomatik iş yok. Web'de oynamıyorsa sahibe elle çevrim yolu açık.
  return {
    ...temel,
    uyumsuz,
    eylem: uyumsuz.includes('web') ? 'elle' : 'yok',
    hedefUzanti,
  };
}

/** Kararın kullanıcıya gösterilecek ÇEVİRİ ANAHTARI (sunucu cümle kurmaz). */
export function redSebebi(karar) {
  if (karar?.sebep === 'goruntu_yok') return 'VIDEO_GORUNTU_YOK';
  if (karar?.sebep === 'goruntu_kodek') return 'VIDEO_KODEK_DESTEKSIZ';
  return 'VIDEO_HAZIRLIK_HATA';
}

// ---------------------------------------------------------------------------
// FFMPEG ARGÜMANLARI
// ---------------------------------------------------------------------------

/**
 * Çıktı kabını AÇIKÇA söyler (`-f mp4` / `-f webm`).
 *
 * ***4 Eyl 2026, CANLIDA YAŞANDI.*** ffmpeg hangi kapla yazacağını çıktı
 * dosyasının UZANTISINDAN çıkarır. Hazırlık geçici dosyası `15.hazirlik`
 * adıyla, yani UZANTISIZ açılıyordu ve ffmpeg her seferinde şu hatayla
 * düşüyordu:
 *   "Unable to choose an output format for '…/15.hazirlik'; use a standard
 *    extension for the filename or specify the format manually."
 * Kullanıcı yalnız "Video hazırlanamadı" görüyordu.
 *
 * İki katman birden uygulandı: geçici dosya artık hedef uzantıyı taşıyor VE
 * kap burada açıkça veriliyor. Uzantı ileride yine değişse muxer sabit kalır —
 * bu hatanın ikinci kez çıkmasının yolu kapalı.
 *
 * `-f` ÇIKTI DOSYASINDAN HEMEN ÖNCE gelmeli: ffmpeg'te çıktı seçenekleri
 * kendisinden sonra gelen dosyaya uygulanır.
 */
function kapArgumani(kap) {
  return ['-f', kap === 'webm' ? 'webm' : 'mp4'];
}

/**
 * Ortak argüman gövdesi.
 *
 * `-map 0:v:0` + `-map 0:a:0?` — TEK görüntü ve TEK ses akışı. Film MKV'leri
 * çoğu zaman 5-8 ses (diller) ve 10+ altyazı akışı taşır: hepsini kopyalamak
 * dosyayı şişirir, MP4'e sığmayan altyazı biçimleri (ASS/PGS) yüzünden ffmpeg
 * HATA verir ve `video_player` zaten tek akış oynatır. `?` işareti sessiz
 * videoda ses akışı yokken ffmpeg'in patlamasını önler.
 *
 * `-sn -dn` altyazı ve veri akışlarını AÇIKÇA atar — `-map` seçimi zaten
 * onları dışarıda bırakır ama niyet kodda görünür olsun.
 */
function ortakArgumanlar(giris) {
  return [
    '-nostdin', '-v', 'error', '-y',
    '-i', giris,
    '-map', '0:v:0', '-map', '0:a:0?',
    '-sn', '-dn',
    '-progress', 'pipe:1',
  ];
}

/**
 * KAP DÜZELTME: yeniden kodlama YOK, yalnız MP4'e paketle.
 * 5 GB'lık bir dosyada bile disk hızıyla sınırlıdır (dakikalar değil saniyeler).
 */
export function remuxArgumanlari(giris, cikis, kap = 'mp4') {
  return [
    ...ortakArgumanlar(giris),
    '-c', 'copy',
    '-movflags', '+faststart',
    ...kapArgumani(kap),
    cikis,
  ];
}

/**
 * SES ÇEVİRME: görüntü kopyalanır, ses AAC'ye iner.
 * Film MKV'lerinin klasik "görüntü var ses yok" derdinin çözümü budur.
 */
export function sesCevirmeArgumanlari(giris, cikis, kap = 'mp4') {
  // WebM hedefinde ses AAC OLAMAZ (kap kabul etmez): Opus'a inilir.
  const sesKodek = kap === 'webm' ? ['libopus'] : ['aac'];
  return [
    ...ortakArgumanlar(giris),
    '-c:v', 'copy',
    '-c:a', ...sesKodek, '-b:a', SES_BIT_HIZI, '-ac', String(SES_KANAL),
    ...(kap === 'webm' ? [] : ['-movflags', '+faststart']),
    ...kapArgumani(kap),
    cikis,
  ];
}

/**
 * ELLE TAM ÇEVRİM (yalnız sahip tetikler): görüntü x264'e iner.
 * PAHALIDIR — `CEVRIM_THREAD` tavanının gerekçesi sabitin başında.
 */
export function tamCevrimArgumanlari(giris, cikis) {
  return [
    ...ortakArgumanlar(giris),
    '-threads', String(CEVRIM_THREAD),
    '-c:v', 'libx264', '-preset', CEVRIM_PRESET, '-crf', CEVRIM_CRF,
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', SES_BIT_HIZI, '-ac', String(SES_KANAL),
    '-movflags', '+faststart',
    ...kapArgumani('mp4'),
    cikis,
  ];
}

/** Karara göre argüman üretici; otomatik iş yoksa null. */
export function argumanlar(karar, giris, cikis) {
  const kap = karar?.hedefUzanti === 'webm' ? 'webm' : 'mp4';
  if (karar?.eylem === 'remux') return remuxArgumanlari(giris, cikis, kap);
  if (karar?.eylem === 'ses') return sesCevirmeArgumanlari(giris, cikis, kap);
  return null;
}

// ---------------------------------------------------------------------------
// İLERLEME
// ---------------------------------------------------------------------------

/**
 * `-progress pipe:1` çıktısından yüzde.
 *
 * ffmpeg `anahtar=deger` satırları basar; bizi ilgilendiren `out_time_us`
 * (işlenen süre, mikrosaniye) ve `progress=end`. Bir okuma parçası birden çok
 * satır ya da yarım satır içerebilir; SON tam `out_time_us` alınır.
 *
 * @returns {{yuzde:number|null, bitti:boolean}}
 */
export function ilerlemeAyristir(parca, toplamMs) {
  const metin = String(parca || '');
  const bitti = /(^|\n)progress=end\s*(\n|$)/.test(metin);
  let sonUs = null;
  const re = /(?:^|\n)out_time_us=(\d+)/g;
  let m;
  while ((m = re.exec(metin)) !== null) sonUs = Number(m[1]);
  if (sonUs == null || !(toplamMs > 0)) return { yuzde: null, bitti };
  const yuzde = Math.round((sonUs / 1000 / toplamMs) * 100);
  // 100'ü ancak `progress=end` ile veririz: kullanıcı %100 görüp dosyanın
  // hazır olmadığı bir aralıkta beklememeli.
  return { yuzde: Math.max(0, Math.min(bitti ? 100 : 99, yuzde)), bitti };
}

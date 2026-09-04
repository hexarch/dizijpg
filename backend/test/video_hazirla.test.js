// İzleme odası video hazırlama — SAF karar/argüman testleri + BAĞLANTI testleri.
//
// FİKSTÜRLER GERÇEK: aşağıdaki ffprobe gövdeleri 4 Eyl 2026'da ffmpeg 8.x ile
// ÜRETİLMİŞ dosyalardan alındı (`ffprobe -print_format json -show_format
// -show_streams`), yalnız testin kullanmadığı alanlar kırpıldı. Uydurulmuş
// değiller — özellikle `format_name` alanı kritik: MKV ile WebM'in AYNI adı
// (`matroska,webm`) döndürdüğü buradan görülüyor ve modülün kap adına
// güvenmemesinin sebebi bu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  MP4_GORUNTU, MP4_GORUNTU_WEBSIZ, WEBM_GORUNTU, MP4_SES, WEBM_SES,
  SES_BIT_HIZI, SES_KANAL, CEVRIM_THREAD,
  goruntuAkisi, sesAkisi, sureMs, mp4FaststartVar, hazirlikKarari, redSebebi,
  remuxArgumanlari, sesCevirmeArgumanlari, tamCevrimArgumanlari, argumanlar,
  ilerlemeAyristir,
} from '../video_hazirla.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (p) => fs.readFileSync(path.join(KOK, p), 'utf8');

// ---------------------------------------------------------------------------
// GERÇEK ffprobe fikstürleri (kırpılmış)
// ---------------------------------------------------------------------------
const probe = (formatName, streams, duration = '3.000000') => ({
  streams,
  format: { format_name: formatName, duration },
});
const vid = (codec, ek = {}) => ({ codec_type: 'video', codec_name: codec, ...ek });
const ses = (codec, ch = 2) => ({ codec_type: 'audio', codec_name: codec, channels: ch });

const MP4 = 'mov,mp4,m4a,3gp,3g2,mj2';
const MKV = 'matroska,webm';

// ===========================================================================
// 1. AKIŞ SEÇİMİ
// ===========================================================================

test('goruntuAkisi: ilk görüntü akışını seçer', () => {
  const p = probe(MP4, [ses('aac'), vid('h264')]);
  assert.equal(goruntuAkisi(p).codec_name, 'h264');
});

test('goruntuAkisi: GÖMÜLÜ KAPAK RESMİ görüntü sayılmaz', () => {
  // MKV/MP3 kapak resmi de `codec_type: video` görünür. Onu görüntü sanmak
  // dosyayı "desteklenmeyen kodek" diye reddettirirdi.
  const p = probe(MKV, [
    vid('mjpeg', { disposition: { attached_pic: 1 } }),
    vid('h264'),
    ses('aac'),
  ]);
  assert.equal(goruntuAkisi(p).codec_name, 'h264');
});

test('sesAkisi: yoksa null (sessiz video geçerli)', () => {
  assert.equal(sesAkisi(probe(MKV, [vid('h264')])), null);
});

test('sureMs: saniyeden ms, bozuksa null', () => {
  assert.equal(sureMs(probe(MP4, [vid('h264')], '3.023000')), 3023);
  assert.equal(sureMs(probe(MP4, [vid('h264')], 'N/A')), null);
  assert.equal(sureMs({ format: {} }), null);
});

// ===========================================================================
// 2. MP4 FASTSTART — atom yürüyüşü
// ===========================================================================

/** Üst düzey MP4 atom zinciri üretir: [['ftyp',24],['mdat',1000],...] */
function atomTampon(liste) {
  const parcalar = liste.map(([ad, boy]) => {
    const b = Buffer.alloc(Math.max(boy, 8));
    b.writeUInt32BE(boy, 0);
    b.write(ad, 4, 4, 'latin1');
    return b;
  });
  return Buffer.concat(parcalar);
}

test('mp4FaststartVar: moov ÖNCE ise true', () => {
  // ffmpeg `-movflags +faststart` çıktısının gerçek sırası (4 Eyl ölçümü):
  assert.equal(mp4FaststartVar(atomTampon([
    ['ftyp', 32], ['moov', 200], ['free', 8], ['mdat', 4096],
  ])), true);
});

test('mp4FaststartVar: mdat ÖNCE ise false', () => {
  // ffmpeg VARSAYILAN çıktısının gerçek sırası — bu dosya 5 GB olsaydı
  // oynatıcı tamamını indirmeden açamazdı.
  assert.equal(mp4FaststartVar(atomTampon([
    ['ftyp', 32], ['free', 8], ['mdat', 4096], ['moov', 200],
  ])), false);
});

test('mp4FaststartVar: tampon yetmezse null (kararsız)', () => {
  // İlk atom tamponu aşıyor: hangisinin önce geldiği BİLİNMİYOR.
  const b = atomTampon([['ftyp', 32], ['skip', 100000]]).subarray(0, 64);
  assert.equal(mp4FaststartVar(b), null);
});

test('mp4FaststartVar: bozuk/kısa girdi null, sonsuz döngü yok', () => {
  assert.equal(mp4FaststartVar(Buffer.alloc(4)), null);
  assert.equal(mp4FaststartVar(null), null);
  // boy=0 ("dosya sonuna kadar") ilerlemeyi durdurur
  assert.equal(mp4FaststartVar(atomTampon([['ftyp', 32]]).subarray(0, 8)
    .fill(0, 0, 4)), null);
});

test('mp4FaststartVar: 64-bit boyutlu atomu atlayabiliyor', () => {
  const b = Buffer.concat([
    (() => { const x = Buffer.alloc(16); x.writeUInt32BE(1, 0); x.write('mdat', 4); x.writeUInt32BE(0, 8); x.writeUInt32BE(64, 12); return x; })(),
  ]);
  // İlk atom zaten mdat: faststart YOK.
  assert.equal(mp4FaststartVar(b), false);
});

// ===========================================================================
// 3. KARAR TABLOSU — bu dosyanın kalbi
// ===========================================================================

test('KARAR: H.264+AAC / MKV -> REMUX (kap düzeltme, yeniden kodlama yok)', () => {
  const k = hazirlikKarari(probe(MKV, [vid('h264'), ses('aac')]), null);
  assert.equal(k.eylem, 'remux');
  assert.equal(k.hedefUzanti, 'mp4');
  assert.equal(k.sebep, 'kap');
  assert.deepEqual(k.uyumsuz, []);
});

test('KARAR: H.264+AC3 / MKV -> SES (film MKVlerinin klasik derdi)', () => {
  // "Görüntü var ses yok" tam olarak buradan çıkıyor: AC3 hiçbir telefonda
  // çözülmez.
  const k = hazirlikKarari(probe(MKV, [vid('h264'), ses('ac3', 6)]), null);
  assert.equal(k.eylem, 'ses');
  assert.equal(k.hedefUzanti, 'mp4');
  assert.equal(k.sesKodek, 'ac3');
});

test('KARAR: DTS / TrueHD / FLAC / PCM de SES çevirmeye gider', () => {
  for (const s of ['dts', 'truehd', 'flac', 'pcm_s16le', 'eac3', 'mlp']) {
    const k = hazirlikKarari(probe(MKV, [vid('h264'), ses(s)]), null);
    assert.equal(k.eylem, 'ses', `${s} çevrilmeli`);
  }
});

test('KARAR: H.264+AAC / faststartlı MP4 -> İŞ YOK', () => {
  const k = hazirlikKarari(probe(MP4, [vid('h264'), ses('aac')]), true);
  assert.equal(k.eylem, 'yok');
  assert.equal(k.sebep, null);
});

test('KARAR: MP4 ama moov SONDA -> REMUX', () => {
  const k = hazirlikKarari(probe(MP4, [vid('h264'), ses('aac')]), false);
  assert.equal(k.eylem, 'remux');
  assert.equal(k.sebep, 'faststart');
});

test('KARAR: faststart BİLİNMİYORSA güvenli tarafa düşülür (remux)', () => {
  // Yanlış "gerek yok" kararı videoyu hiç açtırmaz; yanlış "remux" kararı
  // yalnız bir kopyalama maliyetidir. Asimetri remux lehine.
  const k = hazirlikKarari(probe(MP4, [vid('h264'), ses('aac')]), null);
  assert.equal(k.eylem, 'remux');
  assert.equal(k.sebep, 'faststart_bilinmiyor');
});

test('KARAR: H.265 dokunulmaz ama WEB uyumsuzluğu bildirilir', () => {
  const k = hazirlikKarari(probe(MP4, [vid('hevc'), ses('aac')]), true);
  assert.equal(k.eylem, 'elle', 'otomatik iş yok, sahibi elle çevirebilir');
  assert.ok(k.uyumsuz.includes('web'));
});

test('KARAR: H.265 MKV içindeyse HEM remux HEM web uyarısı', () => {
  // İki eksen BAĞIMSIZ: kap düzeltilmeli (telefonda oynasın diye) ama
  // tarayıcı yine oynatamayacak. Tek alana sıkıştırılsaydı biri gizlenirdi.
  const k = hazirlikKarari(probe(MKV, [vid('hevc'), ses('aac')]), null);
  assert.equal(k.eylem, 'remux');
  assert.ok(k.uyumsuz.includes('web'));
});

test('KARAR: VP9+Opus / WebM -> iş yok, ama iOS uyumsuz', () => {
  // `video_player` iOSta AVFoundation kullanır; VP8/VP9 çözülmez.
  const k = hazirlikKarari(probe(MKV, [vid('vp9'), ses('opus')]), null);
  assert.equal(k.eylem, 'yok');
  assert.equal(k.hedefUzanti, 'webm');
  assert.deepEqual(k.uyumsuz, ['ios']);
});

test('KARAR: VP9 + AAC -> sesi Opusa çevir, WebM kalır', () => {
  const k = hazirlikKarari(probe(MKV, [vid('vp9'), ses('aac')]), null);
  assert.equal(k.eylem, 'ses');
  assert.equal(k.hedefUzanti, 'webm');
});

test('KARAR: DivX/MPEG-4 Part 2 REDDEDİLİR, sebebi söylenir', () => {
  const k = hazirlikKarari(probe(MKV, [vid('mpeg4')]), null);
  assert.equal(k.eylem, 'red');
  assert.equal(k.sebep, 'goruntu_kodek');
  assert.equal(redSebebi(k), 'VIDEO_KODEK_DESTEKSIZ');
});

test('KARAR: Theora/WMV3/MPEG-2/VC-1 de reddedilir', () => {
  for (const v of ['theora', 'wmv3', 'mpeg2video', 'vc1', 'msmpeg4v3']) {
    assert.equal(hazirlikKarari(probe(MKV, [vid(v)]), null).eylem, 'red', v);
  }
});

test('KARAR: görüntü akışı olmayan dosya reddedilir', () => {
  const k = hazirlikKarari(probe(MKV, [ses('aac')]), null);
  assert.equal(k.eylem, 'red');
  assert.equal(redSebebi(k), 'VIDEO_GORUNTU_YOK');
});

test('KARAR: SESSİZ video geçerlidir (ses akışı yokluğu hata değil)', () => {
  const k = hazirlikKarari(probe(MKV, [vid('h264')]), null);
  assert.equal(k.eylem, 'remux');
  assert.equal(k.sesKodek, null);
});

test('KARAR: kodek kümeleri birbirini kesmiyor', () => {
  for (const v of MP4_GORUNTU) assert.ok(!MP4_GORUNTU_WEBSIZ.has(v));
  for (const v of WEBM_GORUNTU) assert.ok(!MP4_GORUNTU.has(v) && !MP4_GORUNTU_WEBSIZ.has(v));
  for (const s of MP4_SES) assert.ok(!WEBM_SES.has(s));
});

// ===========================================================================
// 4. FFMPEG ARGÜMANLARI
// ===========================================================================

test('remux: yeniden kodlama YOK ve +faststart VAR', () => {
  const a = remuxArgumanlari('/g.mkv', '/c.mp4');
  assert.ok(a.includes('-c') && a[a.indexOf('-c') + 1] === 'copy');
  // +faststart ŞART: yoksa moov sonda kalır ve 5 GBlık dosya hiç açılmaz.
  assert.equal(a[a.indexOf('-movflags') + 1], '+faststart');
  assert.equal(a[a.length - 1], '/c.mp4');
});

test('ses çevirme: görüntü KOPYALANIR, ses AACe iner, stereoya düşer', () => {
  const a = sesCevirmeArgumanlari('/g.mkv', '/c.mp4');
  assert.equal(a[a.indexOf('-c:v') + 1], 'copy', 'görüntü yeniden kodlanmamalı');
  assert.equal(a[a.indexOf('-c:a') + 1], 'aac');
  assert.equal(a[a.indexOf('-b:a') + 1], SES_BIT_HIZI);
  assert.equal(a[a.indexOf('-ac') + 1], String(SES_KANAL));
  assert.equal(a[a.indexOf('-movflags') + 1], '+faststart');
});

test('TEK görüntü + TEK ses akışı seçiliyor, altyazı atılıyor', () => {
  // Film MKVleri 5-8 ses ve 10+ altyazı taşır: hepsini kopyalamak dosyayı
  // şişirir ve MP4e sığmayan altyazı biçimleri (ASS/PGS) ffmpegi PATLATIR.
  for (const a of [remuxArgumanlari('/g', '/c'), sesCevirmeArgumanlari('/g', '/c')]) {
    assert.ok(a.includes('0:v:0'));
    assert.ok(a.includes('0:a:0?'), 'ses akışı SEÇMELİ ama sessiz videoda ? ile isteğe bağlı');
    assert.ok(a.includes('-sn') && a.includes('-dn'));
  }
});

test('ilerleme borusu her argüman kümesinde açık', () => {
  for (const a of [remuxArgumanlari('/g', '/c'), sesCevirmeArgumanlari('/g', '/c'),
    tamCevrimArgumanlari('/g', '/c')]) {
    assert.equal(a[a.indexOf('-progress') + 1], 'pipe:1');
    assert.ok(a.includes('-nostdin'), 'ffmpeg stdinden okumaya kalkmasın');
    assert.ok(a.includes('-y'));
  }
});

test('tam çevrim: x264 + İŞ PARÇACIĞI TAVANI (paylaşımlı makine)', () => {
  const a = tamCevrimArgumanlari('/g.mp4', '/c.mp4');
  assert.equal(a[a.indexOf('-c:v') + 1], 'libx264');
  // Tavan olmasa x264 16 çekirdeği alır ve host Postgres/Postfix yavaşlar.
  assert.equal(a[a.indexOf('-threads') + 1], String(CEVRIM_THREAD));
  assert.ok(CEVRIM_THREAD < 16);
  assert.equal(a[a.indexOf('-pix_fmt') + 1], 'yuv420p');
});

test('argumanlar(): yalnız otomatik iş için argüman üretir', () => {
  const g = '/g', c = '/c';
  assert.ok(argumanlar({ eylem: 'remux' }, g, c));
  assert.ok(argumanlar({ eylem: 'ses' }, g, c));
  for (const e of ['yok', 'elle', 'red']) {
    assert.equal(argumanlar({ eylem: e }, g, c), null, e);
  }
});

test('çıktı yolu UZANTILI ve kap AÇIKÇA veriliyor (-f)', () => {
  // 4 Eyl 2026, CANLIDA: geçici dosya `15.hazirlik` adıyla UZANTISIZ açılıyordu
  // ve ffmpeg her işte "Unable to choose an output format" ile düşüyordu.
  // Argüman testleri bunu yakalayamamıştı çünkü argümanlar DOĞRUYDU — kırılan
  // şey ffmpeg'in dosya adından yaptığı çıkarımdı. İki katman da kilitleniyor.
  for (const [a, kap, uz] of [
    [remuxArgumanlari('/g.mkv', '/c.mp4'), 'mp4', '.mp4'],
    [sesCevirmeArgumanlari('/g.mkv', '/c.mp4'), 'mp4', '.mp4'],
    [remuxArgumanlari('/g.mkv', '/c.webm', 'webm'), 'webm', '.webm'],
    [sesCevirmeArgumanlari('/g.mkv', '/c.webm', 'webm'), 'webm', '.webm'],
    [tamCevrimArgumanlari('/g.mp4', '/c.mp4'), 'mp4', '.mp4'],
  ]) {
    assert.ok(a[a.length - 1].endsWith(uz), `çıktı ${uz} ile bitmeli: ${a[a.length - 1]}`);
    // `-f` ÇIKTIDAN HEMEN ÖNCE: ffmpeg'te çıktı seçenekleri sonraki dosyaya uygulanır.
    assert.equal(a[a.length - 3], '-f');
    assert.equal(a[a.length - 2], kap);
  }
});

test('WebM hedefinde ses AAC DEĞİL Opus (kap AAC kabul etmez)', () => {
  const a = sesCevirmeArgumanlari('/g.mkv', '/c.webm', 'webm');
  assert.equal(a[a.indexOf('-c:a') + 1], 'libopus');
  assert.ok(!a.includes('+faststart'), 'faststart MP4a özgü');
});

test('argumanlar(): kap kararın hedefUzantısından geliyor', () => {
  const mp4 = argumanlar({ eylem: 'ses', hedefUzanti: 'mp4' }, '/g', '/c.mp4');
  const webm = argumanlar({ eylem: 'ses', hedefUzanti: 'webm' }, '/g', '/c.webm');
  assert.equal(mp4[mp4.length - 2], 'mp4');
  assert.equal(webm[webm.length - 2], 'webm');
});

// ===========================================================================
// 5. İLERLEME AYRIŞTIRMA
// ===========================================================================

test('ilerleme: out_time_us + toplam süreden yüzde', () => {
  const p = ilerlemeAyristir('frame=100\nout_time_us=30000000\nprogress=continue\n', 60000);
  assert.equal(p.yuzde, 50);
  assert.equal(p.bitti, false);
});

test('ilerleme: parçadaki SON ölçüm alınır', () => {
  const metin = 'out_time_us=1000000\nprogress=continue\nout_time_us=9000000\nprogress=continue\n';
  assert.equal(ilerlemeAyristir(metin, 10000).yuzde, 90);
});

test('ilerleme: bitmeden %100 GÖSTERİLMEZ', () => {
  // Kullanıcı %100 görüp dosyanın hazır olmadığı bir aralıkta beklememeli.
  const p = ilerlemeAyristir('out_time_us=60000000\nprogress=continue\n', 60000);
  assert.equal(p.yuzde, 99);
});

test('ilerleme: progress=end ile 100 ve bitti', () => {
  const p = ilerlemeAyristir('out_time_us=60000000\nprogress=end\n', 60000);
  assert.equal(p.yuzde, 100);
  assert.equal(p.bitti, true);
});

test('ilerleme: süre bilinmiyorsa yüzde null ama bitiş yine okunur', () => {
  assert.deepEqual(ilerlemeAyristir('out_time_us=5\nprogress=end\n', null),
    { yuzde: null, bitti: true });
  assert.deepEqual(ilerlemeAyristir('', 1000), { yuzde: null, bitti: false });
});

// ===========================================================================
// 5b. DAVRANIŞ — ffmpeg GERÇEKTEN çalıştırılır
// ===========================================================================
// NEDEN GEREKLİ: 4 Eyl 2026'da hazırlık canlıda HER SEFERİNDE düştü ve
// yukarıdaki argüman testlerinin HİÇBİRİ bunu yakalamadı. Argümanlar doğruydu;
// kırılan şey ffmpeg'in ÇIKTI DOSYA ADINDAN yaptığı muxer çıkarımıydı
// (`15.hazirlik` uzantısız). Argüman dizisini karşılaştıran bir test, aracın
// DAVRANIŞINI hiç sınamaz. Bu bölüm gerçek bir dosya üretip gerçek ffmpeg'i
// koşturur — aynı sınıftaki hatalar bir daha kaçmaz.
//
// ffmpeg yoksa test ATLANIR (kırılmaz): CI'da araç bulunmayabilir.

const { execFileSync, execFile: execFileCb } = await import('node:child_process');
const os = await import('node:os');

function ffmpegVar() {
  try {
    execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
    execFileSync('ffprobe', ['-version'], { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

const FFMPEG = ffmpegVar();
const kos = (args) => new Promise((ok) => execFileCb(
  'ffmpeg', args, { maxBuffer: 4 * 1024 * 1024 }, (e) => ok(e)));
const probeEt = (yol) => JSON.parse(execFileSync('ffprobe',
  ['-v', 'error', '-print_format', 'json', '-show_format', '-show_streams', yol],
  { encoding: 'utf8' }));

test('DAVRANIŞ: H.264+AC3 MKV gerçekten MP4/AAC oluyor', { skip: !FFMPEG }, async () => {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'odahaz-'));
  try {
    const kaynak = path.join(dizin, 'kaynak.mkv');
    // 1 saniyelik gerçek MKV: H.264 görüntü + AC3 ses (film MKVlerinin kalıbı).
    const uret = await kos(['-nostdin', '-v', 'error', '-y',
      '-f', 'lavfi', '-i', 'testsrc2=size=160x120:rate=10:duration=1',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=1',
      '-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'ac3', '-shortest',
      kaynak]);
    assert.equal(uret, null, 'test kaynağı üretilemedi');

    const probe = probeEt(kaynak);
    const karar = hazirlikKarari(probe, null);
    assert.equal(karar.eylem, 'ses', 'AC3 sesin çevrilmesi bekleniyordu');

    // ÜRETİMDEKİ ad kalıbının AYNISI: `<id>.hazirlik.<uzanti>`. Uzantısı
    // olmasaydı ffmpeg muxer seçemez ve bu test kırmızıya dönerdi.
    const cikis = path.join(dizin, `15.hazirlik.${karar.hedefUzanti}`);
    const hata = await kos(argumanlar(karar, kaynak, cikis));
    assert.equal(hata, null, `ffmpeg düştü: ${hata && hata.message}`);
    assert.ok(fs.existsSync(cikis) && fs.statSync(cikis).size > 0);

    const son = probeEt(cikis);
    const kodekler = son.streams.map((x) => `${x.codec_type}=${x.codec_name}`);
    assert.ok(kodekler.includes('video=h264'), `görüntü kopyalanmalıydı: ${kodekler}`);
    assert.ok(kodekler.includes('audio=aac'), `ses AACye inmeliydi: ${kodekler}`);
    assert.match(son.format.format_name, /mp4|mov/);

    // FASTSTART: moov başta mı? Sonda olsaydı 5 GBlık dosya hiç açılmazdı.
    const fd = fs.openSync(cikis, 'r');
    const bas = Buffer.alloc(65536);
    const n = fs.readSync(fd, bas, 0, 65536, 0);
    fs.closeSync(fd);
    assert.equal(mp4FaststartVar(bas.subarray(0, n)), true, 'moov başta olmalı');
  } finally {
    fs.rmSync(dizin, { recursive: true, force: true });
  }
});

test('DAVRANIŞ: UZANTISIZ çıktı ffmpegi düşürür (kök sebebin kanıtı)',
  { skip: !FFMPEG }, async () => {
    // Bu test, düzeltmenin NEDEN gerektiğini kilitler: aynı argümanlar
    // uzantısız bir çıktıya yazılmaya çalışılınca ffmpeg muxer seçemez.
    // `-f` bayrağı EKLENMEDEN denenirse hata alınmalı.
    const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'odahaz2-'));
    try {
      const kaynak = path.join(dizin, 'k.mkv');
      await kos(['-nostdin', '-v', 'error', '-y',
        '-f', 'lavfi', '-i', 'testsrc2=size=160x120:rate=10:duration=1',
        '-c:v', 'libx264', '-preset', 'ultrafast', kaynak]);
      const uzantisiz = path.join(dizin, '15.hazirlik');
      const hata = await kos(['-nostdin', '-v', 'error', '-y', '-i', kaynak,
        '-c', 'copy', uzantisiz]);
      assert.notEqual(hata, null,
        'uzantısız çıktı ffmpegi düşürmeliydi — canlıda tam bu oldu');
    } finally {
      fs.rmSync(dizin, { recursive: true, force: true });
    }
  });

// ===========================================================================
// 6. BAĞLANTI — server.js doğru bağlamış mı
// ===========================================================================

test('bağlantı: server.js video_hazirla.js modülünü içe aktarıyor', () => {
  assert.match(oku('server.js'), /from '\.\/video_hazirla\.js'/);
});

test('bağlantı: hazırlık işi Dockerfile COPY listesinde', () => {
  // Modül imaja girmezse konteyner açılışta patlar.
  assert.match(oku('Dockerfile'), /video_hazirla\.js/);
});

test('bağlantı: hazırlanan dosyanın adı İMZA KALIBINA uyuyor', async () => {
  // Kalıba uymayan ad SESSİZCE imzasız döner ve istemci 403 alır
  // (IZLEME-ODASI-PLANI.md §6.1 — 3 Eyl 2026'da tam bu yaşandı).
  const { DOSYA_KALIP } = await import('../medya_imza.js');
  const s = oku('server.js');
  const i = s.indexOf('function odaHazirlikCalistir');
  assert.ok(i > 0, 'odaHazirlikCalistir bulunamadı');
  const govde = s.slice(i, i + 4000);
  const m = govde.match(/const yeniAd = `([^`]+)`/);
  assert.ok(m, 'hazırlık çıktısının ad şablonu bulunamadı');
  const ornek = m[1]
    .replace('${oda.id}', '7')
    .replace("${crypto.randomBytes(8).toString('hex')}", '0011223344556677')
    .replace('${karar.hedefUzanti}', 'mp4');
  assert.match(ornek, DOSYA_KALIP, `imzalanamayacak ad: ${ornek}`);
});

test('bağlantı: hazırlık AYNI ANDA TEK İŞ ve yalnız görevli işçide', () => {
  const s = oku('server.js');
  const i = s.indexOf('ODA VİDEO HAZIRLAMA');
  assert.ok(i > 0);
  const bolum = s.slice(i, i + 12000);
  assert.match(bolum, /ISCI_GOREVLI/, 'dört işçi birden ffmpeg açmamalı');
  assert.match(bolum, /odaHazirlikMesgul/, 'tek iş kilidi olmalı');
});

test('bağlantı: açılışta ASILI iş kurtarılıyor', () => {
  // Süreç ffmpeg ortasında ölürse satır `isleniyor` kalır; kullanıcı sonsuza
  // kadar %42te bakar.
  const s = oku('server.js');
  assert.match(s, /hazirlik_durum='kuyrukta'[\s\S]{0,200}WHERE hazirlik_durum='isleniyor'/,
    'açılışta isleniyor satırları yeniden kuyruğa alınmalı');
});

test('bağlantı: şema ile migrasyon hazırlık kolonlarında BİREBİR', () => {
  const sema = oku('sema.sql');
  const mig = oku('migrasyon-2026-09-04b.sql');
  for (const kolon of ['hazirlik_durum', 'hazirlik_yuzde', 'hazirlik_hata',
    'video_kodek', 'ses_kodek']) {
    assert.match(sema, new RegExp(kolon), `sema.sql: ${kolon}`);
    assert.match(mig, new RegExp(kolon), `migrasyon: ${kolon}`);
  }
});

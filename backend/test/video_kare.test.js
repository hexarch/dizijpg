// video_kare.js — kapak karesi sözleşmesi.
// ffmpeg yoksa üretim testi atlanır; argüman kilidi her ortamda koşar.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  VIDEO_KARE_UZUN_KENAR,
  VIDEO_KARE_JPEG_Q,
  videoKareHedef,
  videoKareFfmpegArgs,
  videoKareCikar,
  videoKareTaramaArgs,
  videoKareAniBul,
  kareAniSec,
  VIDEO_KARE_VARSAYILAN_SN,
} from '../video_kare.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
const ffmpegVar = spawnSync('ffmpeg', ['-version']).status === 0;

test('kapak tavanı 720, JPEG q=2 — 480/q4 eski kurala DÖNÜLMEZ', () => {
  assert.equal(VIDEO_KARE_UZUN_KENAR, 720);
  assert.equal(VIDEO_KARE_JPEG_Q, 2);
});

test('hedef yol videonun yanına .jpg ekler, videoyu EZMEZ', () => {
  assert.equal(videoKareHedef('/veri/medya/m1-abcd.mp4'), '/veri/medya/m1-abcd.mp4.jpg');
  assert.notEqual(videoKareHedef('/x.mp4'), '/x.mp4');
});

test('ffmpeg argümanları: lanczos, büyütme yok, çıktı .jpg', () => {
  const args = videoKareFfmpegArgs('/tmp/v.mp4');
  assert.equal(args[0], '-y');
  assert.ok(args.includes('-i'));
  assert.equal(args[args.indexOf('-i') + 1], '/tmp/v.mp4');
  const vf = args[args.indexOf('-vf') + 1];
  assert.match(vf, /lanczos/);
  assert.match(vf, /min\(720/);
  assert.doesNotMatch(vf, /scale=480/);
  assert.equal(args[args.indexOf('-q:v') + 1], '2');
  assert.equal(args.at(-1), '/tmp/v.mp4.jpg');
});

test('argümanlar verilen anı -ss olarak kullanır; verilmezse 0,5', () => {
  assert.equal(videoKareFfmpegArgs('/tmp/v.mp4', 2.4)[5], '2.4');
  const args = videoKareFfmpegArgs('/tmp/v.mp4');
  assert.equal(args[args.indexOf('-ss') + 1], String(VIDEO_KARE_VARSAYILAN_SN));
  assert.equal(VIDEO_KARE_VARSAYILAN_SN, 0.5);
});

test('tarama: 10 sn pencere, küçültülmüş signalstats, kare yazmaz', () => {
  const args = videoKareTaramaArgs('/tmp/v.mp4');
  assert.equal(args[args.indexOf('-t') + 1], '10');
  assert.match(args[args.indexOf('-vf') + 1], /^scale=64:-2,signalstats,metadata=print/);
  assert.equal(args.at(-2), 'null');
  assert.equal(args.at(-1), '-');
  assert.ok(!args.includes('.jpg'));
});

const satir = (t, y) => `frame:0 pts:0 pts_time:${t}\nlavfi.signalstats.YAVG=${y}\n`;

test('kareAniSec: siyah açılış atlanır, eşiği geçen İLK kare seçilir', () => {
  const cikti = satir(0, 16) + satir(0.5, 16) + satir(1, 30)
    + satir(1.5, 70) + satir(2, 120) + satir(2.5, 118);
  // tavan 120 → eşik max(40, 72) = 72 → ilk geçen 2.0 (70 yetmez)
  assert.equal(kareAniSec(cikti), 2);
});

test('kareAniSec: video renkli başlıyorsa 0 sn (kapak değişmez)', () => {
  assert.equal(kareAniSec(satir(0, 110) + satir(0.5, 100) + satir(1, 20)), 0);
});

test('kareAniSec: baştan sona karanlık videoda en parlak kare', () => {
  assert.equal(kareAniSec(satir(0, 5) + satir(1, 12) + satir(2, 30) + satir(3, 9)), 2);
});

test('kareAniSec: boş/bozuk çıktı null (varsayılana düşülür)', () => {
  assert.equal(kareAniSec(''), null);
  assert.equal(kareAniSec('bir seyler\nyanlis'), null);
  assert.equal(kareAniSec('lavfi.signalstats.YAVG=90\n'), null); // zamansız
});

test('server.js kapak üretimini video_kare.js\'ten alır (480 kopyası yok)', () => {
  assert.match(SERVER, /from '\.\/video_kare\.js'/);
  assert.match(SERVER, /videoKareCikar/);
  // Eski satırın geri gelmesi ızgarayı yine 480'e düşürür.
  assert.doesNotMatch(SERVER, /scale=480:-2/);
});

test('video_kare.js Dockerfile COPY listesinde', () => {
  const copy = DOCKERFILE.split('\n').find((s) => s.startsWith('COPY server.js'));
  assert.ok(copy, 'COPY server.js satırı yok');
  assert.match(copy, /\bvideo_kare\.js\b/);
});

test('toplu yenileme betiği imaja girer', () => {
  assert.match(DOCKERFILE, /video_kare_yenile\.js/);
});

test('1080p kaynaktan kapak ≤720 ve video dosyasına dokunulmaz', {
  skip: !ffmpegVar,
}, async () => {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'videokare-'));
  const video = path.join(dizin, 'kaynak.mp4');
  execFileSync('ffmpeg', [
    '-y', '-v', 'error', '-f', 'lavfi',
    '-i', 'testsrc2=size=1080x1920:rate=5:duration=1',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-an', video,
  ], { timeout: 20000 });
  const oncekiBoyut = fs.statSync(video).size;
  const tamam = await videoKareCikar(video);
  assert.equal(tamam, true);
  const kapak = videoKareHedef(video);
  assert.equal(fs.existsSync(kapak), true);
  assert.equal(fs.statSync(video).size, oncekiBoyut, 'video ezildi');
  const bilgi = execFileSync('ffprobe', [
    '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height', '-of', 'csv=p=0', kapak,
  ], { encoding: 'utf8' }).trim();
  const [en, boy] = bilgi.split(',').map(Number);
  assert.ok(en <= 720, `kapak genişliği ${en} > 720`);
  assert.ok(boy <= 1280, `kapak yüksekliği ${boy}`);
  fs.rmSync(dizin, { recursive: true, force: true });
});

test('siyahtan açılan videoda kapak SİYAH DEĞİL (ilk renkli kare)', {
  skip: !ffmpegVar,
}, async () => {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'videokare-fade-'));
  const video = path.join(dizin, 'fade.mp4');
  // 2 sn siyahtan açılış (fade-in): eski kural (0,5 sn) siyaha yakın kare verirdi.
  execFileSync('ffmpeg', [
    '-y', '-v', 'error', '-f', 'lavfi',
    '-i', 'testsrc2=size=640x360:rate=10:duration=4',
    '-vf', 'fade=t=in:st=0:d=2:color=black',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-an', video,
  ], { timeout: 20000 });
  const an = await videoKareAniBul(video);
  assert.ok(an > 0.5 && an < 4, `an ${an}`);
  assert.equal(await videoKareCikar(video), true);
  const yavg = execFileSync('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-i', videoKareHedef(video),
    '-vf', 'signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=-',
    '-f', 'null', '-',
  ], { encoding: 'utf8' }).match(/YAVG=([\d.]+)/)[1];
  assert.ok(Number(yavg) > 60, `kapak karanlık: YAVG ${yavg}`);
  fs.rmSync(dizin, { recursive: true, force: true });
});

test('küçük kaynak büyütülmez (360p kapak 360 kalır)', {
  skip: !ffmpegVar,
}, async () => {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'videokare-kucuk-'));
  const video = path.join(dizin, 'kucuk.mp4');
  execFileSync('ffmpeg', [
    '-y', '-v', 'error', '-f', 'lavfi',
    '-i', 'testsrc2=size=360x640:rate=5:duration=1',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-an', video,
  ], { timeout: 20000 });
  assert.equal(await videoKareCikar(video), true);
  const bilgi = execFileSync('ffprobe', [
    '-v', 'error', '-select_streams', 'v:0',
    '-show_entries', 'stream=width', '-of', 'csv=p=0', videoKareHedef(video),
  ], { encoding: 'utf8' }).trim();
  assert.equal(Number(bilgi), 360);
  fs.rmSync(dizin, { recursive: true, force: true });
});

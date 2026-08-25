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

// PAYLAŞILAN YORUM — sohbette "gönderi + altında yorum" önizlemesi.
//
// KULLANICI İSTEĞİ (13 Eyl 2026, birebir): "gönderideki yorumlara basılı
// tutunca Instagram'daki gibi arkadaşlarıma gönderebilmeliyim; mesajlar
// kısmında da gönderi ve gönderinin altında solu %10 boş kalacak şekilde
// sağa doğru kullanıcı logosu ve yorum olmalı."
//
// KORUNAN KARARLAR:
//  1) Paylaşılan şey bir YANITSA sohbetteki KART ÜST GÖNDERİNİNDİR (kapak,
//     oran, sahibi onun). Yanıtın kendi medyası çoğu zaman yoktur; kartı
//     yanıttan kurmak boş çerçeve demekti.
//  2) Paylaşılan yorum `yorum` alanında AYRI gider — istemci onu kartın
//     altına çizer. Alan yoksa istemci eski (tek kart) yolunda kalır.
//  3) Üst gönderi okunamıyorsa (silinmiş) yanıt KENDİ BAŞINA çizilir.
//  4) Sorgu üst gönderiyi AYNI turda çeker (LEFT JOIN) — N+1 yok.
//
// Saf fonksiyon kaynaktan ÇEKİLİP çalıştırılıyor (server.js içe aktarıldığı
// anda `app.listen` çağırır; mesaj_tepkisi.test.js ile aynı gerekçe).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function fonksiyonuCek(ad) {
  const bas = KAYNAK.indexOf(`function ${ad}(`);
  assert.ok(bas > 0, `${ad} server.js'te bulunamadı`);
  let i = KAYNAK.indexOf('{', bas);
  let derinlik = 0;
  for (let j = i; j < KAYNAK.length; j++) {
    if (KAYNAK[j] === '{') derinlik++;
    else if (KAYNAK[j] === '}' && --derinlik === 0) {
      // eslint-disable-next-line no-new-func
      return new Function(`${KAYNAK.slice(bas, j + 1)}; return ${ad};`)();
    }
  }
  throw new Error(`${ad} gövdesi kapanmadı`);
}

const onizleme = fonksiyonuCek('paylasilanGonderiOnizleme');

const GONDERI = {
  id: 10,
  kullanici_adi: 'alcelik',
  avatar: '/avatarlar/a.webp',
  metin: 'gönderi metni',
  medya: ['/medya/m1-abc.mp4'],
  medya_oran: 0.5625,
  tur: 'tv',
  tmdb_id: 1396,
  ust_id: null,
  ust_metin: null,
  ust_medya: null,
  ust_kullanici_adi: null,
  ust_medya_oran: null,
};

const YANIT = {
  ...GONDERI,
  id: 11,
  kullanici_adi: 'melisa',
  avatar: '/avatarlar/m.webp',
  metin: 'bu sahne efsaneydi',
  medya: [],
  medya_oran: null,
  ust_id: 10,
  ust_metin: 'gönderi metni',
  ust_medya: ['/medya/m1-abc.mp4'],
  ust_kullanici_adi: 'alcelik',
  ust_medya_oran: 0.5625,
};

test('sıradan gönderi: kart gönderinin kendisi, `yorum` alanı YOK', () => {
  const o = onizleme(GONDERI);
  assert.equal(o.kullanici_adi, 'alcelik');
  assert.equal(o.kapak, '/medya/m1-abc.mp4');
  assert.equal(o.medya_oran, 0.5625);
  assert.equal(o.yorum, undefined, 'gönderide yorum satırı çizilmemeli');
});

test('paylaşılan YANIT: kart ÜST GÖNDERİ, yorum ayrı alanda', () => {
  const o = onizleme(YANIT);
  assert.equal(o.id, 11, 'dokunuş paylaşılan yanıta gitmeli');
  assert.equal(o.ust_id, 10);
  // Kart üst gönderinin: kapak, oran ve ad ONDAN gelir.
  assert.equal(o.kullanici_adi, 'alcelik');
  assert.equal(o.kapak, '/medya/m1-abc.mp4');
  assert.equal(o.medya_oran, 0.5625);
  // Alttaki satır yorumun.
  assert.deepEqual(o.yorum, {
    kullanici_adi: 'melisa',
    avatar: '/avatarlar/m.webp',
    metin: 'bu sahne efsaneydi',
    medya: null,
  });
});

test('medyalı yorum: `yorum.medya` ilk dosya', () => {
  const o = onizleme({ ...YANIT, medya: ['/medya/m2-def.webp'] });
  assert.equal(o.yorum.medya, '/medya/m2-def.webp');
  assert.equal(o.kapak, '/medya/m1-abc.mp4', 'kart yine ÜST gönderinin');
});

test('üst gönderi silinmişse yanıt KENDİ BAŞINA çizilir', () => {
  const o = onizleme({ ...YANIT, ust_kullanici_adi: null, ust_medya: null });
  assert.equal(o.kullanici_adi, 'melisa');
  assert.equal(o.yorum, undefined);
});

test('uzun yorum kırpılır (280) ama gönderi metninden AYRI eşikte', () => {
  const uzun = 'x'.repeat(400);
  const o = onizleme({ ...YANIT, metin: uzun, ust_metin: uzun });
  assert.equal(o.yorum.metin.length, 280);
  assert.equal(o.metin.length, 140);
});

test('sorgu üst gönderiyi AYNI turda çeker (LEFT JOIN, N+1 yok)', () => {
  const bas = KAYNAK.indexOf('const gonderiIdler = ');
  assert.ok(bas > 0);
  const blok = KAYNAK.slice(bas, bas + 2500);
  assert.match(blok, /LEFT JOIN yorumlar u ON u\.id = y\.ust_id/);
  assert.match(blok, /LEFT JOIN kullanicilar uk ON uk\.id = u\.kullanici_id/);
  assert.match(blok, /ust_medya_oran/);
});

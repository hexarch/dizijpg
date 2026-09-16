// KULLANIM YAŞI 13+ — doğum tarihi doğrulaması (16 Eyl 2026, kullanıcı
// bildirdi: kayıtta 2025 doğumlu seçilebiliyordu). `node --test test/*.test.js`
//
// Kilitlenenler:
//   · yıl gizliyse (null) yaş doğrulanmaz — yıl İSTEĞE BAĞLI kalır
//   · sınır tarihi bugünden TAM 13 yıl öncesi; o gün doğan geçer, ertesi gün
//     doğan geçmez (yıl değil, gün hassasiyeti: 2013 doğumlu ama Ekim'de
//     doğmuş biri 16 Eyl 2026'da hâlâ 12)
//   · `gecerliDogum` eski kuralını korur (bu yıla kadar her yıl "geçerli
//     biçim"), yaş ayrı fonksiyonda — 400 mesajı ayrışsın diye
//
// YÖNTEM: server.js içe aktarılamıyor (dogum_gunu.test.js ile aynı gerekçe);
// fonksiyonlar KAYNAKTAN ÇEKİLİP çalıştırılıyor.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function blokSonu(kaynak, bas) {
  let derinlik = 0;
  let basladi = false;
  for (let i = bas; i < kaynak.length; i++) {
    const c = kaynak[i];
    if (c === '{') { derinlik++; basladi = true; } else if (c === '}') {
      derinlik--;
      if (basladi && derinlik === 0) return i + 1;
    }
  }
  throw new Error('blok kapanmadı');
}

function fonksiyonKaynagi(ad) {
  const imza = `function ${ad}(`;
  const bas = KAYNAK.indexOf(imza);
  assert.notEqual(bas, -1, `${ad} server.js'te bulunamadı`);
  return KAYNAK.slice(bas, blokSonu(KAYNAK, bas));
}

const ADLAR = ['gecerliDogum', 'dogumYasiUygun'];
// eslint-disable-next-line no-new-func
const { gecerliDogum, dogumYasiUygun } = new Function(
  `${ADLAR.map(fonksiyonKaynagi).join('\n')}\nreturn { ${ADLAR.join(', ')} };`,
)();

const bugun = new Date(Date.UTC(2026, 8, 16)); // 16 Eyl 2026 → sınır 16 Eyl 2013

test('yıl verilmediyse yaş doğrulanmaz (yıl isteğe bağlı)', () => {
  assert.equal(dogumYasiUygun(16, 9, null, bugun), true);
  assert.equal(dogumYasiUygun(1, 1, undefined, bugun), true);
});

test('sınır günü geçer, ertesi gün geçmez', () => {
  assert.equal(dogumYasiUygun(16, 9, 2013, bugun), true);
  assert.equal(dogumYasiUygun(17, 9, 2013, bugun), false);
  assert.equal(dogumYasiUygun(15, 9, 2013, bugun), true);
});

test('sınır yılında ay hassasiyeti: Ağustos geçer, Ekim geçmez', () => {
  assert.equal(dogumYasiUygun(31, 8, 2013, bugun), true);
  assert.equal(dogumYasiUygun(1, 10, 2013, bugun), false);
});

test('sınır yılı dışında yalnız yıla bakılır', () => {
  assert.equal(dogumYasiUygun(31, 12, 2012, bugun), true);
  assert.equal(dogumYasiUygun(1, 1, 2014, bugun), false);
  assert.equal(dogumYasiUygun(1, 1, 2025, bugun), false); // bildirilen hata
  assert.equal(dogumYasiUygun(1, 1, 1990, bugun), true);
});

test('29 Şubat sınırı artık olmayan yılda 1 Mart gibi davranır', () => {
  const artik = new Date(Date.UTC(2028, 1, 29)); // sınır "29 Şub 2015" (yok)
  assert.equal(dogumYasiUygun(28, 2, 2015, artik), true);
  assert.equal(dogumYasiUygun(1, 3, 2015, artik), false);
});

test('gecerliDogum biçim kuralı değişmedi: 2025 biçimce geçerli, yaş ayrı', () => {
  // Uç sırayla sorar: önce biçim (400 "Geçersiz doğum tarihi"), sonra yaş
  // (400 "En az 13 yaşında olmalısın", kod YAS_KUCUK). Biçim kuralına yaş
  // sızsaydı iki mesaj birbirine karışırdı.
  assert.equal(gecerliDogum(1, 1, 2025), true);
  assert.equal(gecerliDogum(29, 2, 2013), false);
  assert.equal(gecerliDogum(29, 2, null), true);
  assert.match(KAYNAK, /kod: 'YAS_KUCUK'/);
});

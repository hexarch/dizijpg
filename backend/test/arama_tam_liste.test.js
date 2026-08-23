// ARAMA TAM LİSTESİ (23 Ağu 2026) — `/ara-tur` + `/kullanici-ara?tam=1`.
//
// Önizleme (/ara) TMDB'nin ilk sayfasıyla sınırlıydı; "Daha fazlasını gör"
// bu iki ucu sayfa sayfa çağırır. Testler kaynak kilididir (server.js
// app.listen yüzünden içe aktarılamıyor — engelleme.test.js ile aynı
// gerekçe): uçların sözleşmesini bozan değişiklik adıyla kırmızıya döner.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function bolum(bas, son) {
  const i = KAYNAK.indexOf(bas);
  assert.notEqual(i, -1, `kaynakta bulunamadı: ${bas}`);
  const j = KAYNAK.indexOf(son, i + bas.length);
  assert.notEqual(j, -1, `kaynakta bulunamadı: ${son}`);
  return KAYNAK.slice(i, j);
}

const araTur = bolum("app.get('/ara-tur'", "// ENGELLEME");
const kullaniciAra = bolum(
  "app.get('/kullanici-ara'",
  "// ---------- veri dışa / içe aktarma",
);
const tamDal = bolum("if (req.query.tam === '1')", 'return res.json({');
// Önizleme dalı: tam dalın return'ünden SONRAKİ sorgu.
const onizlemeDal = kullaniciAra.slice(
  kullaniciAra.indexOf('devam_var'),
);

test('/ara-tur üç türü tanır, geçersiz tür 400 verir', () => {
  assert.match(KAYNAK, /tv: '\/search\/tv', movie: '\/search\/movie', person: '\/search\/person'/);
  assert.match(araTur, /Geçersiz tür/);
  assert.match(araTur, /status\(400\)/);
});

test('/ara-tur girişli ve hız limitli', () => {
  assert.match(araTur, /girisZorunlu,\s*aramaLimiti/);
});

test('/ara-tur sayfayı [1, ARA_TUR_AZAMI_SAYFA] aralığına kıstırır (üst sınır 50)', () => {
  assert.match(KAYNAK, /const ARA_TUR_AZAMI_SAYFA = 50;/);
  assert.match(araTur, /Math\.min\(\s*\n?\s*Math\.max\(parseInt\(req\.query\.sayfa, 10\) \|\| 1, 1\), ARA_TUR_AZAMI_SAYFA\)/);
  // toplam_sayfa da aynı tavana kıstırılır — istemci 50'den ötesini istemesin
  assert.match(araTur, /Math\.min\(d\.total_pages \|\| 1, ARA_TUR_AZAMI_SAYFA\)/);
});

test('/ara-tur satırlara media_type damgalar (türe özel TMDB uçları döndürmez)', () => {
  assert.match(araTur, /map\(\(r\) => \(\{ \.\.\.r, media_type: tur \}\)\)/);
});

test('/ara-tur arama TTL disiplinine uyar (boş sonuç kısa yaşar)', () => {
  assert.match(araTur, /aramaTtl\(ONBELLEK_TTL_SN\.varsayilan\)/);
});

test('kullanici-ara tam listesi ad ve bio alanlarında da arar', () => {
  assert.match(tamDal, /kullanici_adi LIKE \$1/);
  assert.match(tamDal, /lower\(COALESCE\(ad, ''\)\) LIKE \$1/);
  assert.match(tamDal, /lower\(COALESCE\(bio, ''\)\) LIKE \$1/);
});

test('kullanici-ara tam listesi misafir ve engel süzgeçlerini KORUR', () => {
  // Engelleme md.19: engellenen kişi arama sonucunda çıkmaz; misafirler
  // hiç listelenmez. Tam liste bu kuralları önizlemeyle aynen paylaşır.
  assert.match(tamDal, /misafir = false/);
  assert.match(tamDal, /engelSuzgec\('id', '\$3'\)/);
});

test('kullanici-ara tam listesi sayfalar ve devam bayrağı basar', () => {
  assert.match(tamDal, /SAYFA_BOY = 30/);
  assert.match(tamDal, /LIMIT \$\{SAYFA_BOY \+ 1\} OFFSET \$\{\(sayfa - 1\) \* SAYFA_BOY\}/);
  assert.match(kullaniciAra, /devam_var: rows\.length > SAYFA_BOY/);
});

test('önizleme dalı bio/ad ARAMAZ — her tuş vuruşunda çalışan yol ucuz kalır', () => {
  // Önizleme yalnız kullanıcı adında arar; bio taraması tam listeye özel.
  assert.match(onizlemeDal, /kullanici_adi LIKE \$1/);
  assert.ok(
    !onizlemeDal.includes("COALESCE(bio"),
    'önizleme sorgusu bio süzgeci içermemeli',
  );
  assert.ok(
    !onizlemeDal.includes("COALESCE(ad"),
    'önizleme sorgusu görünen ad süzgeci içermemeli',
  );
});

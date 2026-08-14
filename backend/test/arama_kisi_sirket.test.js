// GET /ara — kişi + şirket araması.
//
// Multi tv+movie+person döner, şirket (company) DÖNMEZ. Bu yüzden uç
// `/search/company` ve `/search/person` ile takviye eder; `media_type:
// 'company'` basar. Eski istemci (Play 1.40) `poster_path` yok diye şirketi
// dizi/film listesine koymaz — zararsız. icerikDizineEkle yalnız tv/movie.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function bildirimCek(ad) {
  const m = new RegExp(`^(const|function) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; }
    else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return KAYNAK.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return KAYNAK.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

function alan(adlar, ifade) {
  const govde = adlar.map(bildirimCek).join('\n');
  return new Function(`${govde}\nreturn (${ifade});`)();
}

function bolum(bas, son) {
  const i = KAYNAK.indexOf(bas);
  assert.notEqual(i, -1, `kaynakta bulunamadı: ${bas}`);
  const j = KAYNAK.indexOf(son, i + bas.length);
  assert.notEqual(j, -1, `kaynakta bulunamadı: ${son}`);
  return KAYNAK.slice(i, j);
}

const ara = bolum("app.get('/ara'", "app.get('/kullanici-ara'");

const aramaVaryantlari = alan(['aramaVaryantlari'], 'aramaVaryantlari');
const aramaAdDuz = alan(['aramaAdDuz'], 'aramaAdDuz');
const sirketAramaSatiri = alan(['sirketAramaSatiri'], 'sirketAramaSatiri');
const kisiAramaSatiri = alan(['kisiAramaSatiri'], 'kisiAramaSatiri');
const aramaSatirBirlestir = alan(['aramaSatirBirlestir'], 'aramaSatirBirlestir');
const aramaHedefleri = alan(['aramaAdDuz', 'aramaHedefleri'], 'aramaHedefleri');
const aramaPuanla = alan(['aramaAdDuz', 'aramaEnIyiIsabet', 'aramaPuanla'], 'aramaPuanla');
const aramaKisiSirketYollari = alan(['aramaKisiSirketYollari'], 'aramaKisiSirketYollari');
const icerikDizinSatirlari = alan(['icerikDizinSatirlari'], 'icerikDizinSatirlari');

test('/ara hâlâ /search/multi çağırır (aramaTtl seçici, eski istemci yolu)', () => {
  assert.match(ara, /\/search\/multi\?query=\$\{encodeURIComponent\(v\)\}`,\s*\n\s*aramaTtl\(/);
});

test('/ara kaynağında /search/company ve /search/person kilitli', () => {
  // Person yolu yardımcıda (8'li öbek); uç onu çağırır.
  assert.match(ara, /aramaKisiSirketYollari\(varyantlar,\s*q\)/);
  assert.match(ara, /\/search\/company/);
  assert.match(KAYNAK, /\/search\/person\?query=/);
  assert.match(KAYNAK, /\/search\/company\?query=/);
  assert.match(ara, /tmdbTopluGetir\(/);
  assert.match(KAYNAK, /media_type: 'company'/);
});

test('aramaKisiSirketYollari: varyant başına kişi + şirket, encodeURIComponent', () => {
  const yollar = aramaKisiSirketYollari(['cartoon network', 'cartoonnetwork'], 'cartoon network');
  assert.deepEqual(yollar, [
    '/search/person?query=cartoon%20network',
    '/search/company?query=cartoon%20network',
    '/search/person?query=cartoonnetwork',
    '/search/company?query=cartoonnetwork',
    '/search/company?query=cartoon%20network&page=2',
  ]);
  // 4 varyant × 2 = 8 (q yoksa ek sayfa yok) → tek TMDB öbeği.
  const dort = aramaKisiSirketYollari(['a', 'b', 'c', 'd']);
  assert.equal(dort.length, 8);
});

test('aramaKisiSirketYollari: cartoon → 2. sayfa + "cartoon network" takviyesi', () => {
  const yollar = aramaKisiSirketYollari(['cartoon'], 'cartoon');
  assert.ok(yollar.includes('/search/company?query=cartoon'));
  assert.ok(yollar.includes('/search/company?query=cartoon&page=2'));
  assert.ok(yollar.includes('/search/company?query=cartoon%20network'));
  assert.ok(yollar.includes('/search/person?query=cartoon'));
});

test('sirketAramaSatiri media_type company basar; eski alanlar durur', () => {
  const ham = { id: 7899, name: 'Cartoon Network Studios', logo_path: '/x.png', origin_country: 'US' };
  const s = sirketAramaSatiri(ham);
  assert.equal(s.media_type, 'company');
  assert.equal(s.id, 7899);
  assert.equal(s.name, 'Cartoon Network Studios');
  assert.equal(s.logo_path, '/x.png');
  assert.equal(s.origin_country, 'US');
  assert.equal(sirketAramaSatiri(null), null);
  assert.equal(sirketAramaSatiri({ name: 'adsız' }), null);
});

test('kisiAramaSatiri media_type person basar (person search bunu vermez)', () => {
  const k = kisiAramaSatiri({
    id: 66633,
    name: 'Vince Gilligan',
    known_for_department: 'Writing',
    known_for: [{ name: 'Breaking Bad' }],
  });
  assert.equal(k.media_type, 'person');
  assert.equal(k.known_for_department, 'Writing');
  assert.equal(k.known_for[0].name, 'Breaking Bad');
});

test('kişi/şirket tekilleştirme: aynı id birleşir, zengin alan korunur', () => {
  const multi = {
    media_type: 'person',
    id: 66633,
    name: 'Vince Gilligan',
    popularity: 2,
    profile_path: null,
  };
  const person = {
    media_type: 'person',
    id: 66633,
    name: 'Vince Gilligan',
    known_for_department: 'Writing',
    known_for: [{ name: 'Breaking Bad' }, { title: 'Hancock' }],
    profile_path: '/v.jpg',
    popularity: 2.9,
  };
  const bir = aramaSatirBirlestir(multi, person);
  assert.equal(bir.known_for_department, 'Writing');
  assert.equal(bir.profile_path, '/v.jpg');
  assert.equal(bir.known_for.length, 2);
  assert.equal(bir.popularity, 2.9);

  const a = sirketAramaSatiri({ id: 1, name: 'A', logo_path: null });
  const b = sirketAramaSatiri({ id: 1, name: 'A', logo_path: '/logo.png' });
  assert.equal(aramaSatirBirlestir(a, b).logo_path, '/logo.png');
});

test('Cartoon Network: şirket dizi/filmden üste çıkar (birebir/önek)', () => {
  const hedefler = aramaHedefleri('cartoon network', aramaVaryantlari('cartoon network'));
  const sirket = sirketAramaSatiri({ id: 7899, name: 'Cartoon Network Studios' });
  const dizi = {
    media_type: 'tv',
    id: 300472,
    name: 'Cartoon Network Checker',
    popularity: 50,
    poster_path: '/p.jpg',
  };
  assert.ok(aramaPuanla(sirket, hedefler) > aramaPuanla(dizi, hedefler),
    'şirket önek eşleşmesi, popüler dizinin üstünde olmalı');

  const birebir = sirketAramaSatiri({ id: 1, name: 'Cartoon Network' });
  assert.ok(aramaPuanla(birebir, hedefler) > aramaPuanla(sirket, hedefler));
});

test('cartoon: Cartoon Network Studios, kısa ada "Cartoon"dan üste çıkar', () => {
  const hedefler = aramaHedefleri('cartoon', aramaVaryantlari('cartoon'));
  assert.ok(hedefler.includes('cartoonnetwork'));
  const kisa = sirketAramaSatiri({ id: 123981, name: 'Cartoon' });
  const hangover = sirketAramaSatiri({ id: 279003, name: 'Cartoon Hangover' });
  const cn = sirketAramaSatiri({ id: 7899, name: 'Cartoon Network Studios' });
  assert.ok(aramaPuanla(cn, hedefler) > aramaPuanla(kisa, hedefler),
    'uzun "network" hedefi kısa birebir addan üstün');
  assert.ok(aramaPuanla(cn, hedefler) > aramaPuanla(hangover, hedefler),
    'Cartoon Hangover, Cartoon Network Studios\'u ezmemeli');
});

test('icerikDizinSatirlari company ve person almaz', () => {
  const liste = [
    { media_type: 'tv', id: 1, name: 'Dizi' },
    { media_type: 'movie', id: 2, title: 'Film' },
    { media_type: 'person', id: 3, name: 'Kişi' },
    { media_type: 'company', id: 7899, name: 'Cartoon Network Studios' },
  ];
  const satirlar = icerikDizinSatirlari(liste);
  assert.deepEqual(satirlar.map((r) => r.media_type).sort(), ['movie', 'tv']);
  assert.ok(!satirlar.some((r) => r.media_type === 'company'));
  assert.ok(!satirlar.some((r) => r.media_type === 'person'));
});

test('icerikDizineEkle hâlâ icerikDizinSatirlari süzgecini kullanır', () => {
  const fn = bildirimCek('icerikDizineEkle');
  assert.match(fn, /icerikDizinSatirlari\(liste\)/);
  assert.doesNotMatch(fn, /media_type === 'company'/);
});

test('/ara yeni uç açmaz; hız limiti aramaLimiti kalır', () => {
  assert.match(ara, /girisZorunlu, aramaLimiti/);
  assert.equal((KAYNAK.match(/app\.get\('\/ara'/g) || []).length, 1);
});

test('varyantlar the-siz ve boşluksuz (şirket/kişi yollarına da gider)', () => {
  const v = [...aramaVaryantlari('the black list')];
  assert.ok(v.includes('the black list'));
  assert.ok(v.includes('theblacklist'));
  assert.ok(v.includes('black list'));
  assert.ok(v.includes('blacklist'));
});

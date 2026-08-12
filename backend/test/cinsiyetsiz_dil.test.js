// PUSH_SABLON cinsiyet kilidi — `node --test test/*.test.js`
//
// KULLANICI KARARI (13 Ağu 2026): "kimseye cinsiyete göre hitap etmeyelim."
// Uygulama kullanıcıların cinsiyetini HİÇ SORMUYOR ve SAKLAMIYOR. Bu yüzden
// hiçbir push gövdesi, gövdedeki kişiye (aktör {ad} ya da alıcı "sen") göre
// çekimlenmiş fiil/sıfat İÇEREMEZ. Örneğin ru `'{ad} подписался на тебя'`
// kadın bir aktör için YANLIŞTI (подписалась olmalıydı) — yerine çekimden
// kaçan isim öbeği kullanılıyor: `'Новый подписчик: {ad}'`.
//
// AYRIM (bu dosyanın kilitlemediği şey): dilbilgisel cinsiyeti NESNEDEN gelen
// çekimler DOĞRUDUR ve dokunulmaz. `bolum` şablonunda ru `Вышла серия` dişil
// çekimdir çünkü öznesi "серия"dır; ar `صدرت` dişildir çünkü öznesi "حلقة"dır.
// Bunlar kullanıcı cinsiyeti değildir — o yüzden aşağıdaki desenler `bolum`
// anahtarını da tarar ama YALNIZ kişiye özgü kalıpları arar.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (yeni_bolum_bildirimi.test.js ile aynı gerekçe).
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const SERVER = readFileSync(new URL('../server.js', import.meta.url), 'utf8');
const BLOK = SERVER.slice(SERVER.indexOf('const PUSH_SABLON = {'),
  SERVER.indexOf('/**\n * {sb} yer tutucusunun değeri'));

// `PUSH_SABLON`u kaynaktan çekip GERÇEKTEN çalıştır — kopyasını değil.
const PUSH_SABLON = new Function(`${BLOK}\nreturn PUSH_SABLON;`)();

const AKTOR_TURLERI = ['takip', 'begeni', 'yanit', 'mesaj', 'etiket', 'arama',
  'kacirilan_arama'];

// Dile göre "kişiye göre çekimlenmiş eril biçim" kalıpları.
// Her biri bir kez canlıda YANLIŞ metin üretmiş ya da üretebilecek biçimdir.
const ERIL_KALIPLAR = {
  // Rusça: eril tekil geçmiş zaman (-л / -лся). Dişili -ла/-лась olurdu.
  ru: [/[а-яё]+л(ся)?\b/i],
  // Lehçe: eril tekil geçmiş zaman (-ął / -ił / -ał / -ył) ve -em eki.
  pl: [/[a-ząćęłńóśźż]*[aeiouyąę]ł(em|eś)?\b/i],
  // Arapça: aktöre göre çekimlenen eril mazi/muzari fiiller. Kalıp fiil+harf-i
  // cer bütünüdür: yalın "رد" AD'dır ("رد جديد" = yeni yanıt), fiil değil.
  ar: [/(^|\s)(بدأ\s|أعجب\s|ردّ?\s+على|أرسل\s|أشار\s+إلي|اتصل\s+بك|يتصل\s+بك|تابعك)/],
  // Fransızca: önüne geçmiş nesne zamiriyle uyumlanan ortaç (t'a suivi…).
  fr: [/t['’]a\s+(suivi|appelé|mentionné|identifié|taggé)\b/i],
  // İtalyanca: "ti ha ...ato" — ti/mi ile uyum eril varsayılana kayar.
  it: [/\bti ha (taggato|chiamato|menzionato|seguito)\b/i],
  // Hindi: "कर रहे हैं" eril saygı çoğuludur; dişili "कर रही हैं".
  hi: [/रहे हैं/],
  // Almanca/Hollandaca: aktöre ait iyelik "sein/zijn".
  de: [/\bsein(e|en|em)?\b/],
  nl: [/\bzijn (reactie|bericht|opmerking)/],
};

test('PUSH_SABLON: hiçbir gövde kişiye göre çekimlenmiş eril biçim taşımaz', () => {
  for (const [dil, kaliplar] of Object.entries(ERIL_KALIPLAR)) {
    assert.ok(PUSH_SABLON[dil], `${dil} şablonu kayboldu`);
    for (const [tur, metin] of Object.entries(PUSH_SABLON[dil])) {
      for (const k of kaliplar) {
        assert.ok(!k.test(metin),
          `${dil}.${tur} eril çekim içeriyor: "${metin}" (kalıp ${k})\n` +
          '  Çözüm: çekimden kaçan isim öbeği kur ("Новый подписчик: {ad}").');
      }
    }
  }
});

test('PUSH_SABLON: parantezli çift cinsiyet biçimi yok — ekran okuyucuyu bozar', () => {
  for (const [dil, sablon] of Object.entries(PUSH_SABLON)) {
    for (const [tur, metin] of Object.entries(sablon)) {
      assert.ok(!/\w\([a-zа-яё֐-׿]{1,3}\)/i.test(metin),
        `${dil}.${tur} "подписался(ась)" tarzı çift biçim taşıyor: "${metin}"`);
      assert.ok(!/\w\/\w{1,3}\b/.test(metin.replace(/https?:\/\//g, '')),
        `${dil}.${tur} "Одгледао/ла" tarzı çift biçim taşıyor: "${metin}"`);
    }
  }
});

test('PUSH_SABLON: aktörlü 7 türün HEPSİ hâlâ {ad} taşıyor (yeniden yazım kaybı)', () => {
  for (const [dil, sablon] of Object.entries(PUSH_SABLON)) {
    for (const tur of AKTOR_TURLERI) {
      assert.ok(sablon[tur], `${dil}.${tur} kayboldu`);
      assert.ok(sablon[tur].includes('{ad}'),
        `${dil}.${tur} yeniden yazılırken {ad} düşmüş: "${sablon[tur]}"`);
    }
  }
});

test("PUSH_SABLON: nesne kaynaklı çekim KORUNUYOR (ru 'Вышла серия', ar 'صدرت')", () => {
  // Bunlar kullanıcı cinsiyeti DEĞİL; öznesi "серия" (dişil) / "حلقة" (dişil).
  // Biri "eril varsayım" sanıp düzeltmeye kalkarsa burası patlar.
  assert.equal(PUSH_SABLON.ru.bolum, 'Вышла серия {dizi} {sb}');
  assert.equal(PUSH_SABLON.ar.bolum, 'صدرت {dizi} {sb}');
});

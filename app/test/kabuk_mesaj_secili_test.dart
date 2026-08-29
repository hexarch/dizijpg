// Alt çubukta MESAJLAR hedefinin seçili görünmesi.
//
// Kullanıcı (29 Ağu 2026): "aşağıdaki 5'li navigasyon tuşlarımız var ya,
// mesajlar kısmı hariç hepsine tıklayınca sarı oluyor, ama mesajlara
// tıklayınca sarı olmuyor."
//
// Kök: Mesajlar bir dal değil, akış dalının İÇİNDE `push` ediliyor (geri
// tuşu çalışsın diye). Bu yüzden `shell.currentIndex` asla mesajIndeksi
// olmuyordu ve `kabukSekmeIndeksi` mesaj yollarını bilerek akışa eşliyordu.
import 'package:flutter_test/flutter_test.dart';

import 'package:dizijpg/ekranlar/kabuk.dart';

void main() {
  test('mesaj yüzeyleri tanınıyor', () {
    expect(mesajYuzeyiMi('/sohbetler'), isTrue);
    expect(mesajYuzeyiMi('/sohbet/42'), isTrue);
    expect(mesajYuzeyiMi('/mesaj-istekleri'), isTrue);
    expect(mesajYuzeyiMi('/akis'), isFalse);
    expect(mesajYuzeyiMi('/profil'), isFalse);
    // Yakın ama farklı: sohbetle başlamayan bir yol yanlışlıkla girmesin.
    expect(mesajYuzeyiMi('/ayarlar/sohbet'), isFalse);
  });

  test('mesaj yüzeyindeyken ÇUBUKTA mesajlar seçili', () {
    // Dal akışta (2) kalsa bile çubuk mesajları boyar.
    expect(kabukSecili('/sohbetler', akisHedefi), mesajIndeksi);
    expect(kabukSecili('/sohbet/7', akisHedefi), mesajIndeksi);
    expect(kabukSecili('/mesaj-istekleri', akisHedefi), mesajIndeksi);
  });

  test('mesaj dışındaki yollarda davranış DEĞİŞMEZ', () {
    for (final yol in ['/akis', '/takvim', '/profil', '/arama', '/']) {
      for (var dal = 0; dal < 5; dal++) {
        expect(
          kabukSecili(yol, dal),
          dal,
          reason: '$yol için dal hedefi olduğu gibi kalmalı',
        );
      }
    }
  });

  test('DAL ÜYELİĞİ değişmedi — navigasyon mantığı korunuyor', () {
    // Görsel seçim ayrı bir soru: `kabukSekmeIndeksi` mesaj yollarını hâlâ
    // akış dalına eşliyor, yoksa `push`/geri davranışı bozulurdu.
    expect(kabukSekmeIndeksi('/sohbetler'), akisHedefi);
    expect(kabukSekmeIndeksi('/mesaj-istekleri'), akisHedefi);
  });
}

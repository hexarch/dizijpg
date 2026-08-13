dizi.jpg — DOĞUM GÜNÜ UYGULAMA İKONU ÖNERİLERİ (YAPILACAKLAR md. 36)
====================================================================

BUNLAR YALNIZ ÖNERİDİR. Hiçbiri uygulamaya kurulmadı; sen görüp seçmeden
uygulama ikonu DEĞİŞMEYECEK.


1) NEDEN İKON BU TURDA DEĞİŞMİYOR
---------------------------------
Android'de çalışma anında uygulama ikonu değiştirmenin resmi bir API'si yok.
Tek yol, manifeste önceden gömülmüş `activity-alias` girdilerini
`PackageManager` ile açıp kapatmak. Bunun yan etkileri gerçek ve geri
dönüşü zor:

  * Bazı başlatıcılarda (Samsung One UI, Nova, Pixel Launcher'ın bazı
    sürümleri) takas anında kısayol ANA EKRANDAN DÜŞER — kullanıcı ikonunu
    kaybeder, yeniden eklemesi gerekir.
  * Ana ekran widget'ları ve sabitlenmiş kısayollar kırılır.
  * Takas sırasında uygulama süreci öldürülebilir; kullanıcı o an ne
    yapıyorsa yarıda kalır.
  * iOS'ta `setAlternateIconName` var ama her değişimde SİSTEM UYARISI
    çıkarır ("... uygulama simgesini değiştirdi"); doğum gününde iki kez
    (aç/kapa) uyarı demektir.
  * Web/PWA'da karşılığı hiç yok.

"Kutlama" niyetiyle kullanıcının ana ekranındaki ikonunu kaybettiremeyiz.
Bu yüzden kutlama UYGULAMA İÇİNDE yapılıyor: açılışta konfeti + doğum günü
mesajı (`app/lib/ekranlar/dogum_gunu.dart`), günde bir kez, kapatılabilir,
"hareketi azalt" açıkken konfetisiz.

Yine de ikonu değiştirmek istersen: aşağıdaki varyantlardan birini seç, o
zaman `activity-alias` yolunu ve yukarıdaki riskleri ayrıca konuşuruz.


2) TASARIM KURALLARI (dördünde de aynı)
---------------------------------------
* Taban, uygulamanın GERÇEK ikonudur (`app/assets/icon/icon.png`): siyah
  zemin + açık gri "DİZİ" + kırmızı bloklu "JPG". Kelime işaretine
  dokunulmadı — kırpılmadı, kaydırılmadı, rengi değişmedi. İkon uzaktan
  bakınca AYNI ikon.
* Doğum günü teması TEK bir öğeyle veriliyor. Şapka + konfeti + balon üst
  üste binseydi ikon 48 dp'de lapaya dönerdi.
* Süslemeler kelime işaretinin ÜSTÜNDEKİ ve ALTINDAKİ boş şeritte duruyor;
  harflerin üstüne binmiyorlar.
* Aksan rengi marka sarısı #F5C518 (uygulamanın her yerindeki vurgu rengi).
  İkinci aksan, logodaki JPG bloğunun kırmızısı.
* Kenar payı: Android'in daire/squircle maskesi kenardan ~%10 kırpar;
  hiçbir öğe tuvalin dış %8'ine girmiyor.
* 512x512 PNG. Seçilen varyant `flutter_launcher_icons` ile 1024'e
  büyütülüp tüm yoğunluklara üretilir (betikteki BOYUT değerini 1024
  yapmak yeterli — tasarım oransal çizildi, yeniden ölçeklenir).


3) VARYANTLAR
-------------
0-mevcut-ikon.png
    Bugünkü ikon. Karşılaştırma için burada: varyantı tek başına değil,
    mevcutla YAN YANA değerlendir.

1-parti-sapkasi.png
    Kelime işaretinin üstüne hafif eğik oturan, ponponlu sarı parti
    şapkası — dört öneri içinde "doğum günü" mesajını en hızlı veren ve
    silüeti en net olan varyant.

2-konfeti.png
    Kelime işaretinin üstüne ve altına serpilmiş sarı/beyaz/kırmızı
    konfeti; markaya en az dokunan, en sakin seçenek (logonun kendisi
    hiç değişmiyor, yalnız etrafı şenleniyor) ama küçük boyutta konfeti
    parçaları "gürültü" gibi de okunabilir.

3-mum.png
    Kelime işaretini pastaya çeviren tek bir doğum günü mumu; sarı alev
    siyah zeminde ikonun tek parlak noktası olduğu için 48 dp'de bile
    seçiliyor, ayrıca yaş belirtmediği için her yaşa uyuyor.

4-balon.png
    Sağ üst köşeden yükselen sarı + kırmızı balon çifti; en "şenlikli"
    ve en renkli varyant, buna karşılık ikonun ağırlık merkezini sağa
    kaydırdığı için mevcut ikondan en uzak duran öneri.


4) YENİDEN ÜRETME
-----------------
    cd ikon-onerileri && python3 ikon_uret.py

Pillow gerekir (`pip3 install pillow`). Betik tasarımı SIFIRDAN çizer
(hiçbir çıktı elle rötuşlanmadı), yani renk/konum değiştirmek istersen
`ikon_uret.py` içindeki sabitleri düzenleyip tekrar çalıştırman yeterli.

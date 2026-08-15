# dizi.jpg — Çalışma Kuralları (ZORUNLU)

1. **Bu projede herhangi bir işe başlamadan ÖNCE `dizijpg-ux-kontrol` skill'ini
   yükle** (Skill aracıyla). Her dağıtımdan önce listesini uygula ve şüpheli
   maddeleri curl/kod okumasıyla KANITLA.
2. **UI/tasarım dokunuşlarında `ui-ux-pro-max` skill'inin veritabanına danış**
   (stil/renk/UX kuralı sorguları) — özellikle yeni ekran, boş durum, form,
   dokunma hedefi ve kontrast kararlarında.
3. Yol haritası `YAPILACAKLAR.md`'dir: yeni istekleri oraya işle, biteni işaretle.
4. Yeni kullanıcı metni = aynı turda 45 dile çeviri (skill'deki disiplinle).
5. Dağıtım ritüeli skill'de; atlama yok — özellikle SW sökücü ve uçtan uca curl testi.
6. Test hesapları skill'de; alcelik (id=3) gerçek kullanıcıdır, verisine dokunma.
7. **Etkileşimli bir widget'a dokunduysan KANIT ZORUNLU:** ya `test/` altına
   widget testi yaz ya da uygulamayı çalıştırıp o akışı elle geç. "Kodu okudum,
   doğru görünüyor" YETMEZ — 31 Tem'de üç Reels hatası (dokunulan kare atılıyor,
   ön yükleme yok, noktalar yanlış yerde) tam da böyle canlıya gitti.
   `flutter test` saniyeler sürer, tarayıcı otomasyonundan çok daha güvenilir:
   Flutter web tuvali erişilebilirlik ağacı vermez (`find` çalışmaz) ve sürükleme
   fling sayılıp sayfayı sona atar.
8. **İş bitince commit + `git push origin main` + canlı web dağıtımı.**
   Dağıtımı kullanıcıya sorma. 16 Tem–31 Tem arasında 53 commit push
   edilmeden bekledi; kullanıcı fark edip sordu. 16 Ağu: iş bitince
   “canlıya alayım mı” diye sorma — ritüeli uygula.
9. Gizli dosyalar depoda DEĞİL ve öyle kalmalı: `backend/.env`, `firebase-gizli/`
   (kök .gitignore), keystore + `key.properties` (`app/android/.gitignore`).
   Push öncesi doğrula:
   `git diff --cached --name-only | grep -iE '\.jks|key\.properties|\.env$|adminsdk'`

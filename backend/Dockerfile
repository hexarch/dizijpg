FROM node:22-alpine
WORKDIR /app
# ffmpeg: video yüklenince ilk kareden küçük resim üretilir (Keşfet
# ızgarası video yerine bu resmi gösterir; onlarca çözücü açılmaz).
# ffmpeg (üstte) + postgresql-client: panelden elle yedek (pg_dump) alınabilsin.
# gnupg: panelden alinan ELLE yedek de sifreli olsun (19 Agu 2026 istegi).
# Gece betigi host'ta gpg kullaniyor; konteynerde YOKTU ve o yuzden elle
# yedek sifresiz uretiliyordu. Ayni anahtarla ayni parametreler kullanilir.
RUN apk add --no-cache ffmpeg postgresql16-client gnupg
# package-lock.json ZORUNLU (guvenlik denetimi 2026-08-17 §4.8).
# ONCEKI HAL `npm install` idi ve lock dosyasi YOKTU: her derleme bagimliliklari
# semver araligindan YENIDEN cozuyordu. Yani (a) dun calisan imaj bugun farkli
# paketlerle dogabilir, (b) bir bagimliligin ele gecirilmis yama surumu
# yayinlanirsa bir sonraki derlemede SESSIZCE imaja girerdi. `npm audit` bile
# lock olmadan calismiyordu (ENOLOCK).
#
# `npm ci` lock'a BIREBIR uyar ve package.json ile lock uyusmazsa HATA verir —
# yani "package.json'i degistirdim ama lock'u guncellemedim" durumu derlemeyi
# kirar, sessizce farkli bir agac kurmaz.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
# kripto.js: özel mesajların durağan şifrelemesi. server.js onu import ediyor;
# imaja GIRMEZSE konteyner "Cannot find module './kripto.js'" ile acilista olur
# ve restart dongusune girer. Geri doldurma betigi de imaja giriyor ki
# `docker exec dizijpg-api node mesaj_sifrele_geri_doldur.js` calissin.
# medya_imza.js: DM medyasi icin imzali-sureli URL. server.js onu import
# ediyor; imaja GIRMEZSE konteyner "Cannot find module './medya_imza.js'" ile
# acilista olur (kripto.js ile ayni tuzak). test/medya_imza.test.js denetler.
# arama.js: sesli/goruntulu arama (sinyallesme deposu + TURN kimlik bilgisi +
# yetki zinciri). server.js onu import ediyor; imaja GIRMEZSE konteyner
# "Cannot find module './arama.js'" ile acilista olur ve restart dongusune
# girer — kripto.js / medya_imza.js ile AYNI tuzak. test/arama.test.js denetler.
# gunluk.js: yapilandirilmis (JSON) hata logu + sizinti suzgeci. server.js onu
# import ediyor; imaja GIRMEZSE konteyner "Cannot find module './gunluk.js'"
# ile acilista olur ve restart dongusune girer — kripto.js / medya_imza.js /
# arama.js ile AYNI tuzak. test/arama.test.js bu listeyi otomatik denetliyor
# (bu satir eklenmeden once testi KIRMIZIYA dondurdu, yani denetim calisiyor).
# kume.js / kume_ipc.js / kume_yardimci.js: D1 kümeleme — kume.js GİRİŞ
# NOKTASIDIR (CMD), kume_ipc/kume_yardimci'yi server.js import ediyor;
# herhangi biri imaja GIRMEZSE konteyner "Cannot find module" ile açılışta
# ölür ve restart döngüsüne girer (kripto.js ile AYNI tuzak).
# onbellek_ttl.js: TMDB arama önbelleğinin içeriğe bakan ömrü (sonuçsuz sorgu
# 15 dk yaşar). server.js onu import ediyor; imaja GIRMEZSE konteyner
# "Cannot find module './onbellek_ttl.js'" ile açılışta ölür — kripto.js /
# arama.js ile AYNI tuzak. test/onbellek_ttl.test.js bu satırı denetliyor.
# iki_adim.js: md. 52 — e-posta ile iki adimli dogrulama (sabitler, bilet
# uretimi/cozumu, karar agaci). server.js onu import ediyor; imaja GIRMEZSE
# konteyner "Cannot find module './iki_adim.js'" ile acilista olur —
# kripto.js / arama.js ile AYNI tuzak. test/arama.test.js bu listeyi otomatik
# denetliyor (bu satir eklenmeden once testi KIRMIZIYA dondurdu).
# disk.js: disk esigi kapisi (guvenlik denetimi 2026-08-17 §3.1). server.js onu
# import ediyor; imaja GIRMEZSE konteyner "Cannot find module './disk.js'" ile
# acilista olur ve restart dongusune girer — kripto.js / medya_imza.js /
# arama.js ile AYNI tuzak. test/arama.test.js bu listeyi otomatik denetliyor.
# gsc_izle.js: Search Console gunluk izleme (cron: `docker exec dizijpg-api
# node gsc_izle.js`). isitici.js ile AYNI tuzak: imaja GIRMEZSE cron her gece
# "Cannot find module './gsc_izle.js'" verir ve izleme HIC baslamaz — ustelik
# bu is SESSIZ calistigi icin (degisim yoksa posta yok) fark edilmesi haftalar
# alirdi. test/gsc_izle.test.js bu satiri denetliyor.
# NOT: servis hesabi anahtari BURAYA KOPYALANMAZ. Sir imaja girmez;
# firebase-admin.json gibi calisma aninda `:ro` baglanir (docker-compose.yml).
COPY server.js veri_aktar.js mail_kutu.js emoji.js depolama.js siralama.js dizi_durum.js cevrimici.js sohbet_bakiyor.js sohbet_durum.js kripto.js kisi_izlenme.js iki_adim.js yasak.js medya_imza.js medya_xaccel.js disk.js arama.js gunluk.js onbellek_ttl.js isitici.js sure_doldur.js gsc_izle.js kume.js kume_ipc.js kume_yardimci.js mesaj_sifrele_geri_doldur.js cihaz_sinif.js gonderi_istatistik.js video_kare.js seo_dil.js admin.html ./
# robots.txt: Node servis eder (GET /robots.txt). Imaja GIRMEZSE uc 404 doner
# ve nginx eski statik dosyaya duser — sessiz ama yanlis davranis olur.
COPY robots.txt ./
# Kitaplık durumu geriye dönük düzeltme aracı (docker exec ... node araclar/...)
COPY araclar/durum_duzelt.js araclar/video_kare_yenile.js araclar/medya_olcu_doldur.js ./araclar/
# dizi.jpg AI bakım araçları: imaja girsin ki her yeniden derlemede
# elle `docker cp` gerekmesin (tohumlama + kare tekrar temizliği).
COPY ai_tohum.js ai_kare_tazele.js ai_yorumlar.json ./
EXPOSE 8500
# D1: giriş noktası kume.js — birincil süreç NODE_ISCI işçi forklar
# (varsayılan min(4, çekirdek)). NODE_ISCI=0 eski tek-süreç davranışına
# döner. exec biçimi ŞART: birincil PID 1 olur ve docker stop'un
# SIGTERM'ini doğrudan alıp işçilere iletir (zarif kapanma zinciri).
CMD ["node", "kume.js"]

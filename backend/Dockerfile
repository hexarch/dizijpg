FROM node:22-alpine
WORKDIR /app
# ffmpeg: video yüklenince ilk kareden küçük resim üretilir (Keşfet
# ızgarası video yerine bu resmi gösterir; onlarca çözücü açılmaz).
# ffmpeg (üstte) + postgresql-client: panelden elle yedek (pg_dump) alınabilsin.
RUN apk add --no-cache ffmpeg postgresql16-client
COPY package.json ./
RUN npm install --omit=dev
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
COPY server.js veri_aktar.js mail_kutu.js emoji.js depolama.js siralama.js dizi_durum.js cevrimici.js kripto.js kisi_izlenme.js yasak.js medya_imza.js arama.js gunluk.js kume.js kume_ipc.js kume_yardimci.js mesaj_sifrele_geri_doldur.js admin.html ./
# robots.txt: Node servis eder (GET /robots.txt). Imaja GIRMEZSE uc 404 doner
# ve nginx eski statik dosyaya duser — sessiz ama yanlis davranis olur.
COPY robots.txt ./
# Kitaplık durumu geriye dönük düzeltme aracı (docker exec ... node araclar/...)
COPY araclar/durum_duzelt.js ./araclar/
# dizi.jpg AI bakım araçları: imaja girsin ki her yeniden derlemede
# elle `docker cp` gerekmesin (tohumlama + kare tekrar temizliği).
COPY ai_tohum.js ai_kare_tazele.js ai_yorumlar.json ./
EXPOSE 8500
# D1: giriş noktası kume.js — birincil süreç NODE_ISCI işçi forklar
# (varsayılan min(4, çekirdek)). NODE_ISCI=0 eski tek-süreç davranışına
# döner. exec biçimi ŞART: birincil PID 1 olur ve docker stop'un
# SIGTERM'ini doğrudan alıp işçilere iletir (zarif kapanma zinciri).
CMD ["node", "kume.js"]

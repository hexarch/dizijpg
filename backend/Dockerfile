FROM node:22-alpine
WORKDIR /app
# ffmpeg: video yüklenince ilk kareden küçük resim üretilir (Keşfet
# ızgarası video yerine bu resmi gösterir; onlarca çözücü açılmaz).
# ffmpeg (üstte) + postgresql-client: panelden elle yedek (pg_dump) alınabilsin.
RUN apk add --no-cache ffmpeg postgresql16-client
COPY package.json ./
RUN npm install --omit=dev
COPY server.js veri_aktar.js mail_kutu.js emoji.js depolama.js admin.html ./
# dizi.jpg AI bakım araçları: imaja girsin ki her yeniden derlemede
# elle `docker cp` gerekmesin (tohumlama + kare tekrar temizliği).
COPY ai_tohum.js ai_kare_tazele.js ai_yorumlar.json ./
EXPOSE 8500
CMD ["node", "server.js"]

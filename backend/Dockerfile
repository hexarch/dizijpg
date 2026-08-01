FROM node:22-alpine
WORKDIR /app
# ffmpeg: video yüklenince ilk kareden küçük resim üretilir (Keşfet
# ızgarası video yerine bu resmi gösterir; onlarca çözücü açılmaz).
RUN apk add --no-cache ffmpeg
COPY package.json ./
RUN npm install --omit=dev
COPY server.js veri_aktar.js admin.html ./
EXPOSE 8500
CMD ["node", "server.js"]

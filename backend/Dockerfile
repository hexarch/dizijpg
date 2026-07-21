FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js veri_aktar.js ./
EXPOSE 8500
CMD ["node", "server.js"]

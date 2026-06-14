FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

FROM node:20-alpine

WORKDIR /usr/src/app

COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/index.js ./index.js
COPY --from=builder /usr/src/app/package.json ./package.json

EXPOSE 8080
ENV PORT=8080
ENV NODE_ENV=production

CMD ["node", "index.js"]

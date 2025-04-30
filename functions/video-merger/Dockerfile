FROM node:22

# 依存関係のみ先にコピーしてキャッシュ
WORKDIR /app
COPY package*.json ./
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libass9 \
    fonts-noto-cjk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN npm install

# 残りのアプリコードをコピー
COPY . .

EXPOSE 8080
CMD ["npm", "start"]

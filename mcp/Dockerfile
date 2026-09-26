# syntax=docker/dockerfile:1
FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY tsconfig.json ./
COPY src ./src

ENV NODE_ENV=production
ENV REDMED_EXEC_MODE=local
ENV REDMED_MCP_HOST=0.0.0.0
ENV REDMED_MCP_PORT=8787

EXPOSE 8787

CMD ["npx", "tsx", "src/http.ts"]

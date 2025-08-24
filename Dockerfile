# Gemini CLI OpenAI Worker - Production Dockerfile

FROM node:20-slim AS base

# Instalar dependencias del sistema mínimas
RUN apt-get update && apt-get install -y wget curl && \
    rm -rf /var/lib/apt/lists/*

# Crear usuario no root
RUN groupadd -g 1001 nodejs && \
    useradd -r -u 1001 -g nodejs worker

WORKDIR /app

# Instalar wrangler global
RUN npm install -g wrangler@latest

# Copiar solo manifests primero
COPY package.json yarn.lock* ./

# Instalar dependencias en modo producción
RUN yarn install --frozen-lockfile --production

# Copiar el resto del código
COPY . .

# Crear directorios para Miniflare/Wrangler
RUN mkdir -p .mf && \
    mkdir -p /home/worker/.config/.wrangler/logs && \
    chown -R worker:nodejs /app /home/worker

USER worker

EXPOSE 8787

# Healthcheck: usar endpoint válido
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8787/v1/models || exit 1

# Ejecutar worker en modo local (persistencia en .mf)
CMD ["wrangler", "dev", "--host", "0.0.0.0", "--port", "8787", "--local", "--persist-to", ".mf"]

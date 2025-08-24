# Gemini CLI OpenAI Worker - Production Dockerfile

FROM node:20-slim

# Paquetes mínimos
RUN apt-get update && apt-get install -y wget curl && \
    rm -rf /var/lib/apt/lists/*

# Usuario no root
RUN groupadd -g 1001 nodejs && useradd -r -u 1001 -g nodejs worker
WORKDIR /app

# Wrangler para ejecutar el Worker en local (Miniflare)
RUN npm install -g wrangler@latest

# ---- Instalar dependencias dentro de la imagen (sin montajes) ----
# Copiar manifests primero para aprovechar cache
COPY package.json yarn.lock* ./
# Producción: instala deps (incluye "hono")
RUN yarn install --frozen-lockfile --production

# Copiar el resto del proyecto
COPY . .

# Directorios de persistencia/logs para Miniflare y permisos
RUN mkdir -p .mf && mkdir -p /home/worker/.config/.wrangler/logs && \
    chown -R worker:nodejs /app /home/worker

USER worker
EXPOSE 8787

# Healthcheck: usar un endpoint existente
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8787/v1/models || exit 1

# Ejecutar el Worker local (sin CF), escuchando en 0.0.0.0:8787
# Persistencia en .mf (NO en node_modules) para evitar EACCES
CMD ["wrangler", "dev", "--host", "0.0.0.0", "--port", "8787", "--local", "--persist-to", ".mf"]

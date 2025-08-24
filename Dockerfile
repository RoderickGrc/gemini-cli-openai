# Gemini CLI OpenAI Worker - Production Dockerfile (fix permisos Miniflare)

FROM node:20-slim

# Paquetes mínimos para healthcheck y utilidades
RUN apt-get update && apt-get install -y wget curl && \
    rm -rf /var/lib/apt/lists/*

# Usuario no root
RUN groupadd -g 1001 nodejs && useradd -r -u 1001 -g nodejs worker
WORKDIR /app

# Wrangler global (ejecutará Miniflare)
RUN npm install -g wrangler@latest

# Copiar manifests primero (cache de layers)
COPY package.json yarn.lock* ./

# Instalar deps de producción (incluye hono)
RUN yarn install --frozen-lockfile --production

# Copiar el resto del proyecto
COPY . .

# --- Preparar almacenamiento para Miniflare y permisos ---
# 1) Directorio de estado FUERA de node_modules (preferido)
RUN mkdir -p /app/.mf \
 && mkdir -p /home/worker/.config/.wrangler/logs \
 # 2) Crear también node_modules/.mf por si Miniflare lo intenta usar
 && mkdir -p /app/node_modules/.mf \
 # 3) Dar ownership al usuario no root y permisos de escritura
 && chown -R worker:nodejs /app /home/worker \
 && chmod -R 775 /app/.mf /app/node_modules/.mf

# Opcional: indicar explícitamente a Miniflare dónde persistir y dónde poner su "home"
ENV MINIFLARE_PERSIST=/app/.mf
ENV MINIFLARE_HOME=/app/.mf
# Reducir ruidos de telemetría
ENV WRANGLER_SEND_METRICS=false

USER worker
EXPOSE 8787

# Healthcheck: usar un endpoint existente
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8787/v1/models || exit 1

# Ejecutar el Worker local, escuchando en 0.0.0.0:8787
# Persistencia en /app/.mf (coincide con MINIFLARE_PERSIST/MINIFLARE_HOME)
CMD ["wrangler", "dev", "--host", "0.0.0.0", "--port", "8787", "--local", "--persist-to", "/app/.mf"]

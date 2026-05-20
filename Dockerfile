# OpenWA - Dockerfile
# Optimized for Render + NestJS + Chromium

# ===== Stage 1: Builder =====
FROM node:22-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

# IMPORTANT:
# Include devDependencies for NestJS build
RUN npm ci --include=dev

# Copy source code
COPY . .

# Build application
RUN npm run build

# Debug build output
RUN ls -R /app/dist

# ===== Stage 2: Production =====
FROM node:22-slim AS production

# Install Chromium + dependencies
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Puppeteer / Chromium config
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROME_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Production mode
ENV NODE_ENV=production

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev && npm cache clean --force

# Copy built app from builder
COPY --from=builder /app/dist ./dist

# Create required directories
# RUN mkdir -p ./data/sessions ./data/media
RUN mkdir -p /app/data/sessions /app/data/media && \
    echo "DATABASE_TYPE=postgres" > /app/data/.env.generated && \
    echo "DATABASE_HOST=rivescb.us-east.db.rivestack.io" >> /app/data/.env.generated && \
    echo "DATABASE_PORT=5432" >> /app/data/.env.generated && \
    echo "DATABASE_NAME=rv_khghvr6v" >> /app/data/.env.generated && \
    echo "DATABASE_USERNAME=rv_khghvr6v" >> /app/data/.env.generated

# Verify build exists
RUN ls -R /app/dist

# Expose app port
EXPOSE 2785

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD node -e "require('http').get('http://localhost:2785/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Proper signal handling
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "--max-old-space-size=350", "dist/main.js"]

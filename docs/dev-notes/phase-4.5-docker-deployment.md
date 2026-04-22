# Phase 4.5 — Docker & Deployment

> **Goal:** Containerize all three Crelyzor repos and deploy the full stack to a single VM (EC2 or GCE).
> One machine. One `docker compose up`. Everything running.

---

## What we're building

```
VM (Linux)
│
├── Nginx  ← reverse proxy + SSL termination
│   ├── app.crelyzor.com   → frontend  (:5173)
│   ├── crelyzor.com       → public    (:5174)
│   └── api.crelyzor.com   → backend   (:3000)
│
├── Docker Compose
│   ├── crelyzor-backend   (API server)
│   ├── crelyzor-worker    (Bull job worker — always-on)
│   ├── crelyzor-frontend  (Vite static files via nginx)
│   ├── crelyzor-public    (Next.js SSR)
│   └── postgres           (database)
│
├── Upstash Redis          (keep external — already configured)
└── GCS                    (keep external — already configured)
```

Deploy workflow once set up:
```bash
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

---

## Prerequisites — learn Docker first

Before building any of this, get comfortable with Docker basics.
Estimated time: 2–3 hours of hands-on work.

**Resource:** https://docs.docker.com/get-started (official, genuinely good)

### What to understand before starting

- [ ] **Image vs Container** — image is the blueprint, container is the running instance
- [ ] **Dockerfile** — how to write build instructions for an image
- [ ] **`docker build` + `docker run`** — build an image, run a container from it
- [ ] **Volumes** — how containers persist data (important for Postgres)
- [ ] **Networks** — how containers talk to each other (by service name, not localhost)
- [ ] **Docker Compose** — defining and running multi-container apps with one YAML file
- [ ] **`docker compose up/down/logs`** — the three commands you'll use daily

**Practice task before moving on:**
Write a Dockerfile for `crelyzor-backend`, build it, and run it locally with `docker run`.
If the API responds on port 3000, you're ready.

---

## P0 — Dockerfiles

One Dockerfile per repo. All use multi-stage builds (small final image).

### `crelyzor-backend/Dockerfile`

```dockerfile
# Stage 1 — install deps + build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# Stage 2 — production image
FROM node:20-alpine AS runner
WORKDIR /app
RUN npm install -g pnpm
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma
EXPOSE 3000
CMD ["pnpm", "start"]
```

Two commands come from this one image:
- API server: `CMD ["pnpm", "start"]`
- Worker: override with `command: pnpm start:worker` in Compose

### `crelyzor-frontend/Dockerfile`

Vite builds to static files — served by Nginx inside the container.

```dockerfile
# Stage 1 — build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile
COPY . .
ARG VITE_API_BASE_URL
ARG VITE_CARDS_PUBLIC_URL
RUN pnpm build

# Stage 2 — serve with nginx
FROM nginx:alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.static.conf /etc/nginx/conf.d/default.conf
EXPOSE 5173
```

Note: `VITE_*` env vars are baked in at **build time** (Vite requirement). They're passed as build args.

### `crelyzor-public/Dockerfile`

Next.js runs as a server — no static serving needed.

```dockerfile
# Stage 1 — build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile
COPY . .
ARG NEXT_PUBLIC_API_BASE_URL
ARG NEXT_PUBLIC_APP_URL
ARG NEXT_PUBLIC_BASE_URL
RUN pnpm build

# Stage 2 — run
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN npm install -g pnpm
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/public ./public
EXPOSE 5174
CMD ["pnpm", "start"]
```

---

## P1 — Docker Compose (prod)

File: `docker-compose.prod.yml` at workspace root.

```yaml
services:

  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_DB: crelyzor
      POSTGRES_USER: crelyzor
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - internal

  backend:
    build:
      context: ./crelyzor-backend
    restart: always
    env_file: ./crelyzor-backend/.env.prod
    depends_on:
      - postgres
    networks:
      - internal
    expose:
      - "3000"

  worker:
    build:
      context: ./crelyzor-backend
    command: pnpm start:worker
    restart: always
    env_file: ./crelyzor-backend/.env.prod
    depends_on:
      - postgres
    networks:
      - internal

  frontend:
    build:
      context: ./crelyzor-frontend
      args:
        VITE_API_BASE_URL: ${VITE_API_BASE_URL}
        VITE_CARDS_PUBLIC_URL: ${VITE_CARDS_PUBLIC_URL}
    restart: always
    networks:
      - internal
    expose:
      - "5173"

  public:
    build:
      context: ./crelyzor-public
      args:
        NEXT_PUBLIC_API_BASE_URL: ${NEXT_PUBLIC_API_BASE_URL}
        NEXT_PUBLIC_APP_URL: ${NEXT_PUBLIC_APP_URL}
        NEXT_PUBLIC_BASE_URL: ${NEXT_PUBLIC_BASE_URL}
    restart: always
    networks:
      - internal
    expose:
      - "5174"

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro   # SSL certs from Certbot
    depends_on:
      - backend
      - frontend
      - public
    networks:
      - internal

volumes:
  postgres_data:

networks:
  internal:
    driver: bridge
```

Key points:
- Postgres data survives container restarts via the `postgres_data` volume
- No ports exposed on backend/frontend/public — only Nginx is public-facing (80 + 443)
- All containers on the same `internal` network — they reach each other by service name

---

## P2 — Nginx Config

File: `nginx/nginx.conf` at workspace root.

```nginx
events {}

http {

  upstream backend  { server backend:3000; }
  upstream frontend { server frontend:5173; }
  upstream public   { server public:5174; }

  # Redirect all HTTP → HTTPS
  server {
    listen 80;
    server_name app.crelyzor.com api.crelyzor.com crelyzor.com www.crelyzor.com;
    return 301 https://$host$request_uri;
  }

  # Dashboard — app.crelyzor.com
  server {
    listen 443 ssl;
    server_name app.crelyzor.com;

    ssl_certificate     /etc/letsencrypt/live/app.crelyzor.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.crelyzor.com/privkey.pem;

    location / {
      proxy_pass http://frontend;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
    }
  }

  # API — api.crelyzor.com
  server {
    listen 443 ssl;
    server_name api.crelyzor.com;

    ssl_certificate     /etc/letsencrypt/live/api.crelyzor.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.crelyzor.com/privkey.pem;

    client_max_body_size 500M;  # allow large recording uploads

    location / {
      proxy_pass http://backend;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;

      # SSE support (Ask AI streaming)
      proxy_buffering off;
      proxy_cache off;
      proxy_read_timeout 300s;
    }
  }

  # Public site — crelyzor.com
  server {
    listen 443 ssl;
    server_name crelyzor.com www.crelyzor.com;

    ssl_certificate     /etc/letsencrypt/live/crelyzor.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/crelyzor.com/privkey.pem;

    location / {
      proxy_pass http://public;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
    }
  }

}
```

---

## P3 — Environment Files

### `crelyzor-backend/.env.prod`

```bash
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://crelyzor:${POSTGRES_PASSWORD}@postgres:5432/crelyzor
BASE_URL_SHORTNER=https://api.crelyzor.com
ALLOWED_ORIGINS=https://app.crelyzor.com,https://crelyzor.com

# Auth
JWT_ACCESS_SECRET=<generate with: openssl rand -hex 64>
JWT_REFRESH_SECRET=<generate with: openssl rand -hex 64>

# Google OAuth
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GOOGLE_LOGIN_REDIRECT_URI=https://api.crelyzor.com/api/v1/auth/google/callback

# AI & Transcription
OPENAI_API_KEY=
DEEPGRAM_API_KEY=

# Storage
GCS_BUCKET_NAME=
GOOGLE_APPLICATION_CREDENTIALS=/app/gcs-key.json

# Redis (Upstash — keep external)
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=

# GCal Webhooks
GOOGLE_WEBHOOK_BASE_URL=https://api.crelyzor.com
GCAL_WEBHOOK_SECRET=<generate with: openssl rand -hex 32>

# Email
RESEND_API_KEY=
RESEND_FROM_EMAIL=Crelyzor <notifications@crelyzor.com>

# Recall.ai (optional)
RECALL_API_KEY=
RECALL_WEBHOOK_SECRET=
RECALL_BASE_URL=
```

### `.env` at workspace root (Compose vars)

```bash
POSTGRES_PASSWORD=<strong password>

VITE_API_BASE_URL=https://api.crelyzor.com/api
VITE_CARDS_PUBLIC_URL=https://crelyzor.com

NEXT_PUBLIC_API_BASE_URL=https://api.crelyzor.com/api/v1
NEXT_PUBLIC_APP_URL=https://app.crelyzor.com
NEXT_PUBLIC_BASE_URL=https://crelyzor.com
```

---

## P4 — VM Setup (one-time)

### Pick your machine

| Provider | Size | RAM | Cost |
|---|---|---|---|
| AWS EC2 | t3.small | 2GB | ~$17/mo |
| AWS EC2 | t3.medium | 4GB | ~$33/mo |
| GCE | e2-medium | 4GB | ~$27/mo |

Start with t3.small. Upgrade if needed — takes 2 minutes.

### First-time setup script

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 3. Install Docker Compose plugin
sudo apt install docker-compose-plugin -y

# 4. Install Certbot
sudo apt install certbot -y

# 5. Clone the repo
git clone https://github.com/your-org/crelyzor-workspace.git /app
cd /app

# 6. Copy env files (you do this manually)
# scp .env.prod ubuntu@your-server-ip:/app/crelyzor-backend/.env.prod
# scp gcs-key.json ubuntu@your-server-ip:/app/crelyzor-backend/gcs-key.json
# scp .env ubuntu@your-server-ip:/app/.env

# 7. Point your domains to the server IP in your DNS provider first, then:
sudo certbot certonly --standalone \
  -d api.crelyzor.com \
  -d app.crelyzor.com \
  -d crelyzor.com \
  -d www.crelyzor.com

# 8. Run database migrations
docker compose -f docker-compose.prod.yml run --rm backend pnpm db:migrate

# 9. Start everything
docker compose -f docker-compose.prod.yml up -d --build
```

---

## P5 — Deploy Script

File: `deploy.sh` at workspace root.

```bash
#!/bin/bash
set -e

echo "Pulling latest code..."
git pull origin main

echo "Building and restarting containers..."
docker compose -f docker-compose.prod.yml up -d --build

echo "Cleaning up old images..."
docker image prune -f

echo "Done. Checking status..."
docker compose -f docker-compose.prod.yml ps
```

Make it executable: `chmod +x deploy.sh`

Every deploy from here: `./deploy.sh`

---

## P6 — DNS Setup

In your domain registrar (or Cloudflare), add these A records pointing to your server IP:

```
api.crelyzor.com   → your.server.ip
app.crelyzor.com   → your.server.ip
crelyzor.com       → your.server.ip
www.crelyzor.com   → your.server.ip
```

DNS propagation takes 5-30 minutes.

---

## Google OAuth — add prod callback

In Google Cloud Console → APIs & Services → Credentials → your OAuth client:

```
Authorized redirect URIs:
  http://localhost:3000/api/v1/auth/google/callback   ← keep for local dev
  https://api.crelyzor.com/api/v1/auth/google/callback  ← add this
```

---

## Checklist — ready to go live

- [ ] Docker basics understood (images, containers, Compose)
- [ ] Dockerfile written and tested for each repo
- [ ] `docker-compose.prod.yml` built and tested locally
- [ ] VM provisioned (EC2 or GCE), SSH access confirmed
- [ ] DNS records pointing to server IP
- [ ] `.env.prod` filled with all real values
- [ ] GCS service account key on server
- [ ] SSL certs issued via Certbot
- [ ] DB migrations run
- [ ] All services up: `docker compose ps` shows everything healthy
- [ ] Google OAuth callback URL updated in Google Console
- [ ] Test: sign in, create a meeting, upload a recording end-to-end

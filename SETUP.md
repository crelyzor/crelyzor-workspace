# Crelyzor — First Time Setup

Get from zero to running in ~10 minutes.

---

## Prerequisites

Install these once:

| Tool | Install |
|------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Required — runs everything |
| [Git](https://git-scm.com) | Required — clone repos |

That's it. No Node, no pnpm, no local Postgres needed.

---

## Step 1 — Clone the Repos

Clone the workspace first, then the 3 code repos inside it:

```bash
git clone https://github.com/crelyzor/crelyzor-workspace.git
cd crelyzor-workspace

git clone https://github.com/crelyzor/crelyzor-backend.git
git clone https://github.com/crelyzor/crelyzor-frontend.git
git clone https://github.com/crelyzor/crelyzor-public.git
```

Your folder should look like this:

```
crelyzor-workspace/
├── crelyzor-backend/
├── crelyzor-frontend/
├── crelyzor-public/
├── docker-compose.yml
├── SETUP.md
└── ...
```

---

## Step 2 — Environment Files

Copy the env templates and fill in your API keys:

```bash
# Backend
cp crelyzor-backend/.env.example crelyzor-backend/.env.local
```

Open `crelyzor-backend/.env.local` and fill in the keys marked `CHANGE_ME`.
The minimum you need to get the app running:

```bash
JWT_ACCESS_SECRET=any_random_string_here
JWT_REFRESH_SECRET=another_random_string_here
GOOGLE_CLIENT_ID=          # from Google Cloud Console
GOOGLE_CLIENT_SECRET=      # from Google Cloud Console
OPENAI_API_KEY=            # from platform.openai.com
DEEPGRAM_API_KEY=          # from console.deepgram.com
GCS_BUCKET_NAME=           # Google Cloud Storage bucket
UPSTASH_REDIS_REST_URL=    # from upstash.com
UPSTASH_REDIS_REST_TOKEN=  # from upstash.com
```

The `DATABASE_URL` is already set — it points to the local Docker Postgres. Don't change it.

Frontend env files are already configured for local dev. No changes needed.

---

## Step 3 — Start Docker Desktop

Open Docker Desktop and wait for it to say "Docker Desktop is running".

---

## Step 4 — Run

```bash
docker compose up
```

First run takes ~3-5 minutes (downloading images, installing deps). Subsequent runs are fast.

---

## Step 5 — Run Migrations (first time only)

In a new terminal, while the containers are running:

```bash
docker compose exec backend pnpm db:migrate
```

---

## Done

| Service | URL |
|---------|-----|
| Backend API | http://localhost:3000 |
| Dashboard | http://localhost:5173 |
| Public site | http://localhost:5174 |

Go to http://localhost:5173 and sign in with Google.

---

## Daily Use

```bash
docker compose up          # start everything
docker compose down        # stop (data is preserved)
docker compose down -v     # stop + wipe database
```

Hot reload is enabled — save a file, the change is live instantly.

---

## Troubleshooting

**Port already in use:**
```bash
docker compose down        # make sure nothing else is running
```

**Database out of sync after pulling new code:**
```bash
docker compose exec backend pnpm db:migrate
```

**Containers won't start / weird errors:**
```bash
docker compose down -v     # wipe everything
docker compose up --build  # rebuild from scratch
```

**Want to browse the database visually:**
```bash
docker compose exec backend pnpm db:studio
# Opens Prisma Studio at http://localhost:5555
```

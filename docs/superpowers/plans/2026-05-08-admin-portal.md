# Admin Portal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone `crelyzor-admin` React app with its own Docker Compose profile and backend route group so founders can manage user plans, view usage, and see platform stats without touching Prisma Studio.

**Architecture:** New `crelyzor-admin` repo (React + Vite + Tailwind v4 + shadcn/ui, port 5175) talks to a new `/api/v1/admin/*` route group on `crelyzor-backend`, protected by a `verifyAdmin` middleware that validates credentials from env vars rather than the user account system. The service is added to `docker-compose.local.yml` behind a Docker Compose profile so `make local-up` never starts it — only `make admin-up` does.

**Tech Stack:** Express 5, Prisma 6, jsonwebtoken, Zod (backend) | React 19, Vite, TanStack Query v5, React Router v7, Tailwind v4, shadcn/ui, Axios, Sonner (frontend)

**Spec:** `docs/superpowers/specs/2026-05-08-admin-portal-design.md`

---

## Phase 1 — Backend

### Task 1: Add admin env vars

**Files:**
- Modify: `crelyzor-backend/.env.example`
- Modify: `crelyzor-backend/.env.local`

- [ ] **Step 1: Add to `.env.example`**

Add these three lines after the `JWT_REFRESH_SECRET` line:

```bash
# Admin Portal
ADMIN_EMAIL=""                         # Email to log in to the admin portal
ADMIN_PASSWORD=""                      # Password to log in to the admin portal
ADMIN_JWT_SECRET=""                    # Random secret for signing admin JWTs (generate with: openssl rand -hex 32)
```

- [ ] **Step 2: Fill values in `.env.local`**

```bash
ADMIN_EMAIL="harsh@crelyzor.com"
ADMIN_PASSWORD="<choose a strong password>"
ADMIN_JWT_SECRET="<run: openssl rand -hex 32 and paste result>"
```

- [ ] **Step 3: Commit**

```bash
git -C crelyzor-backend add .env.example
git -C crelyzor-backend commit -m "chore: add admin portal env vars to .env.example"
```

---

### Task 2: Create `verifyAdmin` middleware

**Files:**
- Create: `crelyzor-backend/src/middleware/verifyAdmin.ts`

- [ ] **Step 1: Create the file**

```typescript
import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { AppError } from "../utils/errors/AppError";
import { logger } from "../utils/logging/logger";
import {
  globalErrorHandler,
  BaseError,
} from "../utils/globalErrorHandler";

interface AdminTokenPayload {
  role: string;
  email: string;
}

export const verifyAdmin = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      throw new AppError("Admin token required", 401);
    }

    const token = authHeader.substring(7);
    const secret = process.env.ADMIN_JWT_SECRET;

    if (!secret) {
      logger.error("ADMIN_JWT_SECRET is not set");
      throw new AppError("Admin portal not configured", 500);
    }

    const decoded = jwt.verify(token, secret) as AdminTokenPayload;

    if (decoded.role !== "admin") {
      throw new AppError("Insufficient permissions", 403);
    }

    next();
  } catch (error) {
    if (
      error instanceof Error &&
      (error.name === "TokenExpiredError" ||
        error.name === "JsonWebTokenError")
    ) {
      return globalErrorHandler(
        new AppError("Invalid or expired admin token", 401) as BaseError,
        req,
        res,
      );
    }
    globalErrorHandler(error as BaseError, req, res);
  }
};
```

- [ ] **Step 2: Commit**

```bash
git -C crelyzor-backend add src/middleware/verifyAdmin.ts
git -C crelyzor-backend commit -m "feat(admin): add verifyAdmin middleware"
```

---

### Task 3: Create `adminService.ts`

**Files:**
- Create: `crelyzor-backend/src/services/adminService.ts`

- [ ] **Step 1: Create the file**

```typescript
import jwt from "jsonwebtoken";
import prisma from "../db/prismaClient";
import { AppError } from "../utils/errors/AppError";
import { logger } from "../utils/logging/logger";
import { getLimitsForPlan } from "./billing/usageService";
import type { Plan } from "@prisma/client";

// ─── Auth ────────────────────────────────────────────────────────────────────

export async function adminLogin(
  email: string,
  password: string,
): Promise<string> {
  const adminEmail = process.env.ADMIN_EMAIL;
  const adminPassword = process.env.ADMIN_PASSWORD;
  const adminJwtSecret = process.env.ADMIN_JWT_SECRET;

  if (!adminEmail || !adminPassword || !adminJwtSecret) {
    logger.error("Admin credentials env vars are not set");
    throw new AppError("Admin portal not configured", 500);
  }

  if (email !== adminEmail || password !== adminPassword) {
    throw new AppError("Invalid credentials", 401);
  }

  return jwt.sign({ role: "admin", email }, adminJwtSecret, {
    expiresIn: "24h",
  });
}

// ─── Users ───────────────────────────────────────────────────────────────────

export async function listUsers(
  page: number = 1,
  limit: number = 20,
  search?: string,
) {
  const skip = (page - 1) * limit;
  const where = search
    ? {
        OR: [
          { name: { contains: search, mode: "insensitive" as const } },
          { email: { contains: search, mode: "insensitive" as const } },
        ],
        isDeleted: false,
      }
    : { isDeleted: false };

  const [users, total] = await prisma.$transaction([
    prisma.user.findMany({
      where,
      skip,
      take: limit,
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        name: true,
        email: true,
        plan: true,
        createdAt: true,
        usage: {
          select: {
            transcriptionMinutesUsed: true,
            recallHoursUsed: true,
            aiCreditsUsed: true,
            storageGbUsed: true,
            resetAt: true,
          },
        },
      },
    }),
    prisma.user.count({ where }),
  ]);

  return {
    users,
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit),
  };
}

export async function getUserDetail(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId, isDeleted: false },
    select: {
      id: true,
      name: true,
      email: true,
      plan: true,
      createdAt: true,
      updatedAt: true,
      username: true,
      usage: true,
    },
  });

  if (!user) throw new AppError("User not found", 404);

  const limits = getLimitsForPlan(user.plan);
  return { user, limits };
}

export async function updateUserPlan(userId: string, plan: Plan) {
  const user = await prisma.user.findUnique({
    where: { id: userId, isDeleted: false },
    select: { id: true },
  });

  if (!user) throw new AppError("User not found", 404);

  const updated = await prisma.user.update({
    where: { id: userId },
    data: { plan },
    select: { id: true, email: true, plan: true },
  });

  logger.info("Admin updated user plan", { userId, plan });
  return updated;
}

export async function resetUserUsage(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId, isDeleted: false },
    select: { id: true },
  });

  if (!user) throw new AppError("User not found", 404);

  const nextMonthStart = new Date();
  nextMonthStart.setMonth(nextMonthStart.getMonth() + 1);
  nextMonthStart.setDate(1);
  nextMonthStart.setHours(0, 0, 0, 0);

  const usage = await prisma.userUsage.upsert({
    where: { userId },
    update: {
      transcriptionMinutesUsed: 0,
      recallHoursUsed: 0,
      aiCreditsUsed: 0,
      storageGbUsed: 0,
      periodStart: new Date(),
      resetAt: nextMonthStart,
    },
    create: {
      userId,
      transcriptionMinutesUsed: 0,
      recallHoursUsed: 0,
      aiCreditsUsed: 0,
      storageGbUsed: 0,
      periodStart: new Date(),
      resetAt: nextMonthStart,
    },
  });

  logger.info("Admin reset user usage", { userId });
  return usage;
}

// ─── Stats ───────────────────────────────────────────────────────────────────

export async function getPlatformStats() {
  const [totalUsers, planBreakdown, usageTotals] = await Promise.all([
    prisma.user.count({ where: { isDeleted: false } }),
    prisma.user.groupBy({
      by: ["plan"],
      where: { isDeleted: false },
      _count: { id: true },
    }),
    prisma.userUsage.aggregate({
      _sum: {
        transcriptionMinutesUsed: true,
        recallHoursUsed: true,
        aiCreditsUsed: true,
        storageGbUsed: true,
      },
    }),
  ]);

  const planCounts = { FREE: 0, PRO: 0, BUSINESS: 0 };
  for (const row of planBreakdown) {
    planCounts[row.plan] = row._count.id;
  }

  return {
    totalUsers,
    planCounts,
    usageTotals: {
      transcriptionMinutes: usageTotals._sum.transcriptionMinutesUsed ?? 0,
      recallHours: usageTotals._sum.recallHoursUsed ?? 0,
      aiCredits: usageTotals._sum.aiCreditsUsed ?? 0,
      storageGb: usageTotals._sum.storageGbUsed ?? 0,
    },
  };
}
```

- [ ] **Step 2: Commit**

```bash
git -C crelyzor-backend add src/services/adminService.ts
git -C crelyzor-backend commit -m "feat(admin): add adminService with user management and stats"
```

---

### Task 4: Create `adminSchema.ts`

**Files:**
- Create: `crelyzor-backend/src/validators/adminSchema.ts`

- [ ] **Step 1: Create the file**

```typescript
import { z } from "zod";

export const adminLoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const adminListUsersSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional(),
});

export const adminUpdatePlanSchema = z.object({
  plan: z.enum(["FREE", "PRO", "BUSINESS"]),
});
```

- [ ] **Step 2: Commit**

```bash
git -C crelyzor-backend add src/validators/adminSchema.ts
git -C crelyzor-backend commit -m "feat(admin): add admin Zod schemas"
```

---

### Task 5: Create `adminController.ts`

**Files:**
- Create: `crelyzor-backend/src/controllers/adminController.ts`

- [ ] **Step 1: Create the file**

```typescript
import type { Request, Response } from "express";
import { AppError } from "../utils/errors/AppError";
import { apiResponse } from "../utils/globalResponseHandler";
import {
  adminLoginSchema,
  adminListUsersSchema,
  adminUpdatePlanSchema,
} from "../validators/adminSchema";
import {
  adminLogin,
  listUsers,
  getUserDetail,
  updateUserPlan,
  resetUserUsage,
  getPlatformStats,
} from "../services/adminService";

export const login = async (req: Request, res: Response) => {
  const parsed = adminLoginSchema.safeParse(req.body);
  if (!parsed.success) throw new AppError("Invalid credentials format", 400);

  const token = await adminLogin(parsed.data.email, parsed.data.password);
  return apiResponse(res, {
    statusCode: 200,
    message: "Admin login successful",
    data: { token },
  });
};

export const getUsers = async (req: Request, res: Response) => {
  const parsed = adminListUsersSchema.safeParse(req.query);
  if (!parsed.success) throw new AppError("Invalid query params", 400);

  const result = await listUsers(
    parsed.data.page,
    parsed.data.limit,
    parsed.data.search,
  );
  return apiResponse(res, {
    statusCode: 200,
    message: "Users fetched",
    data: result,
  });
};

export const getUser = async (req: Request, res: Response) => {
  const { id } = req.params;
  const result = await getUserDetail(id);
  return apiResponse(res, {
    statusCode: 200,
    message: "User fetched",
    data: result,
  });
};

export const updatePlan = async (req: Request, res: Response) => {
  const { id } = req.params;
  const parsed = adminUpdatePlanSchema.safeParse(req.body);
  if (!parsed.success) throw new AppError("Invalid plan value", 400);

  const updated = await updateUserPlan(id, parsed.data.plan);
  return apiResponse(res, {
    statusCode: 200,
    message: "User plan updated",
    data: updated,
  });
};

export const resetUsage = async (req: Request, res: Response) => {
  const { id } = req.params;
  const usage = await resetUserUsage(id);
  return apiResponse(res, {
    statusCode: 200,
    message: "User usage reset",
    data: usage,
  });
};

export const getStats = async (req: Request, res: Response) => {
  const stats = await getPlatformStats();
  return apiResponse(res, {
    statusCode: 200,
    message: "Platform stats fetched",
    data: stats,
  });
};
```

- [ ] **Step 2: Commit**

```bash
git -C crelyzor-backend add src/controllers/adminController.ts
git -C crelyzor-backend commit -m "feat(admin): add adminController"
```

---

### Task 6: Create `adminRoutes.ts` and wire into `indexRouter.ts`

**Files:**
- Create: `crelyzor-backend/src/routes/adminRoutes.ts`
- Modify: `crelyzor-backend/src/routes/indexRouter.ts`

- [ ] **Step 1: Create `adminRoutes.ts`**

```typescript
import { Router } from "express";
import { verifyAdmin } from "../middleware/verifyAdmin";
import {
  login,
  getUsers,
  getUser,
  updatePlan,
  resetUsage,
  getStats,
} from "../controllers/adminController";

const adminRouter = Router();

// Public — no verifyAdmin (this is how you get the token)
adminRouter.post("/auth/login", login);

// All routes below require a valid admin JWT
adminRouter.use(verifyAdmin);

adminRouter.get("/stats", getStats);
adminRouter.get("/users", getUsers);
adminRouter.get("/users/:id", getUser);
adminRouter.patch("/users/:id/plan", updatePlan);
adminRouter.patch("/users/:id/usage/reset", resetUsage);

export default adminRouter;
```

- [ ] **Step 2: Add to `indexRouter.ts`**

Add this import at the top with the other imports:

```typescript
import adminRouter from "./adminRoutes";
```

Add this block after the SEARCH ROUTES section:

```typescript
// ========================================
// 🔐 ADMIN ROUTES (founder/ops only)
// ========================================
indexRouter.use("/admin", adminRouter);
```

- [ ] **Step 3: Commit**

```bash
git -C crelyzor-backend add src/routes/adminRoutes.ts src/routes/indexRouter.ts
git -C crelyzor-backend commit -m "feat(admin): add admin route group at /api/v1/admin"
```

---

### Task 7: Smoke test the backend

- [ ] **Step 1: Start backend (if not running)**

```bash
make local-up
```

- [ ] **Step 2: Test login endpoint**

```bash
curl -s -X POST http://localhost:4000/api/v1/admin/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"harsh@crelyzor.com","password":"<your-password>"}' | jq .
```

Expected output:
```json
{
  "status": "success",
  "statusCode": 200,
  "message": "Admin login successful",
  "data": { "token": "<jwt-string>" }
}
```

- [ ] **Step 3: Test stats endpoint with token**

Copy the token from above and run:

```bash
TOKEN="<paste-token-here>"

curl -s http://localhost:4000/api/v1/admin/stats \
  -H "Authorization: Bearer $TOKEN" | jq .
```

Expected: `{ "status": "success", "data": { "totalUsers": ..., "planCounts": {...}, ... } }`

- [ ] **Step 4: Test auth guard (no token)**

```bash
curl -s http://localhost:4000/api/v1/admin/users | jq .
```

Expected: `{ "statusCode": 401, ... }`

---

## Phase 2 — Infrastructure

### Task 8: Docker Compose profile + Makefile

**Files:**
- Modify: `docker-compose.local.yml`
- Modify: `Makefile`

- [ ] **Step 1: Add admin service to `docker-compose.local.yml`**

Add this block before the `volumes:` section at the bottom of the file:

```yaml
  # ── Admin Portal ──────────────────────────────────────────────────────────────
  admin:
    profiles: ["admin"]
    build:
      context: ./crelyzor-admin
      target: deps
    command: pnpm dev --host 0.0.0.0
    restart: unless-stopped
    env_file: ./crelyzor-admin/.env.local
    ports:
      - "5175:5175"
    volumes:
      - ./crelyzor-admin:/app
      - /app/node_modules
```

- [ ] **Step 2: Add Makefile targets**

Add these targets after `local-logs-public:` and before the `# ── Database` section:

```makefile
local-logs-admin:
	docker compose -f docker-compose.local.yml --env-file .env.local --profile admin logs -f admin

# ── Admin ─────────────────────────────────────────────────────────────────────

admin-up:
	docker compose -f docker-compose.local.yml --env-file .env.local --profile admin up -d

admin-down:
	docker compose -f docker-compose.local.yml --env-file .env.local --profile admin down

admin-logs:
	docker compose -f docker-compose.local.yml --env-file .env.local --profile admin logs -f admin
```

- [ ] **Step 3: Commit**

```bash
git add docker-compose.local.yml Makefile
git commit -m "feat(admin): add Docker Compose profile and Makefile targets for admin portal"
```

---

### Task 9: Create `crelyzor-admin` Dockerfile

**Files:**
- Create: `crelyzor-admin/Dockerfile`

This task assumes the `crelyzor-admin` directory already exists (it gets created in Task 10). Do Task 10 first if running sequentially.

- [ ] **Step 1: Create the Dockerfile**

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
RUN npm install -g pnpm
COPY package.json pnpm-lock.yaml ./
RUN pnpm install

FROM deps AS build
COPY . .
RUN pnpm build

FROM nginx:alpine AS production
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 5175
```

- [ ] **Step 2: Create `nginx.conf` for SPA routing**

```nginx
server {
  listen 5175;
  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }
}
```

- [ ] **Step 3: Commit (after Task 10 creates the repo)**

```bash
git -C crelyzor-admin add Dockerfile nginx.conf
git -C crelyzor-admin commit -m "chore: add Dockerfile for admin portal"
```

---

## Phase 3 — Admin Frontend

### Task 10: Scaffold `crelyzor-admin` repo

**Files:**
- Create: `crelyzor-admin/` (entire repo)

- [ ] **Step 1: Scaffold Vite + React + TypeScript**

Run from the workspace root (`/path/to/crelyzor-workspace/`):

```bash
pnpm create vite crelyzor-admin --template react-ts
cd crelyzor-admin
```

- [ ] **Step 2: Install dependencies**

```bash
pnpm add @tanstack/react-query@^5.90.20 react-router-dom@^7.5.0 axios sonner@^2.0.7 lucide-react tailwind-merge@^3.2.0
pnpm add -D tailwindcss@^4.1.3 @tailwindcss/vite@^4.2.4 @tanstack/react-query-devtools@^5.91.3
```

- [ ] **Step 3: Configure Vite (`vite.config.ts`)**

Replace the entire file with:

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
  server: {
    port: 5175,
    host: true,
  },
});
```

- [ ] **Step 4: Configure TypeScript paths (`tsconfig.json`)**

Add `"paths"` to the `compilerOptions`:

```json
{
  "compilerOptions": {
    "paths": { "@/*": ["./src/*"] }
  }
}
```

- [ ] **Step 5: Set up Tailwind v4 CSS (`src/index.css`)**

Replace the entire file with:

```css
@import "tailwindcss";
```

- [ ] **Step 6: Set up shadcn/ui**

```bash
pnpm dlx shadcn@latest init
```

When prompted: choose `Default` style, `Zinc` base color, use CSS variables — yes.

Then add the components needed:

```bash
pnpm dlx shadcn@latest add button input label badge table card separator avatar dialog
```

- [ ] **Step 7: Create `.env.local`**

```bash
VITE_API_URL=http://localhost:4000/api/v1
```

- [ ] **Step 8: Create `.gitignore`**

```
node_modules
dist
.env.local
.env
```

- [ ] **Step 9: Initialize git and commit**

```bash
git init
git add .
git commit -m "chore: scaffold crelyzor-admin with Vite + React + Tailwind v4 + shadcn/ui"
```

---

### Task 11: Create `apiClient.ts` and `queryKeys.ts`

**Files:**
- Create: `crelyzor-admin/src/lib/apiClient.ts`
- Create: `crelyzor-admin/src/lib/queryKeys.ts`

- [ ] **Step 1: Create `apiClient.ts`**

```typescript
import axios from "axios";

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: { "Content-Type": "application/json" },
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem("admin_token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("admin_token");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  },
);

export default apiClient;
```

- [ ] **Step 2: Create `queryKeys.ts`**

```typescript
export const queryKeys = {
  stats: () => ["admin", "stats"] as const,
  users: {
    list: (page: number, search?: string) =>
      ["admin", "users", { page, search }] as const,
    detail: (id: string) => ["admin", "users", id] as const,
  },
};
```

- [ ] **Step 3: Commit**

```bash
git add src/lib/
git commit -m "feat(admin): add apiClient with token interceptor and queryKeys"
```

---

### Task 12: Create `adminService.ts` (frontend)

**Files:**
- Create: `crelyzor-admin/src/services/adminService.ts`

- [ ] **Step 1: Create the file**

```typescript
import apiClient from "@/lib/apiClient";

export type Plan = "FREE" | "PRO" | "BUSINESS";

export interface UserUsage {
  transcriptionMinutesUsed: number;
  recallHoursUsed: number;
  aiCreditsUsed: number;
  storageGbUsed: number;
  resetAt: string;
}

export interface AdminUser {
  id: string;
  name: string;
  email: string;
  plan: Plan;
  createdAt: string;
  usage: UserUsage | null;
}

export interface PlanLimits {
  transcriptionMinutes: number;
  recallHours: number;
  aiCredits: number;
  storageGb: number;
}

export interface UserListResponse {
  users: AdminUser[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface PlatformStats {
  totalUsers: number;
  planCounts: { FREE: number; PRO: number; BUSINESS: number };
  usageTotals: {
    transcriptionMinutes: number;
    recallHours: number;
    aiCredits: number;
    storageGb: number;
  };
}

export async function adminLoginRequest(
  email: string,
  password: string,
): Promise<string> {
  const res = await apiClient.post("/admin/auth/login", { email, password });
  return res.data.data.token;
}

export async function fetchStats(): Promise<PlatformStats> {
  const res = await apiClient.get("/admin/stats");
  return res.data.data;
}

export async function fetchUsers(
  page: number = 1,
  search?: string,
): Promise<UserListResponse> {
  const res = await apiClient.get("/admin/users", {
    params: { page, limit: 20, ...(search ? { search } : {}) },
  });
  return res.data.data;
}

export async function fetchUser(
  id: string,
): Promise<{ user: AdminUser; limits: PlanLimits }> {
  const res = await apiClient.get(`/admin/users/${id}`);
  return res.data.data;
}

export async function updateUserPlan(id: string, plan: Plan): Promise<void> {
  await apiClient.patch(`/admin/users/${id}/plan`, { plan });
}

export async function resetUserUsage(id: string): Promise<void> {
  await apiClient.patch(`/admin/users/${id}/usage/reset`);
}
```

- [ ] **Step 2: Commit**

```bash
git add src/services/adminService.ts
git commit -m "feat(admin): add frontend adminService with all API calls and types"
```

---

### Task 13: Create `AdminRoute.tsx`

**Files:**
- Create: `crelyzor-admin/src/components/AdminRoute.tsx`

- [ ] **Step 1: Create the file**

```typescript
import { Navigate, Outlet } from "react-router-dom";

export default function AdminRoute() {
  const token = localStorage.getItem("admin_token");
  if (!token) return <Navigate to="/login" replace />;
  return <Outlet />;
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/AdminRoute.tsx
git commit -m "feat(admin): add AdminRoute auth guard"
```

---

### Task 14: Create `LoginPage.tsx`

**Files:**
- Create: `crelyzor-admin/src/pages/LoginPage.tsx`

- [ ] **Step 1: Create the file**

```typescript
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { adminLoginRequest } from "@/services/adminService";

export default function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const token = await adminLoginRequest(email, password);
      localStorage.setItem("admin_token", token);
      navigate("/");
    } catch {
      setError("Invalid email or password");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-950">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-1 text-center">
          <h1 className="text-2xl font-bold text-white">Crelyzor Admin</h1>
          <p className="text-sm text-zinc-400">Founders only</p>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email" className="text-zinc-300">Email</Label>
            <Input
              id="email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="bg-zinc-900 border-zinc-700 text-white"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password" className="text-zinc-300">Password</Label>
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="bg-zinc-900 border-zinc-700 text-white"
            />
          </div>
          {error && <p className="text-sm text-red-400">{error}</p>}
          <Button type="submit" className="w-full" disabled={loading}>
            {loading ? "Signing in..." : "Sign in"}
          </Button>
        </form>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/LoginPage.tsx
git commit -m "feat(admin): add LoginPage"
```

---

### Task 15: Create `DashboardPage.tsx`

**Files:**
- Create: `crelyzor-admin/src/pages/DashboardPage.tsx`

- [ ] **Step 1: Create the file**

```typescript
import { useQuery } from "@tanstack/react-query";
import { Users, Mic, Zap, Video } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { fetchStats } from "@/services/adminService";
import { queryKeys } from "@/lib/queryKeys";

function StatCard({
  title,
  value,
  sub,
  icon: Icon,
}: {
  title: string;
  value: string | number;
  sub?: string;
  icon: React.ElementType;
}) {
  return (
    <Card className="bg-zinc-900 border-zinc-800">
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-zinc-400">{title}</CardTitle>
        <Icon className="h-4 w-4 text-zinc-500" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold text-white">{value}</div>
        {sub && <p className="text-xs text-zinc-500 mt-1">{sub}</p>}
      </CardContent>
    </Card>
  );
}

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.stats(),
    queryFn: fetchStats,
  });

  if (isLoading) {
    return (
      <div className="p-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <Card key={i} className="bg-zinc-900 border-zinc-800 h-28 animate-pulse" />
        ))}
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="p-8 space-y-6">
      <h2 className="text-xl font-semibold text-white">Platform Overview</h2>
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          title="Total Users"
          value={data.totalUsers}
          icon={Users}
        />
        <StatCard
          title="Free"
          value={data.planCounts.FREE}
          sub="users on Free plan"
          icon={Users}
        />
        <StatCard
          title="Pro"
          value={data.planCounts.PRO}
          sub="users on Pro plan"
          icon={Users}
        />
        <StatCard
          title="Business"
          value={data.planCounts.BUSINESS}
          sub="users on Business plan"
          icon={Users}
        />
        <StatCard
          title="Transcription (this month)"
          value={`${data.usageTotals.transcriptionMinutes} min`}
          icon={Mic}
        />
        <StatCard
          title="AI Credits (this month)"
          value={data.usageTotals.aiCredits}
          icon={Zap}
        />
        <StatCard
          title="Recall Hours (this month)"
          value={`${data.usageTotals.recallHours.toFixed(1)} hrs`}
          icon={Video}
        />
        <StatCard
          title="Storage"
          value={`${data.usageTotals.storageGb.toFixed(2)} GB`}
          icon={Zap}
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/DashboardPage.tsx
git commit -m "feat(admin): add DashboardPage with platform stats"
```

---

### Task 16: Create `UsersPage.tsx`

**Files:**
- Create: `crelyzor-admin/src/pages/UsersPage.tsx`

- [ ] **Step 1: Create the file**

```typescript
import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Search, ChevronLeft, ChevronRight } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  fetchUsers,
  fetchUser,
  updateUserPlan,
  resetUserUsage,
  type Plan,
  type AdminUser,
} from "@/services/adminService";
import { queryKeys } from "@/lib/queryKeys";

const PLAN_COLORS: Record<Plan, string> = {
  FREE: "bg-zinc-700 text-zinc-300",
  PRO: "bg-blue-900 text-blue-300",
  BUSINESS: "bg-purple-900 text-purple-300",
};

function UsageBar({
  label,
  used,
  limit,
}: {
  label: string;
  used: number;
  limit: number;
}) {
  const pct = limit === -1 ? 0 : Math.min(100, (used / limit) * 100);
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs text-zinc-400">
        <span>{label}</span>
        <span>{limit === -1 ? `${used} / ∞` : `${used} / ${limit}`}</span>
      </div>
      {limit !== -1 && (
        <div className="h-1.5 rounded-full bg-zinc-800">
          <div
            className="h-full rounded-full bg-blue-500"
            style={{ width: `${pct}%` }}
          />
        </div>
      )}
    </div>
  );
}

function UserDetailPanel({
  userId,
  onClose,
}: {
  userId: string;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.users.detail(userId),
    queryFn: () => fetchUser(userId),
  });

  const planMutation = useMutation({
    mutationFn: ({ id, plan }: { id: string; plan: Plan }) =>
      updateUserPlan(id, plan),
    onSuccess: () => {
      toast.success("Plan updated");
      qc.invalidateQueries({ queryKey: ["admin", "users"] });
    },
    onError: () => toast.error("Failed to update plan"),
  });

  const resetMutation = useMutation({
    mutationFn: (id: string) => resetUserUsage(id),
    onSuccess: () => {
      toast.success("Usage reset");
      qc.invalidateQueries({ queryKey: queryKeys.users.detail(userId) });
    },
    onError: () => toast.error("Failed to reset usage"),
  });

  return (
    <Dialog open onOpenChange={onClose}>
      <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-md">
        <DialogHeader>
          <DialogTitle>User Detail</DialogTitle>
        </DialogHeader>
        {isLoading ? (
          <div className="space-y-3 animate-pulse">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="h-4 bg-zinc-800 rounded" />
            ))}
          </div>
        ) : data ? (
          <div className="space-y-5">
            <div className="space-y-1">
              <p className="font-semibold text-lg">{data.user.name}</p>
              <p className="text-zinc-400 text-sm">{data.user.email}</p>
              <p className="text-zinc-500 text-xs">
                Joined {new Date(data.user.createdAt).toLocaleDateString()}
              </p>
            </div>

            <div className="space-y-2">
              <p className="text-sm text-zinc-400 font-medium">Plan</p>
              <div className="flex gap-2">
                {(["FREE", "PRO", "BUSINESS"] as Plan[]).map((p) => (
                  <Button
                    key={p}
                    size="sm"
                    variant={data.user.plan === p ? "default" : "outline"}
                    className={data.user.plan === p ? "" : "border-zinc-700 text-zinc-300"}
                    disabled={planMutation.isPending}
                    onClick={() => planMutation.mutate({ id: userId, plan: p })}
                  >
                    {p}
                  </Button>
                ))}
              </div>
            </div>

            {data.user.usage && (
              <div className="space-y-3">
                <p className="text-sm text-zinc-400 font-medium">Usage this month</p>
                <UsageBar
                  label="Transcription (min)"
                  used={data.user.usage.transcriptionMinutesUsed}
                  limit={data.limits.transcriptionMinutes}
                />
                <UsageBar
                  label="AI Credits"
                  used={data.user.usage.aiCreditsUsed}
                  limit={data.limits.aiCredits}
                />
                <UsageBar
                  label="Recall Hours"
                  used={data.user.usage.recallHoursUsed}
                  limit={data.limits.recallHours}
                />
                <p className="text-xs text-zinc-500">
                  Resets {new Date(data.user.usage.resetAt).toLocaleDateString()}
                </p>
              </div>
            )}

            <Button
              variant="outline"
              size="sm"
              className="border-zinc-700 text-zinc-300 w-full"
              disabled={resetMutation.isPending}
              onClick={() => {
                if (confirm("Reset this user's usage counters to zero?")) {
                  resetMutation.mutate(userId);
                }
              }}
            >
              {resetMutation.isPending ? "Resetting..." : "Reset Usage"}
            </Button>
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}

export default function UsersPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: queryKeys.users.list(page, debouncedSearch),
    queryFn: () => fetchUsers(page, debouncedSearch || undefined),
  });

  const handleSearch = (val: string) => {
    setSearch(val);
    setPage(1);
    // Simple debounce via timeout
    setTimeout(() => setDebouncedSearch(val), 300);
  };

  return (
    <div className="p-8 space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold text-white">Users</h2>
        <div className="relative w-64">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-zinc-500" />
          <Input
            placeholder="Search by name or email"
            value={search}
            onChange={(e) => handleSearch(e.target.value)}
            className="pl-9 bg-zinc-900 border-zinc-700 text-white"
          />
        </div>
      </div>

      <div className="rounded-lg border border-zinc-800 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-zinc-900 text-zinc-400">
            <tr>
              <th className="text-left px-4 py-3 font-medium">User</th>
              <th className="text-left px-4 py-3 font-medium">Plan</th>
              <th className="text-left px-4 py-3 font-medium">Transcription</th>
              <th className="text-left px-4 py-3 font-medium">AI Credits</th>
              <th className="text-left px-4 py-3 font-medium">Joined</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-800">
            {isLoading
              ? Array.from({ length: 10 }).map((_, i) => (
                  <tr key={i}>
                    {Array.from({ length: 5 }).map((_, j) => (
                      <td key={j} className="px-4 py-3">
                        <div className="h-4 bg-zinc-800 rounded animate-pulse" />
                      </td>
                    ))}
                  </tr>
                ))
              : data?.users.map((user: AdminUser) => (
                  <tr
                    key={user.id}
                    className="hover:bg-zinc-900 cursor-pointer transition-colors"
                    onClick={() => setSelectedUserId(user.id)}
                  >
                    <td className="px-4 py-3">
                      <p className="font-medium text-white">{user.name}</p>
                      <p className="text-zinc-500 text-xs">{user.email}</p>
                    </td>
                    <td className="px-4 py-3">
                      <Badge className={PLAN_COLORS[user.plan]}>{user.plan}</Badge>
                    </td>
                    <td className="px-4 py-3 text-zinc-300">
                      {user.usage?.transcriptionMinutesUsed ?? 0} min
                    </td>
                    <td className="px-4 py-3 text-zinc-300">
                      {user.usage?.aiCreditsUsed ?? 0}
                    </td>
                    <td className="px-4 py-3 text-zinc-400">
                      {new Date(user.createdAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
          </tbody>
        </table>
      </div>

      {data && data.totalPages > 1 && (
        <div className="flex items-center justify-between text-sm text-zinc-400">
          <span>
            {data.total} users · page {data.page} of {data.totalPages}
          </span>
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="outline"
              className="border-zinc-700"
              disabled={page === 1}
              onClick={() => setPage((p) => p - 1)}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <Button
              size="sm"
              variant="outline"
              className="border-zinc-700"
              disabled={page === data.totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {selectedUserId && (
        <UserDetailPanel
          userId={selectedUserId}
          onClose={() => setSelectedUserId(null)}
        />
      )}
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/pages/UsersPage.tsx
git commit -m "feat(admin): add UsersPage with table, search, pagination, and detail panel"
```

---

### Task 17: Wire `App.tsx`, `main.tsx`, and create `TASKS.md`

**Files:**
- Modify: `crelyzor-admin/src/App.tsx`
- Modify: `crelyzor-admin/src/main.tsx`
- Create: `crelyzor-admin/TASKS.md`

- [ ] **Step 1: Replace `App.tsx`**

```typescript
import { BrowserRouter, Routes, Route, Navigate, NavLink } from "react-router-dom";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "sonner";
import AdminRoute from "@/components/AdminRoute";
import LoginPage from "@/pages/LoginPage";
import DashboardPage from "@/pages/DashboardPage";
import UsersPage from "@/pages/UsersPage";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 30_000, retry: 1 },
  },
});

function Layout({ children }: { children: React.ReactNode }) {
  const linkClass = ({ isActive }: { isActive: boolean }) =>
    `px-3 py-2 rounded-md text-sm font-medium transition-colors ${
      isActive ? "bg-zinc-800 text-white" : "text-zinc-400 hover:text-white"
    }`;

  return (
    <div className="min-h-screen bg-zinc-950">
      <nav className="border-b border-zinc-800 px-8 py-3 flex items-center gap-6">
        <span className="font-bold text-white text-sm">Crelyzor Admin</span>
        <NavLink to="/" end className={linkClass}>Dashboard</NavLink>
        <NavLink to="/users" className={linkClass}>Users</NavLink>
        <button
          onClick={() => {
            localStorage.removeItem("admin_token");
            window.location.href = "/login";
          }}
          className="ml-auto text-xs text-zinc-500 hover:text-zinc-300 transition-colors"
        >
          Sign out
        </button>
      </nav>
      <main>{children}</main>
    </div>
  );
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route element={<AdminRoute />}>
            <Route
              path="/"
              element={<Layout><DashboardPage /></Layout>}
            />
            <Route
              path="/users"
              element={<Layout><UsersPage /></Layout>}
            />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
      <Toaster theme="dark" />
    </QueryClientProvider>
  );
}
```

- [ ] **Step 2: Replace `main.tsx`**

```typescript
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App.tsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
```

- [ ] **Step 3: Create `TASKS.md`**

```markdown
# crelyzor-admin — Task List

Last updated: 2026-05-08

## Phase 1 — v1 (current)

- [x] Backend: verifyAdmin middleware
- [x] Backend: /api/v1/admin/* route group (login, users, stats)
- [x] Frontend: Login page
- [x] Frontend: Dashboard (platform stats)
- [x] Frontend: Users table with search, pagination, plan management, usage reset

## Phase 2 — Future

- [ ] Audit log — record every plan change with timestamp + admin
- [ ] User soft-delete / suspend from admin
- [ ] System health — queue depth, error rates, recent failures
- [ ] Email admin invites — proper AdminUser table for team access
- [ ] Production deploy of admin portal
```

- [ ] **Step 4: Commit**

```bash
git add src/App.tsx src/main.tsx TASKS.md
git commit -m "feat(admin): wire App.tsx routing + create TASKS.md"
```

---

## Phase 4 — Skill Update

### Task 18: Update `crelyzor-start` skill

**Files:**
- Find: the `crelyzor-start` skill file (run `find ~/.claude -name "*.md" | xargs grep -l "crelyzor-start" 2>/dev/null | head -5` to locate it)
- Modify: wherever the skill file lives

- [ ] **Step 1: Find the skill file**

```bash
find ~/.claude -name "*.md" | xargs grep -l "calendar-backend" 2>/dev/null
```

- [ ] **Step 2: Add `crelyzor-admin` to the git status block**

Find this block in the skill:

```bash
git -C calendar-backend status --short
git -C calendar-frontend status --short
git -C cards-frontend status --short
```

Replace with:

```bash
git -C crelyzor-backend status --short
git -C crelyzor-frontend status --short
git -C crelyzor-public status --short
git -C crelyzor-admin status --short
```

- [ ] **Step 3: Add `crelyzor-admin/TASKS.md` to the read list**

Find the step that reads TASKS.md files and add `crelyzor-admin/TASKS.md` to the list.

- [ ] **Step 4: Fix any remaining `calendar-*` / `cards-frontend` references**

The skill currently uses outdated repo names. Replace:
- `calendar-backend` → `crelyzor-backend`
- `calendar-frontend` → `crelyzor-frontend`
- `cards-frontend` → `crelyzor-public`

And in the session briefing output template, add `crelyzor-admin` as the 4th repo line.

---

## End-to-End Verification

After all tasks are complete:

- [ ] `make local-up` — confirm admin is NOT started (check with `make local-ps`)
- [ ] `make admin-up` — confirm admin container starts on port 5175
- [ ] Open `http://localhost:5175` — redirects to `/login`
- [ ] Log in with `ADMIN_EMAIL` / `ADMIN_PASSWORD` — lands on Dashboard with real stats
- [ ] Navigate to `/users` — see user table with real data
- [ ] Click a user — detail panel opens, usage bars render
- [ ] Change plan from FREE → PRO — badge updates, toast shows "Plan updated"
- [ ] Click Reset Usage — confirm dialog → counters zero out
- [ ] Sign out — redirects to `/login`, token cleared
- [ ] Refresh on `/users` without token — redirects to `/login`

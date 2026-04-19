# Dark / Light Theme — crelyzor-public

**Scope:** `crelyzor-public` only (Next.js 15.2, Tailwind 3.4, no `next-themes` yet)  
**Status:** Planned, not started

---

## Current state

| Thing | State |
|---|---|
| `tailwind.config.ts` | No `darkMode` key — defaults to media query (wrong) |
| `globals.css` | Bare — just `@tailwind` directives, zero CSS variables |
| `layout.tsx` | No ThemeProvider, `themeColor` hardcoded `#0a0a0a`, `suppressHydrationWarning` on `<body>` (needs to move to `<html>`) |
| Pricing page | Fully hardcoded dark (`bg-neutral-950`, `text-neutral-100`, etc.) — biggest refactor |
| Home page (`/`) | Light (`bg-neutral-50`, `text-neutral-950`) — needs dark: variants |
| Card pages | Dark card face (`#0a0a0a`) on light page (`bg-neutral-100`) — card stays dark always |
| Schedule / booking / meeting | Mixed — need light-touch dark: variants |

---

## Design decisions

- **Default theme: `dark`** — preserves current look for all existing visitors
- **System preference:** respected via `enableSystem: true` on next-themes
- **Card face:** ALWAYS `#0a0a0a` regardless of theme — it's a physical dark card (design spec)
- **Gold accent (`#d4af61`):** unchanged — works on both backgrounds
- **Persistence:** `localStorage` via next-themes (automatic)

---

## Token system (CSS variables)

Define in `globals.css` under `:root` (dark default) and `.light` (light override).

```css
:root {
  /* Dark default — matches existing aesthetic */
  --background: #0a0a0a;
  --foreground: #fafafa;
  --surface: #171717;
  --surface-raised: #262626;
  --border: #262626;
  --muted: #737373;
  --muted-foreground: #a3a3a3;
  --nav-bg: rgba(10, 10, 10, 0.8);
}

.light {
  --background: #ffffff;
  --foreground: #0a0a0a;
  --surface: #f5f5f5;
  --surface-raised: #ffffff;
  --border: #e5e5e5;
  --muted: #737373;
  --muted-foreground: #525252;
  --nav-bg: rgba(255, 255, 255, 0.8);
}
```

Extend `tailwind.config.ts` to expose these as Tailwind classes:

```ts
theme: {
  extend: {
    colors: {
      background: 'var(--background)',
      foreground: 'var(--foreground)',
      surface: 'var(--surface)',
      'surface-raised': 'var(--surface-raised)',
      border: 'var(--border)',
      muted: 'var(--muted)',
      'muted-foreground': 'var(--muted-foreground)',
    },
  },
}
```

---

## Implementation steps

### Step 1 — Install next-themes

```bash
cd crelyzor-public
pnpm add next-themes
```

---

### Step 2 — Tailwind config

`tailwind.config.ts`:
- Add `darkMode: 'class'` at the top level
- Add the CSS variable color extensions (see token system above)

---

### Step 3 — CSS variables

Update `src/app/globals.css`:
- Add `:root` block (dark defaults)
- Add `.light` block (light overrides)
- Keep existing `body` styles

---

### Step 4 — ThemeProvider component

New file: `src/components/ThemeProvider.tsx`

```tsx
'use client';

import { ThemeProvider as NextThemesProvider } from 'next-themes';
import type { ThemeProviderProps } from 'next-themes';

export function ThemeProvider({ children, ...props }: ThemeProviderProps) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
```

---

### Step 5 — Update layout.tsx

Three changes:
1. Move `suppressHydrationWarning` from `<body>` to `<html>` (next-themes requirement)
2. Wrap `{children}` in `<ThemeProvider attribute="class" defaultTheme="dark" enableSystem>`
3. Make `themeColor` dynamic:

```ts
export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: dark)', color: '#0a0a0a' },
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
  ],
};
```

---

### Step 6 — ThemeToggle component

New file: `src/components/ThemeToggle.tsx`

```tsx
'use client';

import { useTheme } from 'next-themes';
import { useEffect, useState } from 'react';
import { Sun, Moon } from 'lucide-react'; // or inline SVG if lucide not installed

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  // Avoid hydration mismatch — render nothing until mounted
  useEffect(() => setMounted(true), []);
  if (!mounted) return <div className="w-8 h-8" />;

  return (
    <button
      onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}
      className="w-8 h-8 flex items-center justify-center rounded-lg text-muted-foreground hover:text-foreground hover:bg-surface transition-colors"
      aria-label="Toggle theme"
    >
      {theme === 'dark' ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
    </button>
  );
}
```

Check if lucide-react is installed in this repo first. If not, use inline SVGs.

---

### Step 7 — Pricing page (biggest change)

The pricing page has its own self-contained nav and layout — no shared shell.

**Nav:** Add `<ThemeToggle />` next to the "Get started free" button.

**Color mapping** (hardcoded → token class):

| Old | New |
|---|---|
| `bg-neutral-950` | `bg-background` |
| `bg-neutral-950/80` | `bg-[var(--nav-bg)]` |
| `bg-neutral-900` | `bg-surface` |
| `bg-neutral-900/50` | `bg-surface/50` |
| `bg-neutral-800/30` | `bg-surface-raised/30` |
| `text-neutral-100` / `text-neutral-50` | `text-foreground` |
| `text-neutral-400` | `text-muted-foreground` |
| `text-neutral-500` | `text-muted` |
| `text-neutral-600` | `text-muted` |
| `border-neutral-800` | `border-border` |
| `border-neutral-700` | `border-border` |
| `divide-neutral-800` | `divide-border` |

**Things that stay hardcoded (intentional):**
- The Pro plan header block — white (`bg-white text-neutral-950`) — it's a design highlight, not a theme surface
- The CTA banner — white card (`bg-white text-neutral-950`) — same reason
- Footer text — can use `text-muted`

---

### Step 8 — Home page (`/`)

Currently light (`bg-neutral-50`, `text-neutral-950`). Needs dark variants.

Light → theme-aware:
- `bg-neutral-50` → `bg-background`
- `text-neutral-950` → `text-foreground`
- `text-neutral-500` → `text-muted-foreground`
- `bg-neutral-900` (logo mark bg) → `bg-surface` or keep as `bg-neutral-900` (looks fine in both)

---

### Step 9 — Card pages (light touch)

The card face (`#0a0a0a`) is an inline style — **do not touch it**.  
Only the page shell and detail section need theme awareness.

Page wrapper: `bg-neutral-100` → `bg-neutral-100 dark:bg-neutral-950`

Detail section (white card below the flip card):
- `bg-white` → `bg-white dark:bg-neutral-900`
- `text-neutral-900` → `text-neutral-900 dark:text-neutral-100`
- `text-neutral-500` → `text-neutral-500 dark:text-neutral-400`
- `border-neutral-200` → `border-neutral-200 dark:border-neutral-800`

Action buttons on detail section:
- Primary (save contact): `bg-neutral-900 text-white` stays — works on both
- Secondary: `border-neutral-200 text-neutral-600` → add `dark:border-neutral-700 dark:text-neutral-300`

---

### Step 10 — Schedule / booking / published meeting pages

These are lower priority. Same approach: page shell gets theme-aware classes, content stays neutral. Do a quick pass after the main pages are done.

---

## File checklist

```
crelyzor-public/
├── package.json                          ← pnpm add next-themes
├── tailwind.config.ts                    ← darkMode: 'class' + color tokens
├── src/app/globals.css                   ← CSS variables (:root + .light)
├── src/app/layout.tsx                    ← ThemeProvider + suppressHydrationWarning on html
├── src/components/ThemeProvider.tsx      ← NEW
├── src/components/ThemeToggle.tsx        ← NEW (check if lucide-react exists first)
├── src/app/pricing/page.tsx              ← Full color refactor + toggle in nav
├── src/app/page.tsx                      ← Light touch dark: variants
├── src/components/CardView.tsx           ← Light touch on page shell + detail section
└── src/app/schedule/...                  ← Light touch after above
```

---

## Gotchas

1. **Hydration mismatch** — `ThemeToggle` must use a `mounted` state guard before rendering the icon. Without it, SSR renders one icon and client renders another → React warning.
2. **`suppressHydrationWarning` on `<html>`** — next-themes injects a `class` attribute on `<html>` client-side. The warning will fire without this.
3. **lucide-react** — check if it's installed in this repo (`pnpm list lucide-react`). If not, use inline SVGs in ThemeToggle.
4. **Pro plan white header block** — keep it as `bg-white text-neutral-950` always. It's a deliberate design contrast element, not a theme surface.
5. **CTA banner** — same as above, always white.
6. **`next-themes` SSR** — pages are SSR'd without theme class. The class gets applied on the client after hydration. This causes a brief flash on first load if the user's system preference differs from the default. Mitigation: `next-themes` handles this automatically via a blocking script injected into `<head>`. No extra work needed.

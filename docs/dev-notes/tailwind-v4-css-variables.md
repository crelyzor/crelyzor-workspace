# Tailwind v4 CSS Variable Utilities — Dev Notes

## Problem
Button and modal theming was broken in `calendar-frontend`. CSS variable-based utilities (e.g. `bg-background`, `text-foreground`, `border-border`) were not resolving correctly.

## Root cause
Tailwind v4 changed how CSS variable utilities work. In v4, CSS variables must be explicitly registered or referenced differently than v3.

## Fix
Ensure CSS variables are defined in `index.css` under `@layer base` and that Tailwind v4 config correctly maps them. The pattern that works:

```css
/* index.css */
@layer base {
  :root {
    --background: #ffffff;
    --foreground: #0a0a0a;
    /* ... */
  }
  .dark {
    --background: #0a0a0a;
    --foreground: #fafafa;
    /* ... */
  }
}
```

## Gotcha
- `calendar-frontend` uses **Tailwind v4** — syntax and config differ from v3.
- `cards-frontend` uses **Tailwind v3** — do not copy v4 config patterns there.
- Never hardcode hex values in components — always use CSS variable classes so dark mode auto-switches.

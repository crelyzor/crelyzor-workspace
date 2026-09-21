# Hyperframes Composition Brief: Crelyzor

## Objective
Create a short launch-style brag video for Crelyzor — an all-in-one productivity OS (digital cards + AI meetings + scheduling + tasks) built by a solo founder. The video must *demonstrate* the product's central claim rather than assert it.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 22.0s

## Source Material
- Project root: `/Users/harshkeshari/Developer/crelyzor-workspace`
- Primary files read:
  - `README.md`, `CLAUDE.md`
  - `crelyzor-public/src/app/page.tsx` (metadata + page composition)
  - `crelyzor-public/src/components/sections/Hero.tsx` (hero copy + the in-app mock screens — **the richest source; read it**)
  - `crelyzor-public/src/components/sections/Features.tsx` (feature list + "One product. Ten superpowers.")
  - `crelyzor-public/src/components/sections/Demo.tsx` (the flipping business card component — exact styling)
  - `crelyzor-public/src/components/sections/CTA.tsx` (outro copy)
  - `crelyzor-public/src/app/globals.css` (CSS custom properties), `crelyzor-public/src/app/layout.tsx` (Inter)
  - `crelyzor-public/public/assets/logo-dark.svg` (wordmark for the outro)
- Product name: **Crelyzor**
- Tagline / strongest claim: **"Your meetings remember everything."**
- Key UI moments to recreate (all exist in `Hero.tsx` as real mock components — match their structure and styling closely):
  - `MeetingBody` — the meeting detail screen at `app.crelyzor.app/meetings/ethics-ai`
  - `TasksBody` — the Tasks kanban board at `app.crelyzor.app/tasks`
  - `BusinessCard` in `Demo.tsx` — the dark 1.586:1 card that flips on Y over 700ms
- Copy that must appear verbatim:
  - `Crelyzor · Early access`
  - `Your meetings remember everything.` (split across two lines; *everything* in gold)
  - `Ethics and Safety in AI Development`
  - `Mar 4, 2026 · 3 min`
  - `Dadrio` / `Nikhil` (speaker chips)
  - `Recording · Transcript · AI Summary · Tasks · Notes · Ask AI · Generate` (tab row; AI Summary active)
  - `Establish bias testing protocols before deployment`
  - `Transparency reports required for enterprise AI`
  - `Draft bias testing framework doc`
  - `Schedule regulatory review call`
  - `Action items become tasks.`
  - `Your identity, everywhere.`
  - `Harsh` / `FOUNDER, CRELYZOR` / `harsh@crelyzor.app` / `crelyzor.app`
  - `One tool.` / `Everything connected.`

## Creative Direction
- **Tone preset:** `polished`
- **Creative direction:** a quiet, confident founder's product film — dark, gold, editorial
- **Interpretation:** Five scenes, none shorter than 3.8s. Long settled holds, soft crossfades (0.45–0.6s), quick-but-calm entrances (0.35–0.5s). Mixed case, medium/semibold Inter, tracking-tight headlines, generous `0.15em` tracking on tiny uppercase eyebrows. Nothing strobes, tilts, rotates for effect, or shouts. Restraint is the pitch — this must look like software someone already pays for, not a template promo.
- **Angle:** No jokes, no fake startup voice. This is a real product, and the brag is the *connection* between its parts: we don't cut between four features, we follow one meeting as it turns itself into work. "Your meetings remember everything" gets proven on screen in five seconds instead of merely claimed. The centerpiece is the working app, not the landing page.
- **Hook (0.0–3.8s):** Near-black, a gold radial glow blooming from the top, the eyebrow, then the hero line at full scale in two lines with *everything* in gold. No SFX, no motion tricks — confidence.
- **Outro / punchline (17.5–22.0s):** The CTA copy verbatim — "One tool." / "Everything connected." (gold) — then the wordmark and `crelyzor.app` settling underneath. Hold to black.
- **Avoid:**
  - Generic SaaS language (the project's own copy is the only copy)
  - Abstract filler visuals, particles, gradients-as-content, visualizer graphics
  - Unrelated visual redesign — do not invent a new brand look; this brand is dark + one gold
  - Any text that isn't in the verbatim list above or the storyboard
  - Emoji, stock iconography that isn't Lucide-like line icons

## Visual Identity
- **Background:** `#0a0a0a` (`--background`)
- **Surfaces:** `#111` panels, `#171717` (`--surface`), `#1a1a1a` (card monogram tile), `#262626` borders (`--border`)
- **Text:** `#fafafa` (`--foreground`); muted `#a3a3a3` (`--muted-foreground`); dim `#737373` / `#555`
- **Accent:** `#d4af61` (GOLD — used for exactly one emphasis per frame, never two)
- **Display font:** Inter, semibold (600), `letter-spacing: -0.02em`, `line-height: 1.04`. Use a local/system fallback stack if Inter isn't bundleable — `Inter, -apple-system, "Segoe UI", sans-serif`.
- **Body font:** Inter regular/medium, same fallback.
- **Visual references from the project:**
  - Gold radial hero glow: `radial-gradient(ellipse at top, #d4af6108 0%, transparent 70%)`, ~700x400 — mirrored to `ellipse at bottom` with `#d4af610a` in the CTA section
  - App frame: `rounded-2xl`, `1px solid #262626`, `box-shadow: 0 24px 60px rgba(0,0,0,0.7), 0 8px 24px rgba(0,0,0,0.4)`, with a `#111` URL bar above the content
  - Eyebrows: 8–10px uppercase, `letter-spacing: 0.15em`, color `#737373`, often at 40–60% opacity
  - Tiny gold dot (6px, `#d4af61`) as the brand tick before labels
  - Business card: aspect `1.586/1`, bg `#0a0a0a`, 135° repeating-linear-gradient hairline texture at 3% opacity, a `#1a1a1a` monogram tile with `box-shadow: 0 0 0 1.5px #d4af61`, gold uppercase role text at wide tracking, a 2px `linear-gradient(90deg, #d4af61, #d4af6155)` strip along the bottom edge, and `0 32px 80px rgba(0,0,0,0.8)` shadow
  - Task/status accent green (used sparingly in the board): `#4ade80`

## Storyboard
Use the storyboard in `brag-output/brag-plan.md` as the creative contract. Scene summary:

1. **The claim** — 3.82s `(0.00→3.82)` — Gold glow blooms; eyebrow `Crelyzor · Early access`; then the two-line hero headline, *everything* in gold. Must be fully settled and readable for ≥2s. No SFX.
2. **The meeting summarizes itself** — 4.92s `(3.82→8.74)` — App frame scales 0.96→1.0 with URL `app.crelyzor.app/meetings/ethics-ai`. Meeting header (title, `Mar 4, 2026 · 3 min`, speaker chips Dadrio/Nikhil). Tab underline **glides** from Recording to **AI Summary**. Summary paragraph fades in as texture (small, not required reading). Then **two** KEY POINTS rows arrive one at a time ~1.09s apart, each holding ≥1.2s settled and both still on screen at the cut.
3. **Action items become tasks** — 4.37s `(8.74→13.11)` — Same frame, no reload. ACTION ITEMS rows appear, then the frame content cross-dissolves to the Tasks board (URL retypes to `app.crelyzor.app/tasks`) and **those same two rows fly into the To Do column** as task cards with a small gold "From meeting" tag, ~1.09s apart, each holding ≥1.0s. Existing context cards (`Update onboarding docs`, `Build card analytics page`) and an In Progress column sit behind. Caption below the frame: **"Action items become tasks."**
4. **Your identity, everywhere** — 4.36s `(13.11→17.47)` — The dark business card centered with soft gold rim light; a simulated tap triggers a 0.7s Y-flip (`cubic-bezier(0.4,0,0.2,1)`) to the QR back; it holds. Caption: **"Your identity, everywhere."**
5. **One tool** — 4.53s `(17.47→22.00)` — Back to black with the glow now at the bottom. `One tool.` then `Everything connected.` (gold) landing on the 18.56s cue. Wordmark + `crelyzor.app` fade up beneath. Final ~1.2s is a settled quiet frame — **this is the poster frame.**

**Readability floors (non-negotiable):** headline ≥2.0s settled; every caption and key-point/task line ≥1.0s settled after entering and before exiting. If a scene can't fit its copy at those floors, cut copy — do not speed the reveal up.

## Audio
- **Audio role:** Warm, steady, low bed with sparse professional accents. Support, never drive.
- **Audio arc:** The bed opens quietly under the hook with no SFX at all; picks up presence as the app frame settles; carries three small tactile accents through the middle (frame settle, two task cards landing); gives one restrained bell as "Everything connected." arrives; fades to silence under the wordmark.
- **Music:** `assets/music/happy-beats-business-moves-vol-12-by-ende-dot-app.mp3` (bundled, "steady and clean" — the `polished` pick). Copied into the composition already.
- **Music treatment:** `data-start="0"`, `data-volume="0.30"`, ~0.4s fade-in, fade out over the final ~1.2s. No aggressive ducking.
- **Music cue guidance:** bundled preset — source JSON at `/Users/harshkeshari/.claude/plugins/cache/brag/brag/0.2.2/skills/brag/assets/music/cues/happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json` (also copied to `composition/assets/music/cues/`). Tempo ≈ 109.96 BPM, beat ≈ 0.545s.
  - **Strong-cue locks (use these three, ±0.15s):** `8.74s` → scene 2→3 cut; `13.11s` → scene 3→4 cut; `17.47s` → scene 4→5 cut. Optional fourth: `18.56s` → "Everything connected." landing.
  - **Beat-grid windows (every *other* beat, ~1.09s apart, ±0.10s):** key points in `5.34 → 7.64`; task cards landing in `9.83 → 12.02`.
  - Full grid: 0.56, 1.09, 1.64, 2.19, 2.73, 3.27, 3.82, 4.39, 4.91, 5.34, 6.00, 6.56, 7.09, 7.64, 8.19, 8.74, 9.29, 9.83, 10.37, 10.93, 11.46, 12.02, 12.55, 13.11, 13.64, 14.20, 14.73, 15.29, 15.84, 16.38, 16.93, 17.47, 18.02, 18.56, 19.10, 19.66, 20.19, 20.75, 21.28, 21.84
  - Ignore any cue that hurts readability or the product story.
- **Audio-reactive treatment:** **subtle**. Wire the gold radial glow's opacity/scale and the app frame's shadow presence to music RMS/bass so they breathe. Optionally a soft treble lift on the outro wordmark. **No** waveform, equalizer bars, particles, strobing, or anything that scales text.
- **Audio-coupled moments:**
  - Scene 1 headline — **deliberately silent**; no SFX on any text in the hook.
  - Scene 2, app frame settling — a soft drop/settle accent at the *start* of the scale-in.
  - Scene 2, tab underline landing on "AI Summary" — optional very light accent; skip if it crowds.
  - Scene 3, each task card landing in To Do (2×) — one light card-place accent per landing, fired at the same timestamp as the landing animation *starts*.
  - Scene 4, card flip — one soft card/flip accent at the start of the rotation, nothing after.
  - Scene 5, "Everything connected." landing on 18.56s — one restrained bell. Nothing on the wordmark.
- **SFX selection guidance:** `polished` energy — 3–4 cues total for the whole video, volume `0.55–0.70`, all motion-matched. Card-like reveals get card/drop sounds; the single payoff gets a short announcement cue. Never more than one SFX audible at a time. If a cue makes the edit feel like a template, drop it.
- **SFX analysis guidance:** read `/Users/harshkeshari/.claude/plugins/cache/brag/brag/0.2.2/skills/brag/assets/sfx/sfx-analysis.md` before choosing files; prefer **low/medium high-frequency risk** files — every cue here is a polished or repeated moment.
- **Exact SFX choice:** Hyperframes chooses filenames, timestamps, density, and volume after the visual animation exists.
- **Audio files:** copy chosen SFX into `brag-output/composition/assets/sfx/<family>/`. Music bed on `data-track-index="10"`, SFX ascending from `11`. Never share a track-index between overlapping audio. Relative paths only — never absolute.

## Hyperframes Instructions
Load the composition-building Hyperframes domain skills — `hyperframes-core` (composition contract + `data-*` timing), `hyperframes-animation` (motion), `hyperframes-creative` (design spec, beats, audio-reactive), `hyperframes-keyframes` (seek-safe keyframes), and `hyperframes-cli` (lint/check/render). `/brag` is its own workflow: do **not** enter the `hyperframes` entry-point intent interview and do **not** route into its generic promo / launch-video workflow. Prefer native Hyperframes conventions over anything in `/brag`.

Requirements:
- Show at least one real UI, copy, or visual element from the source project — here, three: the meeting screen, the tasks board, and the business card. Read `Hero.tsx` and `Demo.tsx` and match their structure and styling.
- Keep all text readable in the final render; honor the readability floors above over any beat.
- Keep the video within 15–25 seconds (target 22.0s).
- Include the planned music/SFX layer.
- Treat `/brag` audio notes as guidance, not a fixed cue sheet. Choose SFX after the visual animation exists.
- Treat music cue metadata as optional timing hints; ignore cues that hurt readability, pacing, or the story.
- Lock the three named scene cuts to their strong cues within ±0.15s and mark them `// beat-locked`. Snap the two sequential reveals to the beat grid within ±0.10s and mark them `// beat-grid`.
- Wire at least one visual element to per-frame audio data (subtle), or document the extraction failure and skip it — do not block the render.
- Use local assets only. Relative paths from `composition/`.
- Run `npx hyperframes check` before render — it is brag's single gate.

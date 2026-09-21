# Brag Plan: Crelyzor

## 9-question rubric (Step 1)

1. **What is the app?** An all-in-one productivity OS for solo professionals — digital cards, AI meeting transcription/summary, scheduling, and tasks, where every part knows about the others.
2. **Most impressive claim?** The hero h1: *"Your meetings remember everything."* Runner-up, from Features: *"Every transcript, summary, note, and contact is encrypted with a key only you control."*
3. **Visual hook?** The near-black `#0a0a0a` canvas with the single gold `#d4af61` accent, and the dark 1.586:1 business card with a gold hairline and gold "H" monogram that flips on tap.
4. **What to show from the actual UI?** The Hero's product walkthrough mocks — specifically the meeting detail screen (`app.crelyzor.app/meetings/ethics-ai`) with its tab row and AI Summary, and the Tasks kanban board.
5. **Shortest satisfying video?** ~22s. Needs four beats: the claim, the meeting getting summarized, action items becoming tasks, the card.
6. **Tone?** Preset `polished`. Direction: *a quiet, confident founder's product film — dark, gold, editorial.* This product is not a joke; restraint is the credibility.
7. **Audio?** Warm, steady, low bed (vol-12) with 3 very subtle motion-matched cues. Nothing aggressive.
8. **Share caption?** Drafted below.
9. **User flow worth showing?** Real, and it is the centerpiece: **a recorded meeting → AI summary + key points appear → the action items become tasks on the board.** Then the card as the identity coda.

---

## What is this app?
Crelyzor is one workspace that replaces HiHello, Cal.com, Otter.ai and Todoist — and the point is that they're connected: a meeting transcribes itself, summarizes itself, and hands you the tasks it found.

## The angle
No jokes, no fake startup voice. This is a real product built by one founder, and the brag is the *connection*: we don't cut between four features, we follow one meeting as it turns itself into work. The video is literally the product's claim, demonstrated — "Your meetings remember everything" is proven in five seconds rather than asserted.

## Hook (first 2-3 seconds)
Near-black. A single gold dot ignites, then the hero line arrives in two weights:
**"Your meetings"** (off-white) / **"remember everything."** (gold on *everything*).
It's the product's own headline at full scale. No setup, no question — polished tone earns attention with confidence, not a tease.

## Key moments (the middle)
- The meeting detail screen assembling: title *"Ethics and Safety in AI Development"*, speaker chips **Dadrio** / **Nikhil**, and the tab underline gliding across `Recording · Transcript · **AI Summary**` — the AI doing its job on screen.
- Two **Key Points** rows arriving one by one under the summary, each holding long enough to read.
- The two **Action Items** rows physically lifting out of the meeting card and landing in the Tasks board's **To Do** column — the "everything connected" claim as motion, not copy.
- The business card flipping to its QR back — the identity half of the product, in one gesture.

## Outro / punchline
Back to black. The CTA copy, verbatim: **"One tool."** / **"Everything connected."** (gold). The wordmark and `crelyzor.app` settle under it. Held, not slammed.

## User flow worth showing
Entry → key action → result:
1. **Entry** — open a recorded meeting (`app.crelyzor.app/meetings/ethics-ai`).
2. **Key action** — the AI Summary tab populates: summary, then key points one by one, then action items.
3. **Result** — those action items are already tasks on the Tasks board.
Scenes 2 and 3 are this flow. Scene 4 (card) is the one non-flow product visual. There is exactly one landing-page-style frame in the video (the hook) and one outro card.

## Tone
- **Preset:** `polished`
- **Creative direction:** a quiet, confident founder's product film — dark, gold, editorial
- **Interpretation:** Five scenes, none shorter than 3.8s, long settled holds, soft crossfades (0.45–0.6s). Entrances are quick (0.35–0.5s) but nothing strobes, tilts, or shouts. Type is mixed case, medium weight, generous tracking on eyebrows. The restraint *is* the pitch — this has to look like a product someone already pays for.

## Format: landscape — 1920x1080
## Duration: 22.0s

## Visual identity (from the project)
- **Background:** `#0a0a0a` (`--background`, dark default in `globals.css`)
- **Surfaces:** `#111` / `#171717` panels, `#262626` borders (`--surface`, `--border`)
- **Accent:** `#d4af61` (`GOLD`, hardcoded in Hero/Features/Demo/CTA)
- **Text:** `#fafafa` (`--foreground`), muted `#a3a3a3`, dim `#737373` / `#555`
- **Display font:** Inter (`next/font/google`, `--font-inter`), semibold, tracking-tight, leading ~1.04
- **Body font:** Inter, regular/medium
- **Signature treatments:** gold radial ellipse glow (`radial-gradient(ellipse at top, #d4af6108, transparent 70%)`), 1px `#262626` hairlines, `rounded-xl`/`rounded-2xl`, `0 24px 60px rgba(0,0,0,0.7)` frame shadow, uppercase 8–10px eyebrows at `0.15em` tracking
- **Strongest visual element:** the dark business card (aspect 1.586:1, `#0a0a0a`, gold `H` monogram in a `#1a1a1a` tile with a 1.5px gold ring, 135° 10px diagonal hairline texture at 3% opacity, gold gradient strip along the bottom edge)

## Share copy (draft)
Built Crelyzor: your meetings transcribe, summarize, and hand you the tasks they found — next to your card, your calendar, and your week. One tool. Everything connected.

## Audio direction
- **Role:** Warm, steady, low bed — support, never drive. Sparse professional accents.
- **Music:** `happy-beats-business-moves-vol-12-by-ende-dot-app.mp3` (steady and clean; the `polished` pick).
- **Music treatment:** start at 0.0s, volume 0.30, ~0.4s fade-in, fade out over the last ~1.2s of the outro. No ducking gymnastics.
- **Music cue guidance:** preset cue file read — `assets/music/cues/happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json`, tempo ≈ 110 BPM (beat ≈ 0.545s). Lock the three scene changes that matter to strong cues: **8.74s** (meeting → tasks), **13.11s** (tasks → card), **17.47s** (card → outro); let the wordmark settle near **18.56s**. Sequential reveals use the beat grid at **every other beat** (~1.09s apart), never every beat: key points in the 5.3–7.7s window, action-item tasks in the 9.8–12.0s window.
- **Audio-reactive treatment:** subtle — let the gold radial glow and the app frame's shadow presence breathe with music RMS/bass. No waveform, bars, or visualizer graphics, and nothing that scales text.
- **SFX posture:** Sparse. Three, maybe four cues total, 0.55–0.7 volume, all motion-matched. A soft drop when the app frame settles, a light accent as each action item lands in the board, one restrained bell on the wordmark. Nothing percussive on the hook.
- **Audio-coupled moments:** the tab underline sliding to "AI Summary"; each Key Point row arriving; each action-item card landing in the To Do column; the card flip; the wordmark settling.
- **Restraint rule:** No SFX during the hook line and no sound on any text fade. Never more than one SFX audible at a time. If a cue would make the video feel like a template, drop it.

---

## Storyboard

### Scene 1 — The claim — 3.8s  `(0.00 → 3.82)`
Full-bleed `#0a0a0a`. A gold radial ellipse glow blooms from the top center (the site's own `#d4af6108` hero glow), slowly. A 6px gold dot fades in at left with the eyebrow **"Crelyzor · Early access"** in 11px `#737373`, gold on the word Crelyzor. Then the hero line arrives, two lines, ~88px Inter semibold, tracking-tight, leading 1.04:
**"Your meetings"** `#fafafa` — **"remember everything."** with *everything* in `#d4af61`.
Both lines rise 16px and fade in over 0.45s, second line 0.18s behind the first, then hold ~2.2s fully settled.
Sequential/interaction: yes — eyebrow, then line 1, then line 2; each a beat apart on the grid (~1.09s).
Audio intent: the bed simply opens. Weight and quiet, not excitement.
Audio-coupled idea: none — the hook is deliberately silent of SFX.
Music: warm, steady, low.
Transition mood: soft crossfade (0.55s) → Scene 2

### Scene 2 — The meeting summarizes itself — 4.9s  `(3.82 → 8.74)`
The app frame arrives: a `rounded-2xl` browser panel, `#262626` hairline, deep shadow `0 24px 60px rgba(0,0,0,0.7)`, scaling 0.96→1.0 while fading up. URL chip reads `app.crelyzor.app/meetings/ethics-ai`.
Inside, the meeting header card (`#111`): **"Ethics and Safety in AI Development"**, then `Mar 4, 2026 · 3 min`, then the SPEAKERS (2) row with pill chips **Dadrio** and **Nikhil**.
The tab row sits below — `Recording · Transcript · AI Summary · Tasks · Notes · Ask AI · Generate` — and the white underline **glides** from Recording to land under **AI Summary**, which brightens to `#fff`.
Under the `SUMMARY` eyebrow a 2-line paragraph fades in as texture (small, `#a3a3a3`, not required reading). Then the `KEY POINTS` eyebrow and **two** rows arrive one by one, ~1.09s apart (every other beat), each a gold-grey dot + line:
— *"Establish bias testing protocols before deployment"*
— *"Transparency reports required for enterprise AI"*
Each row holds ≥1.2s settled; the pair is still on screen at the cut.
Sequential/interaction: yes — frame settles, tab underline slides to "AI Summary", then 2 key-point rows arrive one at a time on the beat grid.
Audio intent: something competent is happening on its own. Quiet machinery.
Audio-coupled idea: a soft drop as the app frame settles; a very light accent under the tab underline landing. Key point rows stay silent or take one shared whisper-level accent — not one each.
Music: unchanged bed; let the 8.74s strong cue carry the cut.
Transition mood: soft crossfade (0.5s), landing the cut on the 8.74s strong cue → Scene 3

### Scene 3 — Action items become tasks — 4.4s  `(8.74 → 13.11)`
Same app frame, no reload — continuity matters. The `ACTION ITEMS` eyebrow appears with two bordered rows (checkbox + label) inside the meeting panel:
— *"Draft bias testing framework doc"*
— *"Schedule regulatory review call"*
Then the frame's content cross-dissolves to the Tasks board (URL chip retypes to `app.crelyzor.app/tasks`) and **those same two rows fly in** — travelling from their meeting position into the **To Do** column, settling as task cards with a small gold "From meeting" tag. Two existing cards (*"Update onboarding docs"*, *"Build card analytics page"*) are already there as context, plus an **In Progress** column behind. The two arrivals are ~1.09s apart and each holds ≥1.0s.
A single caption line sits below the frame, `#a3a3a3`, 22px: **"Action items become tasks."** — fades in as the second card lands, holds to the cut.
Sequential/interaction: yes — two action-item rows detach and land as board cards, one after the other on the beat grid.
Audio intent: the click of things falling into place. Satisfaction, understated.
Audio-coupled idea: one light card-place/drop accent per landing card (two total, 0.55–0.6 volume), aligned to the start of each landing, not the end.
Music: bed continues; cut rides the 13.11s strong cue.
Transition mood: soft crossfade (0.5s) → Scene 4

### Scene 4 — Your identity, everywhere — 4.4s  `(13.11 → 17.47)`
The app frame recedes and the dark business card takes center — 1.586:1, `#0a0a0a`, the 135° hairline texture at 3%, the gold `H` monogram in its `#1a1a1a` tile with the 1.5px gold ring, **"Harsh"** and `FOUNDER, CRELYZOR` in gold uppercase 11px at wide tracking, `harsh@crelyzor.app` / `crelyzor.app` in `#a3a3a3` 10px, and the gold gradient strip along the bottom edge. Soft gold rim light behind it.
It **flips** on Y over ~0.7s (`cubic-bezier(0.4,0,0.2,1)`, matching the real component) to the QR back, then holds.
Caption below, `#a3a3a3` 22px, real product copy: **"Your identity, everywhere."**
Sequential/interaction: yes — a simulated tap on the card triggers the flip; caption follows once the back has settled.
Audio intent: a single physical gesture. Tactile, brief, then quiet again.
Audio-coupled idea: one soft card/flip accent at the start of the rotation. Nothing after.
Music: bed rises very slightly toward the 17.47s cue.
Transition mood: soft crossfade (0.6s) on the 17.47s strong cue → Scene 5

### Scene 5 — One tool — 4.5s  `(17.47 → 22.00)`
Back to `#0a0a0a` with the gold glow, now blooming from the bottom (mirroring the site's CTA section). The CTA copy verbatim, ~72px Inter semibold:
**"One tool."** `#fafafa` — **"Everything connected."** `#d4af61`.
Line 1 at the cut, line 2 landing on the **18.56s** strong cue. Both hold.
Then the Crelyzor wordmark (`/assets/logo-dark.svg`) fades up small and centered beneath with `crelyzor.app` in 13px `#737373`. Final ~1.2s is a settled, quiet frame with the music fading under it — this frame is the poster.
Sequential/interaction: yes — line 1 → line 2 on the strong cue → wordmark + URL.
Audio intent: arrival. One resonant note, then let it go.
Audio-coupled idea: one restrained bell accent (0.55 volume) as line 2 lands on the 18.56s cue; nothing on the wordmark. Music fades out over the last 1.2s.
Music: steady through, fade to silence at 22.0s.
Transition mood: hold to black.

---

**Scene duration check:** 3.82 + 4.92 + 4.37 + 4.36 + 4.53 = **22.0s** ✅ (within 15–25s, in the 18–22 sweet spot)

**Music mood for this video:** steady, clean, warm — supporting, never leading.
**Audio summary:** A low warm bed runs unbroken for 22 seconds, with exactly four deliberate accents — the app frame settling, two task cards landing, and one bell as "Everything connected." arrives — then fades to silence under the wordmark.

---

## Build notes — where the finished video departs from the plan above

Three changes made during composition, after seeing real frames:

1. **Scenes 2 and 3 are one clip, not two.** The plan called for a cross-dissolve between them; crossfading two copies of the same app frame dips its brightness. They were merged into a single 3.82→13.61s clip whose *contents* dissolve on the 8.74s cue, so the frame chrome never moves. This is closer to the plan's intent ("same frame, no reload") than two clips would have been.
2. **The card flip runs back → front, not front → back.** The back face (bio + social chips) is the weaker image; ending the scene on it wasted the scene's best 2.5 seconds. The card now lands face-down and is turned over to the identity face — gold monogram, name, role — which is what the caption ("Your identity, everywhere.") is actually about.
3. **The Tasks board carries more real content than planned** — due chips on the two existing To Do cards and a third In Progress card (`Email signature generator`, also from the source mock). The planned four cards left roughly a quarter of the app frame empty.

Also: each scene's editorial right rail carries a small uppercase section label (`AI Summary`, `Tasks`, `Digital Card`) that the plan didn't specify. All three are real product nouns from the app's own tab and nav naming.

**Audio as built:** music bed `vol-12` on track 10 via a volume automation lane (0 → 0.30 by 0.5s, held, → 0 by 22.0s). Five SFX, all motion-matched: `impactSoft_medium_000` at 3.87 (frame settles), `impactSoft_medium_002` at 9.83 and `impactSoft_medium_004` at 10.93 (task cards landing, both beat-grid), `interface/click_003` at 14.20 (the simulated tap), `impactBell_heavy_000` at 18.56 (beat-locked, "Everything connected."). Audio-reactive: the gold glow's opacity and scale follow RMS/bass, the app frame's backlight follows bass, and the outro wordmark glow follows treble — sampled per frame from pre-extracted data, no waveform graphics.

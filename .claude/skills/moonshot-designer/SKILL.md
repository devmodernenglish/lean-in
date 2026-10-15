---
name: moonshot-designer
description: Art direction and motion design for an organic, dreamlike, procedurally generated interface. Use whenever the user asks about look and feel, colour palettes, typography, layout, motion, easing, glow, atmosphere, onboarding copy, the demo moment, or says something looks flat, harsh, ugly, or "not magical enough". Also use before finalising any visual so it gets a polish pass.
---

# Moonshot Designer

You are the art director. The goal is a piece that makes people ask "how is this made of 1s and 0s?" Every decision serves **smoothness, atmosphere, and one unforgettable moment**.

## Aesthetic
- **Mood:** organic and dreamlike. Bioluminescence, haze, depth, slow drift. Nothing rigid, nothing flat.
- **Fictional only:** no stock imagery, no recognisable real-world assets. Everything is generated from math.
- **Restraint:** one hero effect, supported by quiet UI. If the UI competes with the visual, remove UI.

## Colour
- Dark, slightly blue-black base (never pure `#000`): e.g. `#050814`.
- 2 to 3 hue families per scene, with one bright accent used sparingly.
- Use cosine palettes (`a + b*cos(2π(c*t+d))`) so gradients feel organic. Starter palettes:
  - Abyss: a=(0.05,0.10,0.20) b=(0.30,0.40,0.50) c=(1,1,1) d=(0.55,0.65,0.80)
  - Spore: a=(0.20,0.15,0.25) b=(0.50,0.40,0.45) c=(1,0.8,0.6) d=(0.00,0.25,0.55)
  - Ember: a=(0.15,0.05,0.08) b=(0.60,0.30,0.25) c=(1,1,0.8) d=(0.05,0.10,0.30)
- Glow is additive. Layers fade into haze with distance. Finish with gentle filmic tonemapping and a soft vignette.
- Expose the palette as CSS custom properties in `assets/styles/tokens.scss` so UI and shaders share it.

## Motion
- Nothing snaps. All movement uses spring or ease-in-out; durations 400 to 1200 ms for UI, much slower for ambient drift.
- Parallax: nearer layers move more than far ones. Keep the ratio consistent (offset / depth).
- Idle is alive: the scene should drift subtly even with no input.
- Transitions cross-fade; avoid hard cuts and avoid bouncy overshoot.

## Typography and UI
- One typeface, light weight, generous letter-spacing, lowercase or sentence case. Use a system or self-hosted font, no remote fonts.
- Text is sparse: a title, one instruction line, a tiny status line. Fade text in and out; never pop.
- Controls are small, translucent, and hide when idle (fade after ~3 s).
- UI is built from atoms and molecules per `moonshot-frontend`; styles use BEM and shared tokens.

## The demo moment
Define it explicitly before polishing:
1. What does the stranger do in the first 5 seconds?
2. What is the single moment their expression changes?
3. What is the quietest possible way to prompt them? (usually one line of text)

## Polish checklist (run before declaring anything done)
- [ ] No harsh edges or banding (add a touch of noise dither to gradients)
- [ ] Contrast of any text is readable over the brightest glow
- [ ] Motion is smooth at rest; no micro-jitter
- [ ] Works at a different window size and on a big screen
- [ ] Idle state still looks beautiful in a screenshot

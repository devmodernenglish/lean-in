# Lean In

Solo hackathon project, ~2 hours. Nuxt (Vue 3, SPA) + WebGL2, SCSS, BEM, atomic design. All visuals are procedural and fictional (no stock images).
Taste: organic, dreamlike, obsessively smooth. Movement has weight and never snaps.

## Where things are
- `PRD.md`: the source of truth. Read it first.
- `.claude/skills/`: `moonshot-frontend` (structure, atomic design, BEM, styles), `moonshot-dev` (workflow), `moonshot-designer` (art direction), `moonshot-shader-mentor` (GLSL).
- `docs/future-ideas/`: other project ideas. Not part of this project; do not build them.

## Rules for every session
1. Read `PRD.md` first. Build the MVP only, in milestone order. Stretch items go in `TODO.md`. After each milestone make sure the app runs and summarise in 3 lines.
2. Where the PRD mentions Vite, use Nuxt (already configured as an SPA).
3. Everything lives in this project. There is no shared layer: build `GlCanvas`, `useRAF`, `useSpring` and the GLSL chunks here, as small as the PRD needs. Do not build a general toolkit.
4. Follow `moonshot-frontend` for every file: atomic folders, BEM, component-scoped SCSS, globals only in `assets/styles/`.
5. The user is a senior full-stack dev, strong in Vue/JS, NEW to shaders: write the GLSL, explain it briefly, keep everything else idiomatic Vue 3 Composition API.
6. No heavy dependencies; ask before adding any (`nuxt` and `sass` are pre-approved; `@mediapipe/tasks-vision` only for head tracking in milestone 3).
7. Always keep the mouse and scroll fallback working, going through the same smoothing as the camera input.

## Commands
`npm install`, `npm run dev`, `npm run build`.

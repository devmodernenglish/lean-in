---
name: moonshot-dev
description: Senior engineering workflow for building the hackathon prototype in Nuxt (Vue 3) + WebGL2 within a ~2 hour budget. Use whenever the user asks to build, scaffold, implement, wire up, debug, or refactor any part of this project, including composables, components, rendering loops, input handling, or performance, even if they do not say "dev" explicitly.
---

# Moonshot Dev

You are a senior engineer pairing with a fast, experienced Vue developer on a time-boxed hackathon build.

## Start of every task
1. Read `docs/PRD.md`. Identify the current milestone from its "Two-hour build plan".
2. State in one line what you are about to build and what "done" looks like.
3. If the PRD is ambiguous, pick the simplest reading, say so, and continue. Do not stall on questions.

## Architecture conventions
- Follow the `moonshot-frontend` skill for folder structure, atomic design, BEM and styles. Always.
- Nuxt in SPA mode (`ssr: false`), `<script setup>`, Composition API, plain JavaScript (JSDoc types are fine). No TypeScript unless the project already uses it.
- Logic lives in composables (`composables/useX.js`, auto-imported by Nuxt); components stay thin.
- One shared loop: `useRAF()` owns `requestAnimationFrame` and provides delta time. Never create competing loops.
- Smoothness is a feature: every user-driven value passes through `useSpring()` (critically damped spring). Never feed raw input straight into rendering.
- GLSL lives in `shaders/*.glsl` and is imported as raw strings (`import src from '~/shaders/x.frag.glsl?raw'`). Shared chunks (noise, palette, tonemap) live in `shaders/chunks/`.
- Uniforms are the only channel from Vue to GPU. Update uniforms each frame; do not recompile shaders at runtime unless the source changed.
- Handle DPR and resize in one place (`GlCanvas.vue`, an organism). Cap DPR at 2.
- Camera, WebGL and audio code is client-only (`ssr: false`, or `.client.vue` / `import.meta.client`).

## Reference implementation: critically damped spring
```js
// composables/useSpring.js: smooth a target value with weight but no overshoot
export function springStep(state, target, omega, dt) {
  const x = state.value - target;
  const exp = Math.exp(-omega * dt);
  const temp = (state.velocity + omega * x) * dt;
  state.velocity = (state.velocity - omega * temp) * exp;
  state.value = target + (x + temp) * exp;
}
```
`omega` around 6 to 12 feels good; lower is floatier.

## Working rules
- Build the smallest thing that runs, then iterate. The app must run after every milestone.
- Camera, mic, and sensors always have a mouse/keyboard fallback going through the same smoothing pipeline.
- Wrap permission-gated APIs (getUserMedia, AudioContext) in try/catch and show a calm on-screen status.
- Keep a visible debug overlay toggle (`D` key) showing FPS and raw versus smoothed inputs.
- Target 60 fps at 1080p. If a shader is heavy, reduce octaves or render at half resolution before cutting features.
- Before saying a milestone is done: run `npm run build` and check for console errors.

## Output style
- Short summaries. List files changed and how to run. No long explanations of code the user can read.
- Anything cut for time goes into `TODO.md`, not into half-working code.

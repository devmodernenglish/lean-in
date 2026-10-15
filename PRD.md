# PRD: Lean In

Brief it serves: **eccentric, futuristic, fictional.** About 2 hours, solo, Nuxt (SPA) + WebGL2.

## 1. Summary
A window into an infinitely deep procedural world. The user's head position is the only input. Moving left, right, up and down gives true parallax. Leaning toward the screen zooms the world down in scale, from a spore forest to colonies to cells to structures inside cells, endlessly.

## 2. Why it exists
The goal is a demo that makes a stranger lean toward the screen and ask "how is this made of 1s and 0s?" Head tracking is not a gimmick here: depth is something you navigate with your body, and the body is the entire interface.

## 3. Target user and context
- **Demo audience:** judges and passers-by, sitting 40 to 80 cm from a laptop.
- **Builder:** learning a clean head-pose pipeline and layered shader composition.

## 4. Core experience
1. Page opens to a calm, slowly drifting dark scene with a soft prompt: "Sit back. Now lean in."
2. Camera permission is requested. A small calibration ring captures the neutral position over about 2 seconds.
3. Head offset shifts each layer by an amount proportional to its depth, so near layers move more than far ones.
4. Head distance maps to a logarithmic zoom value. Layers scale and cross-fade so the descent loops forever without a visible seam.
5. Everything is spring-smoothed. Nothing ever snaps.

## 5. Scope
**MVP (must ship):**
- Head pose: x, y and a z proxy from MediaPipe Face Landmarker.
- 5 or 6 procedural layers, each a parameterised bioluminescent shader with its own palette and scale.
- Infinite zoom via logarithmic scale and cross-fade.
- Spring smoothing on all head inputs.
- Mouse and scroll fallback if the webcam is unavailable or denied (build this first).
- Debug overlay (toggle with `D`) showing raw versus smoothed head values.

**Out of scope:** audio, multiplayer, saved worlds, mobile, multi-face handling.

**Stretch:** depth-of-field blur by layer distance; slow generative drone that rises in pitch as you descend; palette shifts with scale.

## 6. Functional requirements
| ID | Requirement |
|---|---|
| F1 | Track the nose landmark (x, y) and inter-pupil distance in pixels at 30 fps or better. |
| F2 | Normalise the pose against a user-calibrated neutral. Distance ratio > 1 means leaning in. |
| F3 | Apply a critically damped spring to x, y and zoom, with separate tunable stiffness for each. |
| F4 | Render N layers; each layer samples its shader at `uv * layerScale + headOffset / layerDepth`. |
| F5 | Zoom is `exp(k * leanRatio)`. Layer i is shown at scale `zoom / 2^i`, wrapping so the nearest layer fades out as a new far layer fades in. |
| F6 | If tracking is lost for more than 500 ms, the spring eases to neutral rather than freezing. |
| F7 | Fallback input (mouse position plus scroll wheel) uses the same spring pipeline. |

## 7. Technical approach
**Stack:** Nuxt (SPA), Vue 3, WebGL2, `@mediapipe/tasks-vision`. Cache the model file in `public/`.

**Component map (atomic design):**
- atoms: `GlowText`, `StatusDot`
- molecules: `HintLine`, `CalibrationRing`, `Stratum` (renderless: registers a layer with its parent via `provide/inject`)
- organisms: `GlCanvas` (WebGL2 canvas: compiles a fragment shader, exposes uniforms, handles resize and DPR), `DreamWorld` (layer loop, composite), `DebugOverlay`
- composables: `useHeadPose()` returns `{ x, y, z, tracking }` (normalised -1 to 1, z as lean ratio); `useSpring()` (critically damped spring); `useRAF()` (one shared animation loop with delta time)

**Rendering:** start with ONE full-screen pass whose shader loops over the layers internally (no framebuffer management). Move to one pass per layer only if needed.

## 8. Shader specs
**`glowLayer.frag.glsl`**
- Inputs: `uv`, `time`, `uHeadOffset`, `uDepth`, `uScale`, `uSeed`, `uPalette[4]`.
- Domain-warped fbm: `q = fbm(p + seed)`, `r = fbm(p + 4q + time*0.03)`, `v = fbm(p + 4r)`.
- Thin bright filaments via `pow(1.0 - abs(v * 2.0 - 1.0), 6.0)`, plus a soft body glow from `smoothstep` on `v`.
- Colour from a cosine palette indexed by `v` and `r`. Output premultiplied additive RGB, alpha driven by layer fade.

**`composite.frag.glsl`**
- Sums layers, applies depth haze (`mix` toward deep blue-black by layer index), a gentle vignette, filmic tonemapping and a touch of dither.

## 9. Two-hour build plan
| Time | Milestone |
|---|---|
| 0:00 to 0:30 | Nuxt scaffold, `useRAF`, `useSpring`, `GlCanvas`, GLSL chunks (noise, palette, tonemap), one `glowLayer` shader on screen. |
| 0:30 to 0:55 | Mouse fallback driving parallax via `useSpring`; stack of layers. |
| 0:55 to 1:25 | `useHeadPose` with MediaPipe, calibration, wire z to zoom. |
| 1:25 to 1:45 | Infinite-zoom wrapping and cross-fade; tune the feel. |
| 1:45 to 2:00 | Polish, debug overlay, demo script, README. |

Keep the foundation minimal: build only what this project needs.

## 10. Success criteria
- A stranger understands the interaction in under 5 seconds without instructions.
- No visible jitter at rest; zoom never pops or snaps.
- 60 fps on a modern laptop at 1080p.
- Works with the mouse fallback if the camera fails.

## 11. Risks and mitigations
| Risk | Mitigation |
|---|---|
| Head-pose jitter | Spring smoothing plus a 1-Euro filter on raw landmarks. |
| Noisy z estimate | Use inter-pupil distance ratio, clamp the range, dead zone near neutral. |
| Seams in infinite zoom | Wrap by whole octaves and cross-fade across the overlap. |
| Model download needs network | Cache the model file locally in `public/`. |

> **Future idea, not part of Lean In.** Written for a monorepo with a shared `layers/core`. If you build it as its own project, create its own `useSpring`, `useRAF` and `GlCanvas` instead.

# PRD: Shader Seedbed

Brief it serves: **personal tool that teaches you something.** About 2 hours, solo, Nuxt (SPA) + WebGL2.

## 1. Summary
A playground where you grow organic shaders instead of writing them from a blank file. Pick a "seed" (domain-warped flow, bioluminescent filaments, caustics, optionally reaction-diffusion), tweak auto-generated controls, and read a line-by-line explanation of what each part does. When it feels right, export it as a ready-to-use Vue component.

## 2. Why it exists
You want to learn shaders but have no time to study. This turns learning into play: every parameter is a slider, every slider is linked to the exact GLSL lines it affects, and every result is reusable. It is also the factory that builds the shared foundation in `layers/core` for Lean In and The Reef.

## 3. Target user
You: a senior full-stack developer who thinks in components and props, not GLSL. Secondary: any Vue developer wanting a friendly way into shaders.

## 4. Core experience
1. A gallery of seeds shown as live thumbnails.
2. Choose one and see it full-screen with a side panel.
3. The panel has auto-generated sliders and colour pickers, one per annotated `uniform`.
4. Hover a slider and the GLSL lines it controls highlight in a code view, with a one-sentence explanation beside them.
5. "Mutate" nudges all parameters randomly; "Breed" blends two seeds' parameters. Save favourites as presets.
6. "Export" produces a `.vue` component with the shader inlined and its uniforms as props.

## 5. Scope
**MVP:**
- `GlCanvas` (in `layers/core`) that compiles a fragment shader and binds uniforms.
- Uniform annotation format: `uniform float uWarp; // @slider 0..4 default 1.5 "How strongly the pattern folds into itself"`.
- A parser that reads the annotations and auto-builds the control panel.
- 3 seeds: domain-warp flow, bioluminescent filaments, caustic water.
- Hover-to-highlight linking sliders to code lines via `// @uses uWarp` markers.
- Mutate button and `localStorage` presets.
- Export to a `.vue` single-file component.
- **Shared foundation, built here in `layers/core`:** `useSpring`, `useRAF`, `GlCanvas`, and GLSL chunks `noise.glsl`, `palette.glsl`, `tonemap.glsl`.

**Out of scope:** a full GLSL editor with autocomplete, accounts, sharing, WebGPU.

**Stretch:** a "Feel Lab" tab for tuning `useSpring` parameters with a live bouncing demo; a reaction-diffusion seed with ping-pong framebuffers; record a 5-second loop to WebM with `MediaRecorder`.

## 6. Functional requirements
| ID | Requirement |
|---|---|
| F1 | Any shader following the annotation format produces a working control panel with no extra code. |
| F2 | Compile errors display inline with the line number and never crash the app. |
| F3 | Parameter changes apply in real time with no recompilation (uniform updates only). |
| F4 | Hovering a control highlights the annotated lines and shows its explanation. |
| F5 | Presets save and load via `localStorage`. |
| F6 | Export output runs standalone in a fresh Vue 3 / Nuxt project. |

## 7. Technical approach
**Stack:** Nuxt (SPA), Vue 3, WebGL2, SCSS.

**Component map (atomic design):**
- atoms: `ColorInput`, `GlowText`
- molecules: `ControlSlider`, `SeedThumb`, `ExplainNote`
- organisms: `GlCanvas` (core layer), `ControlPanel`, `CodeView`, `SeedGallery`
- composables / utils: `useShader(source)` (compile, cache, `setUniform`), `parseUniforms(source)` returns `{ name, type, min, max, default, label }[]`, `exportComponent(seed, values)` fills a `.vue` template string

**Seed library (each about 40 to 80 lines of GLSL):**
1. **Mycelium Flow:** domain-warped fbm, thin filament extraction, cosine palette.
2. **Deep Bloom:** layered radial blobs with slow breathing and additive glow.
3. **Caustic Pool:** animated cellular noise folded into bright caustic lines.
4. **Gray-Scott (stretch):** ping-pong reaction-diffusion with feed and kill sliders.

## 8. Two-hour build plan
| Time | Milestone |
|---|---|
| 0:00 to 0:25 | `GlCanvas`, `useRAF`, `useSpring`, first seed rendering, shared GLSL chunks (all in `layers/core`). |
| 0:25 to 0:55 | Uniform parser and auto-generated control panel. |
| 0:55 to 1:20 | Code view with hover-to-highlight and explanations. |
| 1:20 to 1:45 | Remaining seeds, Mutate, presets. |
| 1:45 to 2:00 | Export to `.vue`, README, tidy `layers/core` for reuse. |

## 9. Success criteria
- Adding a seed needs only a shader with annotations, with no app code changes.
- After two hours you can explain fbm, domain warping and a cosine palette in your own words.
- You reuse the exported pieces and core layer in Lean In and The Reef.

## 10. Risks and mitigations
| Risk | Mitigation |
|---|---|
| Scope creep into a full editor | Read-only code view in v1; edit shaders in your own editor with hot reload. |
| Annotation parsing edge cases | Support only float, vec3 colour and bool in v1. |
| Seeds look generic | Spend polish time on palettes and tonemapping, not extra features. |

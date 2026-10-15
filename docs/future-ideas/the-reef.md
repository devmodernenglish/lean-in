> **Future idea, not part of Lean In.** Written for a monorepo with a shared `layers/core`. If you build it as its own project, create its own `useSpring`, `useRAF` and `GlCanvas` instead.

# PRD: The Reef

Brief it serves: **resellable product / company tooling.** About 2 hours, solo, Nuxt (SPA) + Three.js + Web Audio.

## 1. Summary
A bioluminescent jellyfish colony drifting in dark water, where each creature type is bound to a real metric. A calm, beautiful alternative to a conventional dashboard for ops walls, lobbies and personal second screens.

## 2. Why it exists
Dashboards are dense and stressful to look at. Ambient displays communicate system health at a glance and are pleasant to live with. Product thesis: **health you can feel from across the room.**

## 3. Target user and context
- **Buyer:** engineering and ops teams, studios, offices with a lobby or wall display.
- **Viewer:** anyone in the room, glancing for under two seconds.
- **Integrator:** a developer binding metrics with a few lines of Vue.

## 4. Core experience
1. A dark ocean with about 150 jellyfish pulsing softly, with gentle boid-style drift.
2. Each species maps to a metric. Healthy means synchronised, evenly lit pulses and a slow warm drone. Stress means rapid, ragged pulses and a shift toward warm reds. Outage or silence means creatures dim and sink.
3. Demo metrics come from your real session: typing rate, tab focus, idle time. Typing in rhythm makes the colony bloom and synchronise; stopping makes it sleep.
4. Metrics can also be simulated from a control panel so a judge can drag a slider and watch the reef react.

## 5. Scope
**MVP:**
- Three.js scene with an `InstancedMesh` of about 150 bells.
- Bell-pulse vertex shader with per-instance phase; fresnel rim-glow fragment shader.
- Boids on the CPU (separation, alignment, cohesion, soft depth range).
- Declarative Vue API binding metrics to species.
- Real input (typing rate, focus, idle) and simulated input (sliders).
- Web Audio: a soft generative chord whose brightness follows colony state (opt-in button).

**Out of scope:** real backend integrations (Prometheus, Datadog), auth, persistence, multi-screen sync.

**Stretch:** a `<ReefMetric url="...">` that polls a JSON endpoint; marine snow particles and caustic light rays.

## 6. Functional requirements
| ID | Requirement |
|---|---|
| F1 | `<Reef>` hosts the scene; `<Jelly species :metric :count>` registers a group of creatures. |
| F2 | Each metric is normalised to 0 to 1 and smoothed through `useSpring`. |
| F3 | Metric value controls pulse rate, phase coherence, brightness and hue. |
| F4 | Zero input for 10 seconds triggers the "sleep" state: dim, slow, sinking. |
| F5 | A settings drawer exposes simulated sliders and a palette selector. |
| F6 | Audio is opt-in via a single button (browsers require a gesture). |

## 7. Technical approach
**Stack:** Nuxt (SPA), Vue 3, Three.js (dependency of this app only), Web Audio API.

**Component map (atomic design):**
- atoms: `GlowText`, `StatusDot`, `IconButton`
- molecules: `ControlSlider`, `PaletteSwatch`, `Jelly` (renderless: registers a species with the scene via `provide/inject`)
- organisms: `Reef` (renderer, camera, loop, provides context), `SettingsDrawer`
- composables: `useTypingRate()`, `useFocusIdle()`, `useColonyAudio(stateRef)`, plus `useSpring` / `useRAF` from `layers/core`

**Creature geometry:** `LatheGeometry` bell profile, plus 4 to 6 trailing tentacles as thin instanced ribbons, or a cheaper vertex-shader fake of trailing filaments.

**Audio:** three detuned sine or triangle oscillators through a filter whose cutoff follows colony vitality.

## 8. Shader specs
**`bell.vert.glsl`**
- Per-instance attributes: `aPhase`, `aSpeed`, `aSize`. Uniform `uCoherence` (0 random, 1 perfectly synchronised) and `uBaseSpeed`.
- Pulse: `float speed = mix(aSpeed, uBaseSpeed, uCoherence); float phase = mix(aPhase, 0.0, uCoherence); float p = sin(time * speed + phase * 6.2831);`
- Contract the bell radius by `1.0 - 0.18 * max(p, 0.0)` and push vertices slightly upward on contraction.
- Add small noise displacement near the rim so edges wobble organically.

**`bell.frag.glsl`**
- Fresnel rim: `pow(1.0 - dot(N, V), 2.5)`.
- Core glow by `uBrightness`, rim colour from the species palette, faint internal veins from low-frequency noise.
- Additive blending, no depth write.

## 9. Two-hour build plan
| Time | Milestone |
|---|---|
| 0:00 to 0:20 | Three.js scene in `Reef`, one pulsing bell. |
| 0:20 to 0:50 | Instancing, boids, per-instance phase. |
| 0:50 to 1:15 | Rim-glow shader, additive blending, haze, camera drift. |
| 1:15 to 1:40 | Metric binding, typing and idle composables, sleep state. |
| 1:40 to 2:00 | Audio, settings drawer, polish, README with API examples. |

## 10. Success criteria
- The colony visibly changes state within 1 second of a metric change, yet never jerks.
- A viewer can tell "healthy" from "stressed" without being told.
- Integration snippet is 5 lines of Vue or fewer.
- 60 fps with 150 instances.

## 11. Risks and mitigations
| Risk | Mitigation |
|---|---|
| Lower raw technical wow | Lean on mood, audio and the live sleep/wake moment in the demo. |
| Boids cost | 150 agents on CPU is trivial; add a uniform grid only beyond 500. |
| Looks like a screensaver | Always show the metric binding in the demo, ideally with a judge driving a slider. |

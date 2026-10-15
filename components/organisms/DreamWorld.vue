<template>
  <div class="dream-world">
    <GlCanvas :fragment="glowLayerSrc" :uniforms="uniforms" :max-dpr="1" @frame="onFrame" />
    <CalibrationRing class="dream-world__ring" :progress="progress" :visible="status === 'calibrating'" />
    <HintLine class="dream-world__hint" :text="hint" />
    <StatusDot class="dream-world__status" :live="status === 'tracking'" :label="statusLabel" />
  </div>
</template>

<script setup>
import glowLayerSrc from '~/shaders/glowLayer.frag.glsl?raw'
import { createDiveCamera } from '~/utils/diveCamera'

// Realms cycle one per level: every bubble you dive into opens onto the next realm. Length must match REALMS
// in the shader. Colours are linear RGB (the shader tonemaps at the end):
// deep = the depths, shallow = toward the light above, light = shafts / highlights / caustics, accent = bioluminescence.
// shape: [light shafts, spire density, particles, bioluminescence] strengths.
const REALMS = [
  { // Electric blue: deep cobalt water, icy cyan light, hot-pink bioluminescence
    deep: [0.004, 0.010, 0.045], shallow: [0.03, 0.10, 0.42], light: [0.45, 0.78, 1.0], accent: [1.0, 0.3, 0.85],
    shape: [1.0, 0.6, 1.0, 0.7],
  },
  { // Ultraviolet: violet water, lavender light, cyan plankton
    deep: [0.014, 0.005, 0.040], shallow: [0.16, 0.05, 0.34], light: [0.85, 0.62, 1.0], accent: [0.2, 0.95, 1.0],
    shape: [0.9, 0.5, 1.2, 1.0],
  },
  { // Neon lagoon: cyan-green water, mint light, pink sparks
    deep: [0.003, 0.030, 0.030], shallow: [0.02, 0.26, 0.24], light: [0.5, 1.0, 0.85], accent: [1.0, 0.35, 0.7],
    shape: [1.1, 0.7, 0.9, 0.8],
  },
]

const PARALLAX = 1 // head offset scale; each layer's own parallax factor is the `par` argument of layerP() in the shader
const DESCENT_SPEED = 0.35 // octaves per second at lean 1 (a bubble is ~3-5 octaves deep): leaning sets the speed of the dive
const LEAN_ZOOM = 0.5 // octaves of instant zoom per unit of lean, so leaning responds immediately
const IDLE_DESCENT = 0.02 // octaves per second with no input: the nearest bubble is always slowly drawing you in
const MOUTH_DIVE = 0.6 // extra lean-equivalent while the mouth is open: breathe in to dive
const OMEGA_XY = 3 // spring stiffness: lower = floatier
const OMEGA_Z = 2.2
const POINTER_OVERRIDE_MS = 2000 // mouse/scroll takes over for this long after use when no face is seen
const LEANED_IN = 0.4 // smoothed lean that counts as "they got it": hides the prompt

// Idle drift: a slow Lissajous wander in screen units. Periods ~50 s and ~70 s so it never visibly loops.
const DRIFT_AMP = 0.3
const DRIFT_SPEED = [0.12, 0.09]

const NEUTRAL = { x: 0, y: 0, z: 0 }

// Head pose first, so its detection runs before the springs step each frame
const head = useHeadPose()
const { status, progress } = head
const pointer = usePointerInput()
const mood = useMood(head)
const gestures = useGestures(head)

// Preview params for screenshots / demos: ?fade=1&descent=3.6 skips the fade-in and starts zoomed in that many
// octaves (negative = out); ?steer=-0.6,0 holds the steering (head / mouse x, y) fixed
const params = new URLSearchParams(window.location.search)
const fixedSteer = params.has('steer') ? params.get('steer').split(',').map(Number) : null

const x = useSpring(fixedSteer?.[0] || 0, OMEGA_XY) // a fixed ?steer= starts already there, matching the replayed dive
const y = useSpring(fixedSteer?.[1] || 0, OMEGA_XY)
const z = useSpring(0, OMEGA_Z)

// Glow eases in from black on load instead of popping
const fade = useSpring(params.has('fade') ? Number(params.get('fade')) : 0, 1.4)
fade.target = 1

// The camera through the endless chain of bubble worlds (see utils/diveCamera.js)
const dive = createDiveCamera()
const aspect = () => window.innerWidth / Math.max(window.innerHeight, 1)

// An intentional blink (long or double) carries you smoothly into the bubble you are heading for
const jump = useSpring(0, 1.6)
gestures.onIntent(() => {
  jump.target += dive.octavesToTarget(aspect()) + 0.3
})

const hasLeaned = ref(false)

const hint = computed(() => {
  switch (status.value) {
    case 'loading': return 'Sit back.'
    case 'calibrating': return 'Sit back. Hold still.'
    case 'lost': return 'Come back into view.'
    case 'unavailable': return hasLeaned.value ? '' : 'No camera. Move the mouse, scroll to lean in.'
    default: return hasLeaned.value ? '' : 'Now lean in.'
  }
})
const statusLabel = computed(() => (status.value === 'tracking' ? 'Head tracking' : 'Mouse and scroll'))

/** Head when a face is seen; otherwise the mouse if it was just used (or there is no camera); otherwise rest. */
function currentInput(now) {
  if (fixedSteer) return { x: fixedSteer[0] || 0, y: fixedSteer[1] || 0, z: 0 }
  if (head.tracking) return head
  const cameraUp = status.value !== 'unavailable' && status.value !== 'loading'
  if (!cameraUp || now - pointer.lastActive < POINTER_OVERRIDE_MS) return pointer
  return NEUTRAL
}

const uniforms = {
  uHeadOffset: new Float32Array(2),
  uLook: new Float32Array(2),
  uRoot: new Float32Array(2), // (seed, level) of the world the shader starts drawing from
  uCam: new Float32Array(3), // camera centre x, y and scale, in that world's units
  uTarget: -1, // seed of the bubble you are heading into
  uCue: 0, // 0..1 how strongly to mark it
  uRealm: new Float32Array(REALMS.flatMap((r) => [...r.deep, ...r.shallow, ...r.light, ...r.accent])),
  uShape: new Float32Array(REALMS.flatMap((r) => r.shape)),
  uMood: mood.value,
  uGesture: gestures.value,
  uFade: 0,
  uTime: 0, // overrides GlCanvas's clock with the mood-scaled one below
}

let worldTime = 0 // ambient clock: mood speeds it up or slows it down without ever jumping

// Start zoomed in (or out) by ?descent= octaves: replay the dive in small steps so magnetism centres the bubbles
const startHead = [(fixedSteer?.[0] || 0) * PARALLAX, (fixedSteer?.[1] || 0) * PARALLAX + Math.sin(1.3) * DRIFT_AMP]
const startOct = Number(params.get('descent')) || 0
for (let done = 0; Math.abs(done) < Math.abs(startOct);) {
  const step = Math.sign(startOct) * Math.min(0.012, Math.abs(startOct - done)) // ~ a full lean at 30 fps
  dive.advance(1 / 30, { steer: fixedSteer || [0, 0], zoom: step, head: startHead, time: 0, aspect: aspect() })
  done += step
}

let lastZ = 0
let lastJump = 0

function onFrame({ dt, time }) {
  const input = currentInput(performance.now())
  x.target = input.x
  y.target = input.y
  z.target = input.z
  if (!hasLeaned.value && z.value > LEANED_IN) hasLeaned.value = true

  uniforms.uHeadOffset[0] = x.value * PARALLAX + Math.sin(time * DRIFT_SPEED[0]) * DRIFT_AMP
  uniforms.uHeadOffset[1] = y.value * PARALLAX + Math.sin(time * DRIFT_SPEED[1] + 1.3) * DRIFT_AMP
  uniforms.uLook[0] = x.value
  uniforms.uLook[1] = y.value
  worldTime += dt * mood.timeScale
  uniforms.uTime = worldTime

  // Lean sets the speed of the dive; changes in lean (and a blink's jump) also zoom directly, for immediacy
  const zoom = (IDLE_DESCENT + DESCENT_SPEED * (z.value + MOUTH_DIVE * gestures.descentBoost)) * mood.descentScale * dt
    + LEAN_ZOOM * (z.value - lastZ) + (jump.value - lastJump)
  lastZ = z.value
  lastJump = jump.value
  const pull = Math.min(Math.max(jump.target - jump.value, 0), 1)
  dive.advance(dt, { steer: [x.value, y.value], zoom, head: uniforms.uHeadOffset, time: worldTime, aspect: aspect(), pull })
  dive.write(uniforms, worldTime, uniforms.uHeadOffset)
  uniforms.uFade = fade.value
}

// C recalibrates the neutral pose (handy when someone new sits down)
const onKey = (e) => e.key.toLowerCase() === 'c' && head.recalibrate()
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<style lang="scss" scoped>
.dream-world {
  position: fixed;
  inset: 0;
  background: $color-base;

  &__ring {
    position: absolute;
    top: 50%;
    left: 50%;
    margin: rem(-60) 0 0 rem(-60);
    pointer-events: none;
  }
  &__hint {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 18vh;
    pointer-events: none;
  }
  &__status {
    position: absolute;
    left: space(3);
    bottom: space(3);
  }
}
</style>

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

// Realms cycle as you descend: sea -> forest -> cosmos -> sea ... Length must match REALMS in the shader.
// palette: cosine palette (a, b, c, d). shape: [creature body, eye/highlight, web, nebula] strengths.
const REALMS = [
  { // Sea: lantern-drifters
    palette: [0.15, 0.35, 0.45, 0.15, 0.30, 0.35, 1.0, 1.0, 1.0, 0.60, 0.65, 0.70],
    shape: [1.0, 0.9, 0.3, 0.5],
  },
  { // Forest: spore-lanterns on a mycelium web
    palette: [0.40, 0.25, 0.45, 0.35, 0.20, 0.30, 1.0, 1.0, 0.5, 0.80, 0.90, 0.30],
    shape: [0.9, 0.9, 0.8, 0.3],
  },
  { // Cosmos: coral-stars in nebula
    palette: [0.55, 0.35, 0.25, 0.40, 0.30, 0.25, 1.0, 1.0, 1.0, 0.00, 0.10, 0.20],
    shape: [1.0, 0.9, 0.4, 1.0],
  },
]

const PARALLAX = 0.22 // screen units the nearest layer shifts at full input
const DESCENT_SPEED = 0.35 // octaves per second at lean 1: leaning sets the speed of the fall, so it never ends
const LEAN_ZOOM = 0.5 // octaves of instant zoom per unit of lean, so leaning responds immediately
const IDLE_DESCENT = 0.015 // octaves per second with no input: the world is always slowly arriving
const OMEGA_XY = 3 // spring stiffness: lower = floatier
const OMEGA_Z = 2.2
const POINTER_OVERRIDE_MS = 2000 // mouse/scroll takes over for this long after use when no face is seen
const LEANED_IN = 0.4 // smoothed lean that counts as "they got it": hides the prompt

// Idle drift: a slow Lissajous wander in screen units. Periods ~50 s and ~70 s so it never visibly loops.
const DRIFT_AMP = 0.08
const DRIFT_SPEED = [0.12, 0.09]

const NEUTRAL = { x: 0, y: 0, z: 0 }

// Head pose first, so its detection runs before the springs step each frame
const head = useHeadPose()
const { status, progress } = head
const pointer = usePointerInput()
const mood = useMood(head)
const gestures = useGestures(head)

// Preview params for screenshots / demos: ?fade=1&descent=3.6 skips the fade-in and starts at a depth
const params = new URLSearchParams(window.location.search)

const x = useSpring(0, OMEGA_XY)
const y = useSpring(0, OMEGA_XY)
const z = useSpring(0, OMEGA_Z)

// Glow eases in from black on load instead of popping
const fade = useSpring(params.has('fade') ? Number(params.get('fade')) : 0, 1.4)
fade.target = 1

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
  if (head.tracking) return head
  const cameraUp = status.value !== 'unavailable' && status.value !== 'loading'
  if (!cameraUp || now - pointer.lastActive < POINTER_OVERRIDE_MS) return pointer
  return NEUTRAL
}

const uniforms = {
  uHeadOffset: new Float32Array(2),
  uLook: new Float32Array(2),
  uDescent: 0,
  uBaseScale: 1.5,
  uPalette: new Float32Array(REALMS.flatMap((r) => r.palette)),
  uShape: new Float32Array(REALMS.flatMap((r) => r.shape)),
  uMood: mood.value,
  uGesture: gestures.value,
  uFade: 0,
}

let descent = Number(params.get('descent')) || 0 // octaves travelled; unbounded in both directions

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
  descent += (IDLE_DESCENT + DESCENT_SPEED * z.value) * dt
  uniforms.uDescent = descent + LEAN_ZOOM * z.value
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

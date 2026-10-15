<template>
  <div class="dream-world">
    <GlCanvas :fragment="glowLayerSrc" :uniforms="uniforms" :max-dpr="1" @frame="onFrame" />
    <div v-if="cameraVisible && cameraStream" class="dream-world__reflection" aria-hidden="true">
      <video ref="reflectionVideo" class="dream-world__video" autoplay muted playsinline />
    </div>
    <span v-if="cameraVisible && cameraStream && !introOpen" class="dream-world__tracking-readout">{{ handReadout }}</span>
    <ExperienceIntro v-if="introOpen" :status="status" :progress="progress" @enable="head.start()" @enter="introOpen = false" />
    <div v-else class="dream-world__controls">
      <button class="dream-world__help" type="button" :aria-pressed="cameraVisible" :disabled="status === 'loading'" @click="toggleCameraView">{{ cameraVisible ? 'Hide camera view' : 'Show camera view' }}</button>
      <button class="dream-world__help" type="button" @click="introOpen = true">How to explore <span aria-hidden="true">↗</span></button>
    </div>
    <p v-if="!introOpen && cameraMessage" class="dream-world__camera-message" role="status">{{ cameraMessage }}</p>
    <CalibrationRing class="dream-world__ring" :progress="progress" :visible="!introOpen && status === 'calibrating'" />
    <HintLine class="dream-world__hint" :text="introOpen ? '' : hint" />
    <StatusDot class="dream-world__status" :live="status === 'tracking' || hands.status.value === 'tracking'" :label="statusLabel" />
  </div>
</template>

<script setup>
import glowLayerSrc from '~/shaders/glowLayer.frag.glsl?raw'
import { createDiveCamera } from '~/utils/diveCamera'
import { createDiscoveryHints } from '~/utils/discoveryHints'

// Bubbles open into different electric deep-sea worlds. Length must match REALMS
// in the shader. Colours are linear RGB (the shader tonemaps at the end):
// deep = the depths, shallow = toward the light above, light = shafts / highlights / caustics, accent = bioluminescence.
// shape: [light shafts, spire density, particles, bioluminescence] strengths.
const REALMS = [
  { // Neon pink: fuchsia water and violet bioluminescence
    deep: [0.045, 0.002, 0.025], shallow: [0.48, 0.012, 0.20], light: [1.0, 0.18, 0.65], accent: [0.6, 0.15, 1.0],
    shape: [1.3, 0.08, 0.45, 0.8],
  },
  { // Abyssal violet: fine cyan bioluminescence and lavender light
    deep: [0.018, 0.002, 0.065], shallow: [0.22, 0.015, 0.62], light: [0.72, 0.25, 1.0], accent: [0.20, 0.8, 1.0],
    shape: [0.25, 1.3, 1.4, 1.1],
  },
  { // Electric green: neon emerald reef with acid-lime growths
    deep: [0.002, 0.035, 0.006], shallow: [0.035, 0.52, 0.012], light: [0.18, 1.0, 0.08], accent: [0.7, 1.0, 0.02],
    shape: [0.9, 0.45, 0.7, 1.3],
  },
  { // Radioactive yellow: sulphur plumes and chartreuse creatures
    deep: [0.035, 0.028, 0.001], shallow: [0.42, 0.38, 0.004], light: [1.0, 0.95, 0.04], accent: [0.6, 1.0, 0.015],
    shape: [0.12, 0.8, 1.5, 1.4],
  },
  { // Rose silk: open plum water crossed by flowing translucent membranes
    deep: [0.035, 0.002, 0.018], shallow: [0.40, 0.018, 0.12], light: [1.0, 0.26, 0.48], accent: [0.85, 0.12, 1.0],
    shape: [0.4, 0.0, 0.25, 0.9],
  },
  { // Ice cathedral: pale glacial water and sharp crystalline growths
    deep: [0.008, 0.026, 0.045], shallow: [0.11, 0.28, 0.36], light: [0.72, 0.94, 1.0], accent: [0.4, 0.7, 1.0],
    shape: [1.5, 0.15, 0.65, 0.6],
  },
]

const PARALLAX = 0.6 // head offset scale; each layer's own parallax factor is the `par` argument of layerP() in the shader
const DESCENT_SPEED = 0.35 // octaves per second at lean 1 (a bubble is ~3-5 octaves deep): leaning sets the speed of the dive
const LEAN_ZOOM = 0.5 // octaves of instant zoom per unit of lean, so leaning responds immediately
const IDLE_DESCENT = 0.02 // octaves per second with no input: the nearest bubble is always slowly drawing you in
const MOUTH_DIVE = 0.6 // extra lean-equivalent while the mouth is open: breathe in to dive
const OMEGA_XY = 2 // spring stiffness: lower = floatier (the dive camera adds its own water glide on top)
const OMEGA_Z = 2.2
const POINTER_OVERRIDE_MS = 2000 // mouse/scroll takes over for this long after use when no face is seen

// Idle drift: a slow Lissajous wander in screen units. Periods ~50 s and ~70 s so it never visibly loops.
const DRIFT_AMP = 0.3
const DRIFT_SPEED = [0.12, 0.09]

const NEUTRAL = { x: 0, y: 0, z: 0 }

// Head pose first, so its detection runs before the springs step each frame
const head = useHeadPose()
const { status, progress, cameraStream } = head
const introOpen = ref(true)
const cameraVisible = ref(false)
const reflectionVideo = ref(null)
const cameraMessage = computed(() => {
  if (!cameraVisible.value) return ''
  if (status.value === 'unavailable') return 'Camera unavailable. Allow camera access in your browser and try again.'
  if (!cameraStream.value) return 'Connecting to your camera…'
  return ''
})

async function toggleCameraView() {
  if (cameraVisible.value) {
    cameraVisible.value = false
    return
  }
  cameraVisible.value = true
  await head.start()
}

watchEffect(() => {
  const video = reflectionVideo.value
  if (video) {
    video.srcObject = cameraStream.value
    video.play().catch(() => {})
  }
}, { flush: 'post' })
const handsEnabled = computed(() => !introOpen.value)
const hands = useHands(head, handsEnabled)
const discovery = createDiscoveryHints()
const handReadout = computed(() => {
  if (hands.status.value === 'loading') return 'Finding your hands…'
  if (hands.status.value === 'unavailable') return 'Hand tracking unavailable'
  const labels = { together: 'Hands together', push: 'Push forward', sweep: 'Apart and back', swimming: 'Swimming' }
  return `${hands.handCount.value} hands detected · ${labels[hands.swimPhase.value]}`
})
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
const swimJump = useSpring(0, 3.8)
hands.onSwim(() => {
  discovery.record('swim')
  // Finish one surge before accepting another, even if another stroke is detected.
  if (swimJump.target - swimJump.value > 0.1) return
  swimJump.target += dive.octavesToTarget(aspect()) + 0.35
})
gestures.onIntent(() => {
  if (!introOpen.value) discovery.record('blink')
  jump.target += dive.octavesToTarget(aspect()) + 0.3
})

const discoveryHint = ref('')
const cameraHints = ['A little closer?', 'What if you made a face?', 'Let your hands wander.']
const mouseHints = ['Follow your curiosity.', 'A little movement?', 'Scroll a little deeper.']
let previousPose = null

gestures.onWink(() => { if (!introOpen.value) discovery.record('wink') })

const hint = computed(() => {
  switch (status.value) {
    case 'loading': return 'Sit back.'
    case 'calibrating': return 'Sit back. Hold still.'
    case 'lost': return hands.status.value === 'tracking' ? '' : 'Come back into view.'
    default: return discoveryHint.value
  }
})
const statusLabel = computed(() => hands.status.value === 'tracking' ? 'Hand tracking' : status.value === 'tracking' ? 'Head tracking' : 'Mouse and scroll')

/** Head when a face is seen; otherwise the mouse if it was just used (or there is no camera); otherwise rest. */
function currentInput(now) {
  if (fixedSteer) return { x: fixedSteer[0] || 0, y: fixedSteer[1] || 0, z: 0 }
  if (head.tracking) return head
  const cameraUp = !['idle', 'unavailable', 'loading'].includes(status.value)
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
  uPalm: hands.palm,
  uHandMotion: hands.motion,
  uHandAnchor: hands.anchor,
  uHandTrail: hands.trail,
  uHandBurst: hands.burst,
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
dive.snapView()

let lastZ = 0
let lastJump = 0
let lastSwimJump = 0

function onFrame({ dt, time }) {
  if (!introOpen.value && !['loading', 'calibrating', 'lost'].includes(status.value) && !document.hidden) {
    const kinds = []
    if (head.tracking) {
      if (previousPose && Math.hypot(head.x - previousPose.x, head.y - previousPose.y, head.z - previousPose.z) > 0.025) kinds.push('movement')
      previousPose = { x: head.x, y: head.y, z: head.z }
      if (Math.max(...mood.value) > 0.35 || gestures.value[1] > 0.3) kinds.push('expression')
    } else {
      previousPose = null
      if (performance.now() - pointer.lastActive < 150) kinds.push('movement')
    }
    if (hands.palm[2] > 0.5 && (Math.hypot(hands.motion[0], hands.motion[1]) > 0.12 || hands.motion[3] > 0.5)) kinds.push('hands')
    const index = discovery.step(dt, kinds)
    discoveryHint.value = index < 0 ? '' : (head.tracking ? cameraHints : mouseHints)[index]
  } else {
    previousPose = null
    discoveryHint.value = ''
  }
  const input = currentInput(performance.now())
  x.target = input.x
  y.target = input.y
  z.target = input.z

  uniforms.uHeadOffset[0] = x.value * PARALLAX + Math.sin(time * DRIFT_SPEED[0]) * DRIFT_AMP
  uniforms.uHeadOffset[1] = y.value * PARALLAX + Math.sin(time * DRIFT_SPEED[1] + 1.3) * DRIFT_AMP
  uniforms.uLook[0] = x.value
  uniforms.uLook[1] = y.value
  worldTime += dt * mood.timeScale
  uniforms.uTime = worldTime

  // Lean sets the speed of the dive; changes in lean (and a blink's jump) also zoom directly, for immediacy
  const zoom = (IDLE_DESCENT + DESCENT_SPEED * (z.value + MOUTH_DIVE * gestures.descentBoost)) * mood.descentScale * dt
    + LEAN_ZOOM * (z.value - lastZ) + (jump.value - lastJump) + (swimJump.value - lastSwimJump)
  lastZ = z.value
  lastJump = jump.value
  lastSwimJump = swimJump.value
  const pull = Math.min(Math.max(jump.target - jump.value, swimJump.target - swimJump.value, 0), 1)
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

  &__reflection {
    position: absolute;
    inset: 0;
    pointer-events: none;
    overflow: hidden;
    opacity: .38;
    mix-blend-mode: screen;
    mask-image: radial-gradient(ellipse at center, #000 20%, transparent 80%);
    &::after {
      content: '';
      position: absolute;
      inset: 0;
      background: linear-gradient(135deg, #32d9e6, #7060d9 55%, #e77bc5);
      mix-blend-mode: color;
    }
  }
  &__tracking-readout {
    position: absolute;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    padding: 7px 10px;
    border-radius: 8px;
    background: #030812cc;
    color: $color-text;
    font-size: 10px;
    text-align: center;
    pointer-events: none;
  }
  &__video {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transform: scaleX(-1);
    filter: grayscale(1) contrast(1.2) brightness(.85);
  }
  &__controls {
    position: absolute;
    top: 24px;
    right: 24px;
    left: 24px;
    display: flex;
    justify-content: flex-end;
    flex-wrap: wrap;
    gap: 10px;
  }
  &__camera-message {
    position: absolute;
    top: 84px;
    right: 24px;
    left: 24px;
    text-align: right;
    color: $color-text;
    font-size: 12px;
  }
  &__help {
    border: 1px solid #cfe3ff30;
    border-radius: 30px;
    padding: 12px 18px;
    background: #09122299;
    color: $color-text;
    cursor: pointer;
    font: inherit;
    font-size: 12px;
    &[aria-pressed='true'] { border-color: #aee9ee99; background: #244859bb; }
    &:disabled { opacity: .6; cursor: wait; }
    &:focus-visible { outline: 2px solid #aee9ee; outline-offset: 4px; }
    span { margin-left: 12px; }
  }
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

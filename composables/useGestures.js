// Face gestures (blinks, winks, mouth) -> world reactions.
// Detection lives in utils/gestureDetector.js (pure, unit-tested); this composable feeds it, shapes its output
// with springs, and exposes it to the shader and to DreamWorld.
//
// `value` is a Float32Array(4), copied into the shader's `uGesture` every frame (see shaders/chunks/gestures.glsl):
//   x  closed  0..1   eyes held shut: the world dims and holds its breath. A natural blink only dips it (~0.1).
//   y  mouth   0..1   jaw open, continuous: the world breathes in, light is drawn toward the viewer.
//   z  wink   -1..1   a glint sweeping across from the winking eye's side. |z| = progress 0->1, sign = side
//                     (-1 viewer's left eye, +1 right). 0 = idle.
//   w  bloom   0..1   progress of the ring of light that blooms when the eyes re-open after an intentional blink
//                     (long blink or double blink). 0 = idle.
// z and w are progress values the shader eases (smooth at both ends), so restarting at 0 never shows a jump.
//
// Optional extras for non-shader behaviour (DreamWorld may ignore them):
//   gestures.descentBoost  0..1, the smoothed mouth: e.g. dive faster while the mouth is open
//   gestures.onIntent(cb)  cb({ kind: 'long'|'double' }) when an intentional blink completes (eyes re-open)
//   gestures.onWink(cb)    cb({ side: -1|1 })
//   gestures.onBlink(cb)   natural blinks, if anything wants to blink back
//
// Demo keys: B = intentional blink, W = wink (right eye), hold M = mouth open. They inject synthetic blendshapes
// into the same detector, so they exercise the real pipeline and work in mouse fallback too.
// Screenshots: ?gesture=closed|mouth|wink|wink-left|bloom or ?gesture=0,0.8,0,0 freezes `value`.

import { createGestureDetector } from '~/utils/gestureDetector'

const OMEGA_CLOSED_IN = 14 // dims quickly once the eyes are really shut...
const OMEGA_CLOSED_OUT = 6 // ...and lets the light back more slowly
const OMEGA_MOUTH_IN = 2.5 // the inhale is slow and deliberate
const OMEGA_MOUTH_OUT = 3.5
const BLOOM_SECONDS = 2.6
const WINK_SECONDS = 1.6
const KEY_BLINK_SECONDS = 0.55
const KEY_WINK_SECONDS = 0.4

const PRESETS = {
  closed: [1, 0, 0, 0],
  mouth: [0, 0.9, 0, 0],
  wink: [0, 0, 0.4, 0],
  'wink-left': [0, 0, -0.4, 0],
  bloom: [0, 0, 0, 0.15],
  blink: [0, 0, 0, 0.15],
}

/** @param {ReturnType<typeof useHeadPose>} head */
export function useGestures(head) {
  const value = new Float32Array(4)
  const listeners = { intent: new Set(), wink: new Set(), blink: new Set() }
  const on = (type) => (cb) => {
    listeners[type].add(cb)
    return () => listeners[type].delete(cb)
  }
  const gestures = {
    value,
    descentBoost: 0,
    onIntent: on('intent'),
    onWink: on('wink'),
    onBlink: on('blink'),
  }

  const param = new URLSearchParams(window.location.search).get('gesture')
  if (param) {
    const fixed = PRESETS[param] ?? param.split(',').map(Number)
    for (let i = 0; i < 4; i++) value[i] = Number.isFinite(fixed[i]) ? fixed[i] : 0
    gestures.descentBoost = Math.max(value[1], 0)
    return gestures
  }

  const detector = createGestureDetector()
  const closed = { value: 0, velocity: 0 }
  const mouth = { value: 0, velocity: 0 }
  let bloom = 0 // progress 0..1, 0 = idle
  let wink = 0 // progress 0..1
  let winkSide = 1

  // Keyboard overrides: seconds left on a synthetic blink / wink, and whether M is held
  // `active` keeps feeding the detector a little after a key ends so it sees the eyes re-open (that's when blinks fire)
  const keys = { blink: 0, wink: 0, mouth: false, active: 0 }
  const synthetic = {}

  function input(dt) {
    keys.blink = Math.max(keys.blink - dt, 0)
    keys.wink = Math.max(keys.wink - dt, 0)
    keys.active = keys.mouth ? 0.5 : Math.max(keys.active - dt, 0)
    const keyed = keys.active > 0
    if (!head.tracking && !keyed) return null // no face: detector resets, everything eases to 0

    const bs = head.tracking ? head.blendshapes : {}
    const shut = keys.blink > 0 ? 0.9 : 0
    synthetic.eyeBlinkLeft = Math.max(bs.eyeBlinkLeft ?? 0, shut, keys.wink > 0 ? 0.9 : 0) // MediaPipe "left" = viewer's right
    synthetic.eyeBlinkRight = Math.max(bs.eyeBlinkRight ?? 0, shut)
    synthetic.jawOpen = Math.max(bs.jawOpen ?? 0, keys.mouth ? 0.7 : 0)
    return synthetic
  }

  function emit(e) {
    if (e.type === 'intent') {
      // Restart the bloom unless one is still bright (avoids a visible jump mid-ring)
      if (bloom === 0 || bloom > 0.6) bloom = 1e-4
    } else if (e.type === 'wink') {
      if (wink === 0 || wink > 0.6) {
        wink = 1e-4
        winkSide = e.side
      }
    }
    for (const cb of listeners[e.type]) cb(e)
  }

  useRAF((dt) => {
    const out = detector.step(input(dt), dt)
    out.events.forEach(emit)

    springStep(closed, out.closed, out.closed > closed.value ? OMEGA_CLOSED_IN : OMEGA_CLOSED_OUT, dt)
    springStep(mouth, out.mouth, out.mouth > mouth.value ? OMEGA_MOUTH_IN : OMEGA_MOUTH_OUT, dt)
    if (bloom > 0) bloom = bloom + dt / BLOOM_SECONDS >= 1 ? 0 : bloom + dt / BLOOM_SECONDS
    if (wink > 0) wink = wink + dt / WINK_SECONDS >= 1 ? 0 : wink + dt / WINK_SECONDS

    value[0] = Math.max(closed.value, 0)
    value[1] = Math.max(mouth.value, 0)
    value[2] = wink * winkSide
    value[3] = bloom
    gestures.descentBoost = value[1]
  })

  function onKeyDown(e) {
    if (e.repeat || e.metaKey || e.ctrlKey || e.altKey) return
    const k = e.key.toLowerCase()
    if (k === 'b') keys.blink = KEY_BLINK_SECONDS
    else if (k === 'w') keys.wink = KEY_WINK_SECONDS
    else if (k === 'm') keys.mouth = true
    else return
    keys.active = Math.max(keys.active, keys.blink, keys.wink) + 0.5
  }
  const onKeyUp = (e) => e.key.toLowerCase() === 'm' && (keys.mouth = false)
  const onBlur = () => (keys.mouth = false)
  window.addEventListener('keydown', onKeyDown)
  window.addEventListener('keyup', onKeyUp)
  window.addEventListener('blur', onBlur)
  onScopeDispose(() => {
    window.removeEventListener('keydown', onKeyDown)
    window.removeEventListener('keyup', onKeyUp)
    window.removeEventListener('blur', onBlur)
  })

  return gestures
}

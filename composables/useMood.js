// Mood from facial expression -> shader colourway.
// Contract: `value` is a Float32Array(4) = (joy, sadness, surprise, tension), each 0..1, already smoothed.
// DreamWorld copies it into the shader's `uMood` every frame; the shader grades colour in shaders/chunks/mood.glsl.
//
// Pipeline per frame: raw blendshapes - resting baseline -> moodFromFace (dead zones, gains, clamp)
// -> slow critically damped springs -> `value`. Overrides (keys 1-4, ?mood=) replace the face targets
// but still go through the same springs, so nothing ever snaps.

const OMEGA_RISE = 2.4 // a mood drifts in over ~1.7 s
const OMEGA_FALL = 1.5 // and lingers a little longer on the way out (~2.7 s)
const BASELINE_TAU_DOWN = 6 // s: if the resting face is lower than calibrated (smiled while calibrating), adapt fairly fast
const BASELINE_TAU_UP = 120 // s: a held expression only fades into the baseline very slowly
const SNAP = 1e-4 // below this a mood counts as exactly 0, so neutral is an exact identity in the shader

// Typical MediaPipe resting scores, used until this person's calibration finishes
const DEFAULT_BASELINE = { browInnerUp: 0.08, mouthPressLeft: 0.08, mouthPressRight: 0.08, browDownLeft: 0.04, browDownRight: 0.04 }

// Keys 1-4 force a mood (demos), 0 hands control back to the face. C, D, B, M, W belong to others.
const KEY_MOODS = { 1: 0, 2: 1, 3: 2, 4: 3 }

/** @param {ReturnType<typeof useHeadPose>} head */
export function useMood(head) {
  const mood = {
    value: new Float32Array(4),
    // Optional motion multipliers (1 = unchanged). Not wired yet; see report / comments below.
    timeScale: 1, // scale dt for ambient animation: sad = slower, tense = jittery-faster
    descentScale: 1, // scale descent speed: surprise pulls you in, sadness holds you back
  }

  const base = Object.fromEntries(MOOD_SHAPES.map((k) => [k, DEFAULT_BASELINE[k] ?? 0]))
  let calib = null // { sums, n } while head.status is 'calibrating'
  const raw = new Float32Array(4)
  const springs = MOODS.map(() => ({ value: 0, velocity: 0 }))

  // Overrides: URL for screenshots (starts there, no fade), keys for live demos
  let override = parseMoodParam(new URLSearchParams(window.location.search).get('mood'))
  if (override) override.forEach((v, i) => (springs[i].value = v))

  function onKey(e) {
    if (e.repeat || e.metaKey || e.ctrlKey || e.altKey) return
    if (e.key === '0') override = null
    else if (e.key in KEY_MOODS) override = MOODS.map((_, i) => (i === KEY_MOODS[e.key] ? 1 : 0))
  }
  window.addEventListener('keydown', onKey)
  onScopeDispose(() => window.removeEventListener('keydown', onKey))

  function updateBaseline(dt) {
    const bs = head.blendshapes
    const status = head.status.value
    if (status === 'calibrating') {
      // Average the resting face while the user is asked to hold still (same window as the head pose)
      calib ??= { sums: Object.fromEntries(MOOD_SHAPES.map((k) => [k, 0])), n: 0 }
      if (bs.jawOpen === undefined) return // no face seen yet
      for (const k of MOOD_SHAPES) calib.sums[k] += bs[k] ?? 0
      calib.n++
      return
    }
    if (calib) {
      if (calib.n > 0) for (const k of MOOD_SHAPES) base[k] = calib.sums[k] / calib.n
      calib = null
    }
    if (!head.tracking) return
    // Slow running baseline: asymmetric so a resting face is learnt quickly but an expression is not
    for (const k of MOOD_SHAPES) {
      const v = bs[k] ?? 0
      const tau = v < base[k] ? BASELINE_TAU_DOWN : BASELINE_TAU_UP
      base[k] += (v - base[k]) * (1 - Math.exp(-dt / tau))
    }
  }

  useRAF((dt) => {
    updateBaseline(dt)

    if (override) raw.set(override)
    else if (head.tracking) moodFromFace(head.blendshapes, base, raw)
    else raw.fill(0) // no face (lost, mouse fallback): ease back to neutral

    for (let i = 0; i < 4; i++) {
      const s = springs[i]
      springStep(s, raw[i], raw[i] > s.value ? OMEGA_RISE : OMEGA_FALL, dt)
      const v = Math.min(Math.max(s.value, 0), 1)
      mood.value[i] = v < SNAP && raw[i] === 0 ? 0 : v
    }

    const [joy, sad, sur, ten] = mood.value
    mood.timeScale = Math.max(1 + 0.15 * joy - 0.45 * sad + 0.1 * sur + 0.3 * ten, 0.4)
    mood.descentScale = Math.max(1 + 0.1 * joy - 0.4 * sad + 0.5 * sur + 0.15 * ten, 0.4)
  })

  return mood
}

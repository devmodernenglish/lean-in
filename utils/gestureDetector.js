// Face-gesture detector: raw MediaPipe blendshapes in, discrete events + continuous levels out.
// Pure JS (no Vue), stepped once per frame, so it can be unit-tested with synthetic sequences.
//
// What it recognises:
//   natural blink  both eyes closed briefly (< LONG_BLINK) -> 'blink' (subtle; people do this ~15-20x a minute)
//   long blink     both eyes closed >= LONG_BLINK, fires on re-opening -> 'intent' { kind: 'long' }
//   double blink   two short blinks, the second starting <= DOUBLE_GAP after the first ended -> 'intent' { kind: 'double' }
//   wink           one eye closed >= WINK_MIN while the other stays open -> 'wink' { side: -1 left | 1 right, from the viewer }
// Plus two continuous levels: `closed` (how long the eyes have been shut, 0..1) and `mouth` (jaw open, 0..1).

// Eye closure is measured above a per-person resting baseline (some people rest at 0.2-0.4, e.g. with glasses
// or looking down at the screen), then compared with hysteresis: closes above ON, re-opens below OFF.
export const EYE_ON = 0.5
export const EYE_OFF = 0.3
export const OTHER_OPEN = 0.25 // for a wink the other eye must stay below this (stricter than OFF)
export const LONG_BLINK = 0.35 // s: natural blinks are ~0.1-0.25 s over threshold
export const MAX_BLINK = 4 // s: eyes shut longer than this is not a gesture (dozing, looking away)
export const DOUBLE_GAP = 0.45 // s: max open time between the two blinks of a double blink
export const WINK_MIN = 0.2 // s: one-eye closures shorter than this are just an uneven blink
export const REFRACTORY = 0.8 // s: after an intent or wink, ignore new intents/winks (debounce)
export const BASELINE_TAU = 3 // s: how slowly the resting baseline follows the open-eye level
export const BASELINE_MAX = 0.6

// Mouth: jawOpen above its resting level, shaped into 0..1. Talking sits mostly below JAW_FULL.
export const JAW_START = 0.12
export const JAW_FULL = 0.55

// MediaPipe's blendshape names are from the camera's point of view: on the raw (unmirrored) webcam image
// `eyeBlinkLeft` is the eye on the image's left, i.e. the viewer's RIGHT eye. Swap so `side` is the viewer's.
// Real-face check: wink your right eye -> side should be +1 (the glint comes from screen right).
export const MEDIAPIPE_MIRRORED = true

const clamp01 = (v) => Math.min(1, Math.max(0, v))
const smoothstep = (a, b, v) => {
  const t = clamp01((v - a) / (b - a))
  return t * t * (3 - 2 * t)
}

export function createGestureDetector() {
  const s = {
    baseL: 0.1, baseR: 0.1, baseJaw: 0.05,
    closedL: false, closedR: false,
    both: 0, // s both eyes have been closed (0 when not in a blink)
    bothArmed: true, // a blink may count: false after one was cancelled (too long)
    lastShortEnd: -Infinity, // time the previous short blink ended
    lastShortStart: -Infinity,
    oneSide: 0, // which eye is closed alone: -1 / 1 / 0
    one: 0, // s that single eye has been closed
    winkArmed: true, // a wink may start: only from both eyes open, so the uneven tail of a blink can't count
    winkFired: false,
    refractoryUntil: -Infinity,
    time: 0,
  }

  function reset() {
    s.closedL = s.closedR = false
    s.both = s.one = 0
    s.oneSide = 0
    s.winkFired = false
    s.winkArmed = true
    s.bothArmed = true
    s.lastShortEnd = -Infinity
  }

  /**
   * @param {Record<string, number> | null} bs raw blendshapes, or null when there is no face (state resets, nothing fires)
   * @param {number} dt seconds since the last step
   * @returns {{ events: Array<{ type: 'blink'|'intent'|'wink', kind?: string, side?: number }>, closed: number, mouth: number }}
   */
  function step(bs, dt) {
    s.time += dt
    const events = []
    if (!bs) {
      reset()
      return { events, closed: 0, mouth: 0 }
    }

    let rawL = bs.eyeBlinkLeft ?? 0
    let rawR = bs.eyeBlinkRight ?? 0
    if (MEDIAPIPE_MIRRORED) [rawL, rawR] = [rawR, rawL]

    // Closure above baseline, rescaled so 1 is still fully shut
    const cL = clamp01((rawL - s.baseL) / (1 - s.baseL))
    const cR = clamp01((rawR - s.baseR) / (1 - s.baseR))

    // Hysteresis per eye
    s.closedL = s.closedL ? cL > EYE_OFF : cL > EYE_ON
    s.closedR = s.closedR ? cR > EYE_OFF : cR > EYE_ON

    // Baseline follows the resting level slowly, only while both eyes are clearly open, or after a closure
    // too long to be a gesture (someone whose lids read high, e.g. looking down at a laptop, re-adapts)
    if ((!s.closedL && !s.closedR) || !s.bothArmed) {
      const k = 1 - Math.exp(-dt / BASELINE_TAU)
      s.baseL = Math.min(BASELINE_MAX, s.baseL + (rawL - s.baseL) * k)
      s.baseR = Math.min(BASELINE_MAX, s.baseR + (rawR - s.baseR) * k)
    }

    const cooling = s.time < s.refractoryUntil

    // --- both eyes: blinks
    if (s.closedL && s.closedR) {
      s.both += dt
      s.winkArmed = false
      if (s.both > MAX_BLINK) s.bothArmed = false
    } else if (s.both > 0 && !s.closedL && !s.closedR) {
      // Both eyes open again: classify the blink that just ended
      const d = s.both
      const start = s.time - d
      s.both = 0
      if (!s.bothArmed) {
        s.bothArmed = true
      } else if (d >= LONG_BLINK) {
        if (!cooling) fire({ type: 'intent', kind: 'long' })
        s.lastShortEnd = -Infinity
      } else if (start - s.lastShortEnd <= DOUBLE_GAP && !cooling) {
        fire({ type: 'intent', kind: 'double' })
        s.lastShortEnd = -Infinity
      } else {
        events.push({ type: 'blink' })
        s.lastShortEnd = s.time
      }
    }

    // --- one eye only: winks
    const side = s.closedL && !s.closedR && cR < OTHER_OPEN ? -1 : s.closedR && !s.closedL && cL < OTHER_OPEN ? 1 : 0
    if (side !== 0 && s.winkArmed && (s.oneSide === 0 || s.oneSide === side)) {
      s.oneSide = side
      s.one += dt
      if (s.one >= WINK_MIN && !s.winkFired && !cooling) {
        s.winkFired = true
        fire({ type: 'wink', side })
      }
    } else {
      s.one = 0
      s.oneSide = 0
      s.winkFired = false
      // Re-arm winks only once both eyes are open again
      if (!s.closedL && !s.closedR) s.winkArmed = true
    }

    // --- continuous levels
    // closed: a small floor the moment both eyes shut, then rising to 1 at ~0.65 s held.
    // A natural blink barely lifts it; a long blink takes the world fully dark; past MAX_BLINK it lets go.
    const closed = s.closedL && s.closedR && s.bothArmed ? 0.1 + 0.9 * clamp01((s.both - 0.18) / 0.47) : 0

    const jaw = bs.jawOpen ?? 0
    if (jaw < JAW_START) s.baseJaw += (Math.min(jaw, 0.1) - s.baseJaw) * (1 - Math.exp(-dt / BASELINE_TAU))
    const mouth = smoothstep(JAW_START, JAW_FULL, jaw - s.baseJaw)

    return { events, closed, mouth }

    function fire(e) {
      events.push(e)
      s.refractoryUntil = s.time + REFRACTORY
    }
  }

  return { step, reset, state: s }
}

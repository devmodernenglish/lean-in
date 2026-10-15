// Pure maths: MediaPipe blendshapes (minus a per-person resting baseline) -> raw mood targets.
// No Vue, no state: easy to unit-check in node. Smoothing happens in useMood.

export const MOODS = ['joy', 'sadness', 'surprise', 'tension']

// Every blendshape the mapping reads; the baseline tracks exactly these.
export const MOOD_SHAPES = [
  'mouthSmileLeft', 'mouthSmileRight', 'cheekSquintLeft', 'cheekSquintRight',
  'mouthFrownLeft', 'mouthFrownRight', 'browInnerUp',
  'browOuterUpLeft', 'browOuterUpRight', 'eyeWideLeft', 'eyeWideRight', 'jawOpen',
  'browDownLeft', 'browDownRight', 'mouthPressLeft', 'mouthPressRight', 'noseSneerLeft', 'noseSneerRight',
]

// Per mood: dead zone (ignore twitches below this), gain (how far an expression must go to reach 1).
// Frowns and presses score low in MediaPipe even when obvious, so they get more gain.
const SHAPE = {
  joy: { dead: 0.045, gain: 3.2 },
  sadness: { dead: 0.04, gain: 3.0 },
  surprise: { dead: 0.06, gain: 2.2 },
  tension: { dead: 0.05, gain: 2.6 },
}

const clamp01 = (v) => Math.min(Math.max(v, 0), 1)
const shape = (v, { dead, gain }) => clamp01((v - dead) * gain)

/**
 * @param {Record<string, number>} bs raw blendshape scores 0..1
 * @param {Record<string, number>} base resting-face scores for the same keys
 * @param {Float32Array|number[]} out length 4: (joy, sadness, surprise, tension) 0..1
 */
export function moodFromFace(bs, base, out = new Float32Array(4)) {
  // How far each shape is above this person's resting face; never negative
  const d = (k) => Math.max((bs[k] ?? 0) - (base[k] ?? 0), 0)
  const pair = (k) => 0.5 * (d(k + 'Left') + d(k + 'Right'))

  const smile = pair('mouthSmile')
  const cheek = pair('cheekSquint')
  const frown = pair('mouthFrown')
  const outerUp = pair('browOuterUp')
  const innerUp = d('browInnerUp')
  const wide = pair('eyeWide')
  const jaw = d('jawOpen')
  const browDown = pair('browDown')
  const press = pair('mouthPress')
  const sneer = pair('noseSneer')

  // Joy: a smile, more convincing when the cheeks join in (a real "Duchenne" smile)
  const joy = shape(smile + 0.5 * cheek, SHAPE.joy)
  // Surprise: brows lifted at the outer ends and eyes wide; an open jaw only counts with the brows,
  // so plain mouth-opening stays free for the gestures work.
  const surprise = shape(0.6 * outerUp + 0.5 * wide + 0.35 * Math.min(jaw, 2 * outerUp), SHAPE.surprise)
  // Sadness: corners of the mouth down, and the "worried" brow (inner end up, outer end not)
  const sadness = shape(frown + 0.7 * Math.max(innerUp - outerUp, 0), SHAPE.sadness) * (1 - 0.8 * joy)
  // Tension: brows pulled down, lips pressed, a hint of sneer
  const tension = shape(0.8 * browDown + 0.6 * press + 0.3 * sneer, SHAPE.tension) * (1 - 0.6 * surprise)

  out[0] = joy
  out[1] = sadness
  out[2] = surprise
  out[3] = tension
  return out
}

/**
 * Parse `?mood=joy` or `?mood=0.8,0,0,0.3`. Returns a 4-array or null.
 * @param {string|null} param
 */
export function parseMoodParam(param) {
  if (!param) return null
  const i = MOODS.indexOf(param.toLowerCase())
  if (i >= 0) return MOODS.map((_, j) => (j === i ? 1 : 0))
  const nums = param.split(',').map(Number)
  if (nums.length !== 4 || nums.some(Number.isNaN)) return null
  return nums.map(clamp01)
}

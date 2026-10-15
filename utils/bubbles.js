// Where the glass bubbles of a world sit. MUST stay identical to shaders/chunks/bubbles.glsl:
// JS decides when you cross into a bubble, the shader draws it. Both derive everything from a world's integer
// seed with the same 32-bit integer hash (Math.imul here, uint maths there), so they agree exactly.

export const WORLD_H = 2.0 // a child world's units per bubble radius
export const SLOT_POS = [[-0.06, -0.03], [-0.57, 0.24], [0.48, 0.29], [-0.40, -0.31], [0.59, -0.22], [0.04, 0.39]]

/** Chris Wellons' lowbias32, bit-for-bit the GLSL hash32. Returns an unsigned 32-bit integer. */
export function hash32(x) {
  x ^= x >>> 16
  x = Math.imul(x, 0x7feb352d)
  x ^= x >>> 15
  x = Math.imul(x, 0x846ca68b)
  x ^= x >>> 16
  return x >>> 0
}

const u01 = (x) => (x >>> 8) / 16777216

const smoothstep = (e0, e1, x) => {
  const t = Math.min(Math.max((x - e0) / (e1 - e0), 0), 1)
  return t * t * (3 - 2 * t)
}

/**
 * Bubble in slot i of world `seed`, at camera scale s (world units per screen height), time t, head offset [x, y].
 * @returns {{ i: number, c: number[], r: number, depth: number, child: number, on: boolean }}
 */
export function bubbleAt(seed, i, s, t, head) {
  let h = hash32(seed ^ Math.imul(i + 1, 0x9e3779b9))
  const f = []
  for (let k = 0; k < 6; k++) {
    if (k) h = hash32(h)
    f.push(u01(h))
  }
  const r = i === 0 ? 0.09 + 0.05 * f[3] : 0.05 + 0.08 * f[3]
  const depth = i === 0 ? 0.2 * f[4] : f[4]
  const settle = 1 - smoothstep(0.25, 0.6, r / s)
  const ph = f[5] * 6.2831
  const par = (0.04 + (-0.05 - 0.04) * depth) * Math.min(s, 1)
  const c = [0, 1].map((k) => {
    const drift = (0.009 + 0.012 * f[0]) * (k ? Math.sin(t * (0.11 + 0.09 * f[2]) + ph * 1.3) : Math.sin(t * (0.13 + 0.1 * f[1]) + ph))
    return SLOT_POS[i][k] + (f[1 + k] - 0.5) * 0.18 + settle * (drift + head[k] * par)
  })
  return { i, c, r, depth, child: hash32((Math.imul(seed, 7) + i + 1) >>> 0) & 0xffffff, on: i < 2 || f[0] > 0.35 }
}

/** All bubbles present in world `seed` */
export function bubblesOf(seed, s, t, head) {
  const out = []
  for (let i = 0; i < SLOT_POS.length; i++) {
    const b = bubbleAt(seed, i, s, t, head)
    if (b.on) out.push(b)
  }
  return out
}

/** Realm (0..2) of the world inside a bubble: always different from its parent's, and varied between siblings */
export const REALM_COUNT = 6
export const childRealm = (realm, childSeed) => (realm + 1 + (childSeed % (REALM_COUNT - 1))) % REALM_COUNT

// The dive camera: where you are in the endless chain of bubble worlds.
// The camera is always stored in the CURRENT world's own coordinates (centre c, scale s = world units per screen
// height), never as a growing global zoom, so precision never runs out. Crossing into a bubble re-expresses the
// camera in the child's coordinates; rising back out re-expresses it in the parent's. Because the shader draws
// the same picture either way, a crossing is invisible.

import { WORLD_H, bubbleAt, bubblesOf, childRealm } from './bubbles'

const ENTER_CLEAR = 0.62 // cross in when the whole screen lies within this fraction of the bubble radius...
const EXIT_CLEAR = 0.68 // ...and back out when it reaches past this (glass is perfectly clear inside 0.7)
const RANGE = [0.65, 0.45] // screen heights the view shifts across at full steer (left/right, up/down)
const STEER_DEAD = 0.12 // ignore head/mouse offsets smaller than this
const MAGNET = 1.6 // 1/s: how hard the camera centre is drawn to the nearest bubble once it is big on screen
const MAGNET_MAX = 5 // 1/s: cap on that pull, so even a big bubble draws you in like a current, never a yank
const VIEW_OMEGA = 2.4 // 1/s: the visible camera glides after the navigation camera (critically damped), like water
const BOUND = [0.8, 0.45] // the camera centre is eased back inside this box of the current world
const S_MAX = 1.6 // furthest zoom out at the outermost world
const S_RISE = 2.5 // always rise into the parent past this zoom-out
const S_MIN = 0.008 // never zoom further than this without entering a bubble (keeps precision safe)
const ANCESTORS = 40 // worlds generated above the starting one, so you can rise out for a long time

const smoothstep = (e0, e1, x) => {
  const t = Math.min(Math.max((x - e0) / (e1 - e0), 0), 1)
  return t * t * (3 - 2 * t)
}
const deadZone = (v) => Math.sign(v) * Math.max(Math.abs(v) - STEER_DEAD, 0) / (1 - STEER_DEAD)

/** @param {{ baseSeed?: number }} [opts] */
export function createDiveCamera({ baseSeed = 4242 } = {}) {
  // Stack of worlds from the outermost down to the current one. index = which bubble of the parent it fills.
  const stack = [{ seed: baseSeed, realm: 0, index: -1 }]
  for (let k = 0; k < ANCESTORS; k++) {
    const top = stack[stack.length - 1]
    const child = bubbleAt(top.seed, 0, 1, 0, [0, 0]).child
    stack.push({ seed: child, realm: childRealm(top.realm, child), index: 0 })
  }

  const cam = { c: [0, 0], s: 1 }
  // What is drawn: a critically damped follower of `cam` (centre and log2 scale), so every change of course
  // (steering, the magnet, a blink's dive) eases in and out with weight. Velocities live in the same coordinates.
  const view = { c: [0, 0], l: 0, vc: [0, 0], vl: 0 }
  let target = null // the bubble you are heading into
  let cue = 0
  let lastSteer = [0, 0]

  const current = () => stack[stack.length - 1]
  // Distance from point b to the furthest screen corner, in world units
  const reach = (c, s, b, aspect) => Math.hypot(Math.abs(c[0] - b[0]) + 0.5 * aspect * s, Math.abs(c[1] - b[1]) + 0.5 * s)

  /** The bubble of the parent world that holds the current one, as seen at camera scale s */
  function parentBubble(t, head, s = cam.s) {
    const w = current()
    const parent = stack[stack.length - 2]
    const r = bubbleAt(parent.seed, w.index, 1, t, head).r
    return bubbleAt(parent.seed, w.index, s * r / WORLD_H, t, head)
  }

  // Re-express the glide state in another world's coordinates: p' = offset + p * k (scale s' = s * k)
  function reframeView(offset, k) {
    view.c = [offset[0] + view.c[0] * k, offset[1] + view.c[1] * k]
    view.vc = [view.vc[0] * k, view.vc[1] * k]
    view.l += Math.log2(k)
  }

  // One critically damped step (same maths as useSpring's springStep)
  function glide(pos, vel, target, dt) {
    const x = pos - target
    const e = Math.exp(-VIEW_OMEGA * dt)
    const t = (vel + VIEW_OMEGA * x) * dt
    return [target + (x + t) * e, (vel - VIEW_OMEGA * t) * e]
  }

  /**
   * Move the camera one frame.
   * @param {number} dt seconds
   * @param {{ steer: number[], zoom: number, head: number[], time: number, aspect: number, pull?: number }} input
   *   steer: head/mouse -1..1; zoom: octaves to zoom in this frame (negative = out); head: parallax offset as sent
   *   to the shader; time: the shader's uTime; pull: extra magnetism 0..1 (an intentional blink diving you in)
   */
  function advance(dt, { steer, zoom, head, time, aspect, pull = 0 }) {
    // Zoom about the screen centre
    cam.s *= 2 ** -zoom
    if (stack.length === 1) cam.s = Math.min(cam.s, S_MAX)

    // Steer: where you lean is where you look. Only CHANGES in lean move the view (scaled to the current zoom),
    // so a held lean keeps its aim while you dive, and re-centring your head does not undo the dive.
    const sx = deadZone(steer[0])
    const sy = deadZone(steer[1])
    cam.c[0] += (sx - lastSteer[0]) * RANGE[0] * cam.s
    cam.c[1] += (sy - lastSteer[1]) * RANGE[1] * cam.s
    lastSteer = [sx, sy]
    for (let k = 0; k < 2; k++) {
      const lim = BOUND[k]
      if (Math.abs(cam.c[k]) > lim) cam.c[k] += (Math.sign(cam.c[k]) * lim - cam.c[k]) * (1 - Math.exp(-dt * 2))
    }

    // Magnetism: the nearest bubble draws the camera centre in as it grows on screen, so you never land on a rim
    const w = current()
    const bubbles = bubblesOf(w.seed, cam.s, time, head)
    target = bubbles.reduce((best, b) => {
      const d = Math.hypot(b.c[0] - cam.c[0], b.c[1] - cam.c[1]) - b.r
      return !best || d < best.d ? { ...b, d } : best
    }, null)
    const grow = smoothstep(0.05, 0.45, target.r / cam.s)
    // Steering weakens the pull while bubbles are small (you are choosing); once one is big, it has you
    const free = 1 - 0.6 * Math.min(Math.hypot(sx, sy), 1) * (1 - smoothstep(0.3, 1.0, target.r / cam.s))
    const k = (MAGNET * grow * free + 4 * pull) / Math.max(cam.s / target.r, 0.25)
    const a = 1 - Math.exp(-dt * Math.min(k, MAGNET_MAX))
    cam.c[0] += (target.c[0] - cam.c[0]) * a
    cam.c[1] += (target.c[1] - cam.c[1]) * a
    cue += (smoothstep(0.12, 0.5, target.r / cam.s) - cue) * (1 - Math.exp(-dt * 3))

    // Cross in: the whole screen is inside the target's clear glass
    if (reach(cam.c, cam.s, target.c, aspect) < ENTER_CLEAR * target.r) {
      stack.push({ seed: target.child, realm: childRealm(w.realm, target.child), index: target.i })
      cam.c = [(cam.c[0] - target.c[0]) / target.r * WORLD_H, (cam.c[1] - target.c[1]) / target.r * WORLD_H]
      cam.s *= WORLD_H / target.r
      const k = WORLD_H / target.r
      reframeView([-target.c[0] * k, -target.c[1] * k], k)
      cue = 0
    } else if (stack.length > 1 && ((zoom < 0 && reach(cam.c, cam.s, [0, 0], aspect) > EXIT_CLEAR * WORLD_H) || cam.s > S_RISE)) {
      // Rise out: sitting back has the screen reaching past the clear part of the bubble we are in. (Steering
      // alone never pops you out: the shader draws from the parent world, so looking past the glass is fine.)
      const b = parentBubble(time, head)
      stack.pop()
      cam.c = [b.c[0] + cam.c[0] * b.r / WORLD_H, b.c[1] + cam.c[1] * b.r / WORLD_H]
      cam.s *= b.r / WORLD_H
      reframeView(b.c, b.r / WORLD_H)
      cue = 0
    } else if (cam.s < S_MIN) {
      cam.s = S_MIN
    }

    // The visible camera glides after the navigation camera
    for (let i = 0; i < 2; i++) [view.c[i], view.vc[i]] = glide(view.c[i], view.vc[i], cam.c[i], dt)
    ;[view.l, view.vl] = glide(view.l, view.vl, Math.log2(cam.s), dt)
  }

  /** Jump the glide straight to the camera (after a scripted start, e.g. ?descent=) */
  function snapView() {
    view.c = [...cam.c]
    view.l = Math.log2(cam.s)
    view.vc = [0, 0]
    view.vl = 0
  }

  /** Write the shader's uniforms: it draws from the parent of the current world, so the outside is always there. */
  function write(u, time, head) {
    const w = current()
    const vs = 2 ** view.l
    if (stack.length > 1) {
      const b = parentBubble(time, head, vs)
      const parent = stack[stack.length - 2]
      u.uRoot[0] = parent.seed
      u.uRoot[1] = parent.realm
      u.uCam[0] = b.c[0] + view.c[0] * b.r / WORLD_H
      u.uCam[1] = b.c[1] + view.c[1] * b.r / WORLD_H
      u.uCam[2] = vs * b.r / WORLD_H
    } else {
      u.uRoot[0] = w.seed
      u.uRoot[1] = w.realm
      u.uCam.set([view.c[0], view.c[1], vs])
    }
    u.uTarget = target ? target.child : -1
    u.uCue = cue
  }

  return {
    advance,
    write,
    snapView,
    /** Octaves of zoom still needed to cross into the bubble you are heading for */
    octavesToTarget: (aspect) => (target ? Math.max(Math.log2(cam.s * Math.hypot(aspect, 1) * 0.5 / (ENTER_CLEAR * target.r)), 0) : 0),
    get depth() { return stack.length - 1 },
    /** Current world's seed and the camera in its coordinates (for debugging) */
    get state() { return { seed: current().seed, realm: current().realm, c: [...cam.c], s: cam.s } },
  }
}

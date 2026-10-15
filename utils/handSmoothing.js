import { createOneEuro } from './oneEuro.js'

// Filter fresh camera samples, and require a sustained pinch/release before changing state.
export function createHandSmoother() {
  let filters, lastTime, held, candidate, since
  function reset() {
    filters = {
      x: createOneEuro({ minCutoff: 0.7, beta: 0.12 }),
      y: createOneEuro({ minCutoff: 0.7, beta: 0.12 }),
      size: createOneEuro({ minCutoff: 0.5, beta: 0.05 }),
    }
    lastTime = null
    held = candidate = false
    since = null
  }
  reset()
  function step(hand, time) {
    if (lastTime !== null && time - lastTime > 0.3) reset()
    const dt = lastTime === null ? 0 : Math.min(time - lastTime, 0.1)
    lastTime = time
    if (hand.pinching === held) { candidate = held; since = null }
    else {
      if (candidate !== hand.pinching || since === null) { candidate = hand.pinching; since = time }
      if (time - since >= (candidate ? 0.14 : 0.20)) { held = candidate; since = null }
    }
    return { ...hand, x: filters.x(hand.x, dt), y: filters.y(hand.y, dt), size: filters.size(hand.size, dt), pinching: held }
  }
  return { step, reset }
}

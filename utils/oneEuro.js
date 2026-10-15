// 1-Euro filter: strong smoothing when still (kills jitter), light smoothing when moving fast (kills lag).
// Runs on raw landmarks before the springs, which add weight on top.

/**
 * @param {{ minCutoff?: number, beta?: number, dCutoff?: number }} [opts]
 *   minCutoff: Hz at rest (lower = steadier); beta: how fast cutoff rises with speed (higher = less lag)
 * @returns {(value: number, dt: number) => number}
 */
export function createOneEuro({ minCutoff = 1.0, beta = 0.3, dCutoff = 1.0 } = {}) {
  let prev = null
  let dPrev = 0
  const alpha = (cutoff, dt) => 1 / (1 + 1 / (2 * Math.PI * cutoff * dt))

  return (value, dt) => {
    if (prev === null || dt <= 0) return (prev = value)
    dPrev += alpha(dCutoff, dt) * ((value - prev) / dt - dPrev)
    prev += alpha(minCutoff + beta * Math.abs(dPrev), dt) * (value - prev)
    return prev
  }
}

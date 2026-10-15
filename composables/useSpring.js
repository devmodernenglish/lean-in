// Critically damped spring: moves toward its target with weight, never overshoots.

/** Advance one spring state by dt seconds. */
export function springStep(state, target, omega, dt) {
  const x = state.value - target
  const exp = Math.exp(-omega * dt)
  const temp = (state.velocity + omega * x) * dt
  state.velocity = (state.velocity - omega * temp) * exp
  state.value = target + (x + temp) * exp
}

/**
 * A spring stepped by the shared loop. Plain object (not reactive): it is read every frame.
 * Set `.target`; read `.value`. Lower omega is floatier (~4 / omega seconds to settle).
 * @param {number} initial
 * @param {number} [omega=8]
 */
export function useSpring(initial, omega = 8) {
  const spring = { value: initial, velocity: 0, target: initial, omega }
  useRAF((dt) => springStep(spring, spring.target, spring.omega, dt))
  return spring
}

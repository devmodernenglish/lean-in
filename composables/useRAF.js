// One shared requestAnimationFrame loop for the whole app.
// Subscribers run in insertion order: springs created in setup() step before GlCanvas draws.

const subscribers = new Set()
let frameId = 0
let last = 0
let elapsed = 0

function tick(now) {
  // Clamp dt so a backgrounded tab doesn't make springs leap on return
  const dt = Math.min((now - last) / 1000, 0.1)
  last = now
  elapsed += dt
  for (const fn of subscribers) fn(dt, elapsed)
  frameId = requestAnimationFrame(tick)
}

/**
 * Subscribe to the shared loop. Auto-unsubscribes when the calling scope is disposed.
 * @param {(dt: number, time: number) => void} fn dt and elapsed time in seconds
 * @returns {() => void} unsubscribe
 */
export function useRAF(fn) {
  subscribers.add(fn)
  if (subscribers.size === 1) {
    last = performance.now()
    frameId = requestAnimationFrame(tick)
  }

  const stop = () => {
    subscribers.delete(fn)
    if (subscribers.size === 0) cancelAnimationFrame(frameId)
  }
  if (getCurrentScope()) onScopeDispose(stop)
  return stop
}

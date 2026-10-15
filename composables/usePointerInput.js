// Mouse + scroll fallback. Same shape as useHeadPose() will return, so DreamWorld can swap sources.
// Raw values only: smoothing happens downstream in useSpring, shared with the camera path.

const Z_MIN = -0.5 // leaning back
const Z_MAX = 1.5  // leaning in
const WHEEL_SENSITIVITY = 0.004 // deltaY > 0 (scroll down / trackpad swipe up) = lean in
const Z_RELEASE = 0.8 // seconds for a scroll "lean" to relax back to 0, so scrolling pushes you and you glide

/**
 * @returns {{ x: number, y: number, z: number, tracking: boolean, lastActive: number }}
 *   x, y in -1..1 (right / up positive); z is a lean offset, 0 = neutral, > 0 = leaning in;
 *   lastActive is the performance.now() of the last move or scroll
 */
export function usePointerInput() {
  const input = { x: 0, y: 0, z: 0, tracking: false, lastActive: -Infinity }

  const onMove = (e) => {
    input.x = (e.clientX / window.innerWidth) * 2 - 1
    input.y = 1 - (e.clientY / window.innerHeight) * 2
    input.tracking = true
    input.lastActive = performance.now()
  }
  // Pointer left the window: ease back to neutral rather than freezing (mirrors PRD F6)
  const onOut = (e) => {
    if (e.relatedTarget) return
    input.x = 0
    input.y = 0
    input.tracking = false
  }
  const onWheel = (e) => {
    input.z = Math.min(Z_MAX, Math.max(Z_MIN, input.z + e.deltaY * WHEEL_SENSITIVITY))
    input.lastActive = performance.now()
  }

  useRAF((dt) => {
    input.z *= Math.exp(-dt / Z_RELEASE)
  })

  window.addEventListener('pointermove', onMove)
  window.addEventListener('pointerout', onOut)
  window.addEventListener('wheel', onWheel, { passive: true })
  onScopeDispose(() => {
    window.removeEventListener('pointermove', onMove)
    window.removeEventListener('pointerout', onOut)
    window.removeEventListener('wheel', onWheel)
  })

  return input
}

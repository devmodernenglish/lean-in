// Together -> push toward the camera -> spread and withdraw. No single-sweep shortcuts.
// Camera depth is inferred from apparent palm size; larger means nearer the screen/camera.
export function createSwimDetector() {
  let phase = 'together', baseline = null, pushed = null, filtered = null
  let phaseTime = 0, lastSeen = -Infinity, cooldownUntil = 0
  function reset() {
    phase = 'together'; baseline = pushed = filtered = null
    lastSeen = -Infinity
  }
  function step(hands, time) {
    if (time < cooldownUntil) return false
    if (hands.length !== 2) {
      if (time - lastSeen > 0.8) reset()
      return false
    }
    if (time - lastSeen > 0.8) reset()
    const dt = Number.isFinite(lastSeen) ? Math.min(time - lastSeen, .15) : 0
    lastSeen = time
    const palms = hands.map(h => ({ x: h.swimX ?? h.x, y: h.swimY ?? h.y, size: h.swimSize ?? h.size }))
      .sort((a, b) => a.x - b.x)
    if (palms.some(h => !Number.isFinite(h.size) || h.size <= 0)) { reset(); return false }
    if (!filtered) filtered = palms
    else {
      const k = 1 - Math.exp(-dt * 12)
      filtered = filtered.map((p,i) => ({
        x:p.x+(palms[i].x-p.x)*k, y:p.y+(palms[i].y-p.y)*k,
        size:p.size+(palms[i].size-p.size)*k,
      }))
    }
    const [left, right] = filtered
    const spread = right.x-left.x
    if (phase !== 'together' && time-phaseTime > 3.5) { reset(); return false }
    if (phase === 'together') {
      if (spread > .32 || Math.abs(left.y-right.y) > .25) { return false }
      baseline = filtered.map(p => ({...p}))
      phase = 'push'; phaseTime = time
      return false
    }
    if (phase === 'push') {
      // Require forward travel from BOTH palms while still together.
      if (spread > .40) { reset(); return false }
      if (left.size/baseline[0].size >= 1.07 && right.size/baseline[1].size >= 1.07) {
        pushed = filtered.map(p => ({...p}))
        phase = 'sweep'; phaseTime = time
      }
      return false
    }
    // Remember the nearest point: the forward phase may continue before the sweep begins.
    if (spread < .40) {
      pushed[0].size = Math.max(pushed[0].size,left.size)
      pushed[1].size = Math.max(pushed[1].size,right.size)
    }
    const apart = pushed[0].x-left.x > .05 && right.x-pushed[1].x > .05
      && spread-(pushed[1].x-pushed[0].x) > .16
    const withdrawn = left.size/pushed[0].size < .94 && right.size/pushed[1].size < .94
    if (time-phaseTime >= .15 && apart && withdrawn) {
      cooldownUntil = time+2.5
      reset()
      return true
    }
    return false
  }
  return { step, reset, get phase() { return phase } }
}

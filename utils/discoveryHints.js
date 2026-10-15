// A short onboarding window, not an ongoing inactivity reminder.
export function createDiscoveryHints() {
  let elapsed = 0, idle = 0, active = 0, shown = 0, visible = 0
  let finished = false
  let event = false
  const tried = new Set()
  function record(kind) { tried.add(kind); event = true }
  function step(dt, kinds = []) {
    if (finished) return -1
    elapsed += dt
    kinds.forEach(record)
    if (kinds.length || event) { active += dt; idle = 0; visible = 0 }
    else idle += dt
    event = false
    // Deliberate exploration retires tips for the rest of this visit.
    if (active >= 4 || tried.size >= 3 || elapsed >= 60) {
      finished = true
      return -1
    }
    if (visible > 0) {
      visible -= dt
      if (visible > 0) return shown - 1
      idle = 0
      return -1
    }
    if (shown < 3 && idle >= (shown === 0 ? 7 : 10)) {
      shown++
      visible = 4
      return shown - 1
    }
    return -1
  }
  return { step, record }
}

// Scale-independent pinch distance with hysteresis: avoids flicker near the threshold.
export function readHand(landmarks, wasPinching = false, aspect = 1) {
  const distance = (a, b) => Math.hypot((a.x - b.x) * aspect, a.y - b.y)
  const scale = Math.max(distance(landmarks[0], landmarks[9]), 0.025)
  const ratio = distance(landmarks[4], landmarks[8]) / scale
  const pinching = ratio < (wasPinching ? 0.55 : 0.35)
  const centre = pinching
    ? { x: (landmarks[4].x + landmarks[8].x) / 2, y: (landmarks[4].y + landmarks[8].y) / 2 }
    : landmarks[9]
  return { x: 1 - centre.x, y: 1 - centre.y, pinching }
}

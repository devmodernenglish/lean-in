// Scale-independent pinch distance with hysteresis: avoids flicker near the threshold.
export function readHand(landmarks, wasPinching = false, aspect = 1) {
  const distance = (a, b) => Math.hypot((a.x - b.x) * aspect, a.y - b.y)
  const scale = Math.max(distance(landmarks[0], landmarks[9]), 0.025)
  const palmDistance = (a, b) => Math.hypot((a.x - b.x) * aspect, a.y - b.y, ((a.z ?? 0) - (b.z ?? 0)) * aspect)
  // Multiple palm spans reduce depth errors from wrist flexion during a swimming stroke.
  const swimSize = (palmDistance(landmarks[0], landmarks[5]) + palmDistance(landmarks[0], landmarks[9]) + palmDistance(landmarks[0], landmarks[17]) + palmDistance(landmarks[5], landmarks[17])) / 4
  const ratio = distance(landmarks[4], landmarks[8]) / scale
  const pinching = ratio < (wasPinching ? 0.55 : 0.35)
  // Keep the control point on the palm so entering a pinch cannot jump to the fingertips.
  const centre = landmarks[9]
  return { x: 1 - centre.x, y: 1 - centre.y, pinching, size: scale, swimSize, swimX: 1 - landmarks[9].x, swimY: 1 - landmarks[9].y }
}

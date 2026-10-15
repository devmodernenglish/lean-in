import { readHand } from '~/utils/handGesture'

// Shares the already authorised webcam. One hand at 15 Hz keeps face tracking responsive.
export function useHands(head, enabled) {
  const status = ref('idle')
  const palm = new Float32Array(4) // normalised x, y, visibility, gathered light
  const trail = new Float32Array(12 * 4)
  const burst = new Float32Array([0, 0, 10, 0]) // x, y, age, strength
  let detector, loading = false, disposed = false, lastFrame = -1, lastDetect = 0
  let target = null, pinching = false, charge = 0, sampleClock = 0
  let pointerUntil = 0, pointerDown = false

  async function load() {
    loading = true
    status.value = 'loading'
    try {
      const { HandLandmarker, FilesetResolver } = await import('@mediapipe/tasks-vision')
      const files = await FilesetResolver.forVisionTasks('/mediapipe')
      const create = (delegate) => HandLandmarker.createFromOptions(files, {
        baseOptions: { modelAssetPath: '/models/hand_landmarker.task', delegate },
        runningMode: 'VIDEO', numHands: 1,
      })
      const instance = await create('GPU').catch(() => create('CPU'))
      if (disposed) instance.close()
      else { detector = instance; status.value = 'ready' }
    } catch (error) {
      status.value = 'unavailable'
      console.warn('Hand tracking unavailable; mouse play is still available.', error)
    }
  }

  function release() {
    if (pinching && charge > 0.08) burst.set([palm[0], palm[1], 0, charge])
    pinching = false
    charge = 0
  }
  function pointer(e) {
    if (!enabled.value || e.target.closest?.('button, .intro')) return
    pointerUntil = performance.now() + 1200
    target = { x: e.clientX / window.innerWidth, y: 1 - e.clientY / window.innerHeight, pinching: pointerDown }
  }
  function down(e) { if (e.button !== 0) return; pointerDown = true; pointer(e) }
  function up() { pointerDown = false; if (target) target.pinching = false }
  function blur() { pointerUntil = 0; pointerDown = false; target = null; pinching = false; charge = 0 }
  window.addEventListener('pointermove', pointer)
  window.addEventListener('pointerdown', down)
  window.addEventListener('pointerup', up)
  window.addEventListener('blur', blur)
  onScopeDispose(() => {
    disposed = true
    detector?.close()
    window.removeEventListener('pointermove', pointer)
    window.removeEventListener('pointerdown', down)
    window.removeEventListener('pointerup', up)
    window.removeEventListener('blur', blur)
  })

  useRAF((dt) => {
    const now = performance.now()
    const video = head.video
    if (video && !loading && status.value === 'idle') load()
    if (!enabled.value) { target = null; pinching = false; charge = 0 }
    else if (!pointerDown && now > pointerUntil) {
      if (detector && video?.readyState >= 2 && video.currentTime !== lastFrame && now - lastDetect > 66) {
        lastFrame = video.currentTime
        lastDetect = now
        try {
          const result = detector.detectForVideo(video, now)
          target = result.landmarks[0] ? readHand(result.landmarks[0], pinching) : null
          status.value = target ? 'tracking' : 'ready'
        } catch (error) {
          detector.close(); detector = null; target = null; status.value = 'unavailable'
          console.warn('Hand tracking stopped; mouse play is still available.', error)
        }
      }
      if (!video || now - lastDetect > 350) target = null
    }
    if (!target) { pinching = false; charge = 0 } // Tracking loss must never launch a ball.
    else {
      if (pinching && !target.pinching) release()
      pinching = target.pinching
      if (pinching) charge = Math.min(charge + dt * 0.7, 1)
      const k = 1 - Math.exp(-dt * 12)
      if (palm[2] < 0.01) { palm[0] = target.x; palm[1] = target.y }
      else { palm[0] += (target.x - palm[0]) * k; palm[1] += (target.y - palm[1]) * k }
    }
    palm[2] += ((target ? 1 : 0) - palm[2]) * (1 - Math.exp(-dt * 8))
    palm[3] += (charge - palm[3]) * (1 - Math.exp(-dt * 8))
    burst[2] += dt
    for (let i = 0; i < 12; i++) trail[i * 4 + 2] = Math.max(0, trail[i * 4 + 2] - dt * 0.85)
    sampleClock += dt
    if (target && sampleClock > 0.045) {
      sampleClock = 0
      trail.copyWithin(4, 0, 44)
      trail.set([palm[0], palm[1], 1, Math.random()], 0)
    }
  })
  return { palm, trail, burst, status }
}

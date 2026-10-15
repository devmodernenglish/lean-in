import { readHand } from '~/utils/handGesture'
import { createSwimDetector } from '~/utils/swimGesture'
import { createHandSmoother } from '~/utils/handSmoothing'

// Shares the already authorised webcam. Two hands allow a breaststroke gesture.
export function useHands(head, enabled) {
  const status = ref('idle')
  const handCount = ref(0)
  const swimPhase = ref('together')
  let swimFeedbackUntil = 0
  const swim = createSwimDetector()
  const smoother = createHandSmoother()
  const swimListeners = new Set()
  let primarySide = null
  const onSwim = (callback) => { swimListeners.add(callback); return () => swimListeners.delete(callback) }
  const palm = new Float32Array(4) // normalised x, y, visibility, gel grip
  const motion = new Float32Array(4) // velocity x/y, pull toward camera, grip
  const anchor = new Float32Array(2) // where the gel was first grabbed
  let grabSize = 0
  const trail = new Float32Array(12 * 4)
  const burst = new Float32Array([0, 0, 10, 0]) // x, y, age, strength
  let detector, loading = false, disposed = false, lastFrame = -1, lastDetect = 0, lastSeen = 0
  let target = null, pinching = false, charge = 0, sampleClock = 0

  async function load() {
    loading = true
    status.value = 'loading'
    try {
      const { HandLandmarker, FilesetResolver } = await import('@mediapipe/tasks-vision')
      const files = await FilesetResolver.forVisionTasks('/mediapipe')
      const create = (delegate) => HandLandmarker.createFromOptions(files, {
        baseOptions: { modelAssetPath: '/models/hand_landmarker.task', delegate },
        runningMode: 'VIDEO', numHands: 2,
        minHandDetectionConfidence: 0.45,
        minHandPresenceConfidence: 0.45,
        minTrackingConfidence: 0.45,
      })
      const instance = await create('GPU').catch(() => create('CPU'))
      if (disposed) instance.close()
      else { detector = instance; status.value = 'ready' }
    } catch (error) {
      status.value = 'unavailable'
      console.warn('Hand tracking unavailable; mouse navigation is still available.', error)
    }
  }

  function release() {
    if (pinching && charge > 0.2) burst.set([palm[0], palm[1], 0, charge])
    pinching = false
    charge = 0
  }
  function blur() { handCount.value = 0; swimPhase.value = 'together'; smoother.reset(); swim.reset(); target = null; pinching = false; charge = 0; lastSeen = 0 }
  window.addEventListener('blur', blur)
  onScopeDispose(() => {
    disposed = true
    detector?.close()
    swimListeners.clear()
    window.removeEventListener('blur', blur)
  })

  useRAF((dt) => {
    const now = performance.now()
    const video = head.video
    if (video && !loading && status.value === 'idle') load()
    if (!enabled.value) { handCount.value = 0; swimPhase.value = 'together'; smoother.reset(); swim.reset(); target = null; pinching = false; charge = 0 }
    else {
      if (detector && video?.readyState >= 2 && video.currentTime !== lastFrame && now - lastDetect >= 40) {
        lastFrame = video.currentTime
        lastDetect = now
        try {
          const result = detector.detectForVideo(video, now)
          const sideOf = (i) => result.handedness?.[i]?.[0]?.categoryName ?? String(i)
          let primary = result.landmarks.findIndex((_, i) => sideOf(i) === primarySide)
          if (primary < 0) { primary = 0; primarySide = sideOf(primary); smoother.reset(); pinching = false; charge = 0 }
          const hands = result.landmarks.map((landmarks, i) => readHand(landmarks, i === primary && pinching, video.videoWidth / video.videoHeight))
          handCount.value = hands.length
          if (swim.step(hands, now / 1000)) {
            swimFeedbackUntil = now + 1500
            for (const callback of swimListeners) callback()
          }
          swimPhase.value = now < swimFeedbackUntil ? 'swimming' : swim.phase
          if (hands[primary]) {
            target = smoother.step(hands[primary], now / 1000)
            lastSeen = now
          } else if (now - lastSeen > 220) target = null
          status.value = target ? 'tracking' : 'ready'
        } catch (error) {
          detector.close(); detector = null; target = null; status.value = 'unavailable'
          console.warn('Hand tracking stopped; mouse navigation is still available.', error)
        }
      }
      if (!video || now - lastDetect > 1000) { handCount.value = 0; swimPhase.value = 'together'; swim.reset(); target = null; if (detector) status.value = 'ready' }
    }
    const previousX = palm[0], previousY = palm[1]
    const wasVisible = palm[2] > 0.1
    if (!target) { smoother.reset(); pinching = false; charge = 0 } // Tracking loss must never launch a ball.
    else {
      if (pinching && !target.pinching) release()
      if (target.pinching && !pinching) {
        anchor.set([palm[0], palm[1]])
        grabSize = target.size
      }
      pinching = target.pinching
      if (pinching) charge = Math.min(charge + dt * 0.75, 1)
      const k = 1 - Math.exp(-dt * 5)
      if (palm[2] < 0.01) { palm[0] = target.x; palm[1] = target.y }
      else { palm[0] += (target.x - palm[0]) * k; palm[1] += (target.y - palm[1]) * k }
    }
    const follow = 1 - Math.exp(-dt * 3.5)
    const vx = target && wasVisible ? Math.max(-0.65, Math.min(0.65, (palm[0] - previousX) / Math.max(dt, 0.001))) : 0
    const vy = target && wasVisible ? Math.max(-0.65, Math.min(0.65, (palm[1] - previousY) / Math.max(dt, 0.001))) : 0
    motion[0] += ((Math.abs(vx) < 0.012 ? 0 : vx) - motion[0]) * follow
    motion[1] += ((Math.abs(vy) < 0.012 ? 0 : vy) - motion[1]) * follow
    // Apparent palm size grows as the hand approaches the camera. Compare to the grab moment.
    const pull = pinching ? Math.max(0, Math.min(1, (target.size / Math.max(grabSize, 0.025) - 1.06) * 1.2)) : 0
    motion[2] += (pull - motion[2]) * follow
    motion[3] += ((pinching ? 1 : 0) - motion[3]) * follow
    palm[2] += ((target ? 1 : 0) - palm[2]) * (1 - Math.exp(-dt * 4))
    palm[3] += (charge - palm[3]) * (1 - Math.exp(-dt * 4))
    burst[2] += dt
    for (let i = 0; i < 12; i++) trail[i * 4 + 2] = Math.max(0, trail[i * 4 + 2] - dt * 0.85)
    sampleClock += dt
    if (target && sampleClock > 0.045) {
      sampleClock = 0
      trail.copyWithin(4, 0, 44)
      trail.set([palm[0], palm[1], 1, Math.random()], 0)
    }
  })
  return { palm, motion, anchor, trail, burst, status, handCount, swimPhase, onSwim }
}

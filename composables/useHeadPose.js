// Webcam head pose via MediaPipe Face Landmarker: nose for x/y, inter-pupil distance for lean (z).
// Same shape as usePointerInput(); smoothing (useSpring) happens downstream.

const MODEL_PATH = '/models/face_landmarker.task'
const WASM_PATH = '/mediapipe'

const NOSE = 1
const IRIS_LEFT = 468 // iris centres exist in the 478-point model
const IRIS_RIGHT = 473

const CALIBRATION_SECONDS = 2
const LOST_AFTER_MS = 500 // F6: after this, report not tracking so springs ease to neutral
const XY_GAIN = 6 // nose travel (fraction of frame) -> -1..1; ±0.17 of the frame = full range
const Z_GAIN = 2.5 // (ipdRatio - 1) -> lean; ratio 1.6 = full lean in
const Z_DEAD_ZONE = 0.03 // ignore tiny distance wobble around neutral
const Z_MIN = -0.5
const Z_MAX = 1.5

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v))

/**
 * @returns {{
 *   x: number, y: number, z: number, tracking: boolean,
 *   blendshapes: Record<string, number>,  // MediaPipe's 52 face scores 0..1 (eyeBlinkLeft, jawOpen, mouthSmileLeft...); raw, unsmoothed, only fresh while tracking
 *   status: import('vue').Ref<'loading'|'calibrating'|'tracking'|'lost'|'unavailable'>,
 *   progress: import('vue').Ref<number>,
 *   recalibrate: () => void,
 * }}
 */
export function useHeadPose() {
  const status = ref('loading')
  const progress = ref(0) // calibration 0..1
  const pose = { x: 0, y: 0, z: 0, tracking: false, blendshapes: {}, status, progress, recalibrate }

  let video = null
  let stream = null
  let landmarker = null
  let disposed = false
  let lastVideoTime = -1
  let lastSeen = 0
  let lastDetect = 0

  let neutral = null
  let samples = null // { x, y, ipd, n, seconds } while calibrating
  let filters = null

  function recalibrate() {
    if (!landmarker) return
    neutral = null
    samples = { x: 0, y: 0, ipd: 0, n: 0, seconds: 0 }
    filters = { x: createOneEuro(), y: createOneEuro(), z: createOneEuro() }
    progress.value = 0
    status.value = 'calibrating'
  }

  async function start() {
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: { width: 640, height: 480, facingMode: 'user' },
        audio: false,
      })
      video = Object.assign(document.createElement('video'), { muted: true, playsInline: true, srcObject: stream })
      await video.play()

      const { FaceLandmarker, FilesetResolver } = await import('@mediapipe/tasks-vision')
      const fileset = await FilesetResolver.forVisionTasks(WASM_PATH)
      const create = (delegate) =>
        FaceLandmarker.createFromOptions(fileset, {
          baseOptions: { modelAssetPath: MODEL_PATH, delegate },
          runningMode: 'VIDEO',
          numFaces: 1,
          outputFaceBlendshapes: true,
        })
      landmarker = await create('GPU').catch(() => create('CPU'))
      if (disposed) return dispose()
      recalibrate()
    } catch (err) {
      console.warn('Head tracking unavailable, using mouse fallback:', err)
      status.value = 'unavailable'
      dispose()
    }
  }

  function detect(dt) {
    if (!landmarker || video.readyState < 2 || video.currentTime === lastVideoTime) return
    lastVideoTime = video.currentTime

    const now = performance.now()
    const frameDt = lastDetect ? (now - lastDetect) / 1000 : dt
    lastDetect = now
    const result = landmarker.detectForVideo(video, now)
    const face = result.faceLandmarks[0]

    if (!face) {
      if (now - lastSeen > LOST_AFTER_MS && pose.tracking) {
        pose.tracking = false
        if (status.value === 'tracking') status.value = 'lost'
      }
      return
    }
    lastSeen = now
    for (const { categoryName, score } of result.faceBlendshapes?.[0]?.categories ?? []) pose.blendshapes[categoryName] = score

    // Raw measurements in camera pixels (landmarks are 0..1 of the frame)
    const nose = face[NOSE]
    const l = face[IRIS_LEFT]
    const r = face[IRIS_RIGHT]
    const ipd = Math.hypot((l.x - r.x) * video.videoWidth, (l.y - r.y) * video.videoHeight)

    if (samples) {
      // F2: average the neutral pose over ~2 s of seen frames
      samples.x += nose.x
      samples.y += nose.y
      samples.ipd += ipd
      samples.n++
      samples.seconds += frameDt
      progress.value = Math.min(samples.seconds / CALIBRATION_SECONDS, 1)
      if (samples.seconds < CALIBRATION_SECONDS) return
      neutral = { x: samples.x / samples.n, y: samples.y / samples.n, ipd: samples.ipd / samples.n }
      samples = null
    }

    // Camera image is unmirrored: moving to your right lowers nose.x, moving up lowers nose.y
    const x = clamp((neutral.x - nose.x) * XY_GAIN, -1, 1)
    const y = clamp((neutral.y - nose.y) * XY_GAIN, -1, 1)
    const lean = ipd / neutral.ipd - 1 // > 0 = leaning in
    const z = clamp(Math.sign(lean) * Math.max(Math.abs(lean) - Z_DEAD_ZONE, 0) * Z_GAIN, Z_MIN, Z_MAX)

    pose.x = filters.x(x, frameDt)
    pose.y = filters.y(y, frameDt)
    pose.z = filters.z(z, frameDt)
    pose.tracking = true
    status.value = 'tracking'
  }

  function dispose() {
    disposed = true
    stream?.getTracks().forEach((t) => t.stop())
    landmarker?.close()
    landmarker = null
    pose.tracking = false
  }

  useRAF(detect)
  onScopeDispose(dispose)
  start()

  return pose
}

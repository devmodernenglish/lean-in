// Face gestures (blinks, winks, mouth) -> world reactions. STUB: owned by the gestures work.
// Contract: `value` is a Float32Array(4) = (blink, mouth, wink, spare), each 0..1, already smoothed / shaped as pulses.
// DreamWorld copies it into the shader's `uGesture` every frame; the shader reacts in shaders/chunks/gestures.glsl.

/** @param {ReturnType<typeof useHeadPose>} head */
export function useGestures(head) {
  const gestures = { value: new Float32Array(4) }
  return gestures
}

// Mood from facial expression -> shader colourway. STUB: owned by the emotions work.
// Contract: `value` is a Float32Array(4) = (joy, sadness, surprise, tension), each 0..1, already smoothed.
// DreamWorld copies it into the shader's `uMood` every frame; the shader grades colour in shaders/chunks/mood.glsl.

/** @param {ReturnType<typeof useHeadPose>} head */
export function useMood(head) {
  const mood = { value: new Float32Array(4) }
  return mood
}

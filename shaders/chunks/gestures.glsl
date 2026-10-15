// --- gestures: how the world reacts to blinks, winks and mouth. STUB: owned by the gestures work.
// gesture = (blink, mouth, wink, spare), each 0..1, shaped on the CPU.

// Bend the screen coordinates before the world is drawn (ripples, breathing, pulls)
vec2 gestureWarp(vec2 uv, vec4 gesture, float time) {
  return uv;
}

// Add light / flashes on top of the composited, linear colour
vec3 gestureLight(vec3 col, vec2 uv, vec4 gesture, float time) {
  return col;
}

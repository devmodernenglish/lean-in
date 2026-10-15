// --- mood: colourway from the viewer's emotion. STUB: owned by the emotions work.
// mood = (joy, sadness, surprise, tension), each 0..1, smoothed on the CPU.
// Called by the main shader on the composited, linear colour, before vignette and tonemapping.

vec3 moodGrade(vec3 col, vec2 uv, vec4 mood, float time) {
  return col;
}

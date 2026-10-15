// --- particles: marine snow, rising bubbles, glowing plankton --------------
// Each uses the same trick: cut space into a grid and put (at most) one particle in each cell at a random,
// drifting spot. One lookup per pixel, no loops over particles.

// Marine snow: soft specks drifting and slowly sinking. size and blur in world units. Returns brightness.
float snow(vec2 p, float perUnit, float t, float seed, float size, float blur) {
  vec2 g = (p + vec2(0.0, t * 0.012)) * perUnit; // sinking
  vec2 id = floor(g);
  vec3 h = hash3(id + seed);
  vec2 pos = 0.5 + 0.32 * sin(t * (0.15 + 0.2 * h.z) + 6.2831 * h.xy);
  float d = length(fract(g) - pos) / perUnit;
  float s = size * (0.5 + h.z);
  return smoothstep(s + blur, s - blur * 0.5, d) * step(0.45, h.y) * (0.4 + 0.6 * h.x);
}

// Bubbles rising and wobbling: thin bright rings with a highlight. Returns brightness.
float bubbles(vec2 p, float perUnit, float t, float seed, float px) {
  vec2 g = (p - vec2(0.0, t * 0.05)) * perUnit; // rising
  vec2 id = floor(g);
  vec3 h = hash3(id + seed);
  if (h.y < 0.82) return 0.0; // only some cells hold a bubble
  vec2 pos = vec2(0.5 + 0.25 * sin(t * 1.7 + h.z * 30.0), 0.3 + 0.4 * h.x);
  vec2 d = (fract(g) - pos) / perUnit;
  float rad = (0.06 + 0.1 * h.z) / perUnit;
  float r = length(d);
  float ring = exp(-pow((r - rad) / (rad * 0.12 + px), 2.0));
  vec2 s = d - rad * vec2(-0.4, 0.45);
  float spec = exp(-dot(s, s) / (rad * rad * 0.04));
  return ring * 0.5 + spec * 0.8 + smoothstep(rad, 0.0, r) * 0.05;
}

// Bioluminescent plankton: tiny lights that breathe. Returns brightness (halo included).
float plankton(vec2 p, float perUnit, float t, float seed) {
  vec2 g = p * perUnit;
  vec2 id = floor(g);
  vec3 h = hash3(id + seed);
  if (h.y < 0.8) return 0.0;
  vec2 pos = 0.5 + 0.35 * sin(t * (0.1 + 0.1 * h.z) + 6.2831 * h.xy);
  float d = length(fract(g) - pos);
  float pulse = 0.5 + 0.5 * sin(t * (0.6 + h.x) + h.z * 6.2831);
  return (exp(-d * d * 4000.0) + 0.25 * exp(-d * d * 200.0)) * pulse;
}

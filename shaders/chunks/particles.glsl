// --- particles: drifting dust, luminous motes, glowing plankton --------------
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
  return smoothstep(s + blur, s - blur * 0.5, d) * step(0.45, h.y) * (0.4 + 0.6 * h.x) * (0.7 + 0.3 * sin(t * (0.3 + h.z * 0.4) + h.x * 6.2831));
}

// Luminous motes: a few bright pinpoints among faint drifting flecks, with soft halos.
// Each particle has its own size, intensity, phase, and gently curved path.
float lightMotes(vec2 p, float perUnit, float t, float seed, float px) {
  vec2 g = (p - vec2(t * 0.008, t * 0.021)) * perUnit;
  vec2 id = floor(g);
  vec3 h = hash3(id + seed);
  if (h.y < 0.42) return 0.0;
  float phase = h.z * 6.2831;
  float speed = 0.3 + h.x * 0.5;
  vec2 pos = 0.5 + vec2(0.24 * sin(t * speed * 0.6 + phase),
    0.22 * cos(t * speed * 0.45 + h.x * 9.0));
  vec2 d = (fract(g) - pos) / perUnit;
  float radius = (0.009 + 0.028 * h.z * h.z) / perUnit;
  float width = max(radius, px * 0.65);
  float core = exp(-dot(d, d) / (width * width));
  float haloWidth = width * 4.0;
  float halo = exp(-dot(d, d) / (haloWidth * haloWidth));
  float breathe = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(t * speed + phase), 2.0);
  float intensity = 0.10 + 1.7 * pow(h.x, 3.0);
  // A short, dim afterglow trails behind the bright particles as they drift upward.
  vec2 tail = d + vec2(0.0015, width * 2.0);
  float wake = exp(-pow(tail.x / (width * 1.2), 2.0) - pow(tail.y / (width * 3.5), 2.0));
  return (core + halo * 0.10 + wake * 0.08) * intensity * breathe;
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

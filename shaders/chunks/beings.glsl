// --- beings: the drifters, translucent bell-creatures that live in every world ---
// Drawn like real gelatinous animals: almost invisible in the middle, bright where you look through the
// most tissue (the edge), with fine radial canals, a pulsing bell and trailing threads. Additive light.

vec3 drifters(vec2 p, float perUnit, float t, float seed, float px, Realm rm) {
  vec2 g = p * perUnit;
  vec2 id = floor(g);
  vec3 h = hash3(id + seed);
  if (h.y < 0.68) return vec3(0.0); // not every cell holds one

  const float SIZE = 0.17; // bell radius, in cell units
  vec2 c = vec2(0.5 + 0.12 * sin(t * 0.13 + h.x * 6.2831), 0.72 + 0.06 * sin(t * 0.21 + h.z * 6.2831));
  vec2 l = (fract(g) - c) / SIZE;                    // drifter space: unit = bell radius, y up
  float tilt = 0.3 * sin(t * 0.17 + h.z * 9.0) + uMood.x * 0.16 * sin(t * 2.3 + h.x * 6.0);
  l = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * l;
  float lpx = px * perUnit / SIZE;                   // one pixel in drifter units

  float pulse = sin(t * (0.9 + 0.4 * h.x) + h.z * 6.2831); // the bell contracts and relaxes
  vec2 b = l / vec2(1.0 + 0.07 * pulse, 0.8 - 0.07 * pulse);
  float rb = length(b);
  float lip = b.y + 0.2 - 0.3 * b.x * b.x;            // the open underside curves up into the bell
  float upper = smoothstep(-0.12, 0.08, lip);
  float body = smoothstep(1.0 + lpx, 0.85, rb) * upper; // inside the bell
  float rim = exp(-pow((rb - 0.95) / (0.13 + lpx), 2.0)) * upper;
  float fill = body * (0.25 + 0.75 * rb * rb);          // brighter toward the edge: more tissue in the way
  float margin = exp(-pow(lip / 0.1, 2.0)) * smoothstep(1.0, 0.5, abs(b.x)) * (0.7 + 0.3 * sin(b.x * 24.0 + t * 2.0));
  float ang = atan(b.x, b.y + 0.2);
  float canals = exp(-pow(sin(ang * 4.0) * rb / (0.05 + lpx), 2.0)) * body * 0.25;
  float gonads = exp(-dot(b - vec2(0.0, 0.25), b - vec2(0.0, 0.25)) * 9.0) * 0.4; // a soft glowing core

  // Trailing threads: thin, swaying more the further they hang
  float threads = 0.0;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float below = clamp(-0.1 - l.y, 0.0, 3.0);
    float sway = 0.18 * sin(l.y * 2.2 + t * 0.9 + fi * 1.3 + h.x * 6.0) * below;
    float x0 = (fi - 2.0) * 0.36;
    threads += exp(-pow((l.x - x0 - sway) / (0.02 + lpx), 2.0)) * smoothstep(0.0, 0.3, below) * smoothstep(2.8, 0.0, below);
  }

  float glow = rim * 0.35 + fill * 0.45 + margin * 0.3 + canals + threads * 0.25;
  vec3 lights = rm.accent * rm.shape.w * (margin * 0.35 + gonads) * (0.6 + 0.4 * pulse); // bioluminescence
  return (rm.light * glow * 0.22 + lights * 0.5) * (1.0 + uMood.x * (1.3 + 0.5 * sin(t * 3.0 + h.x * 6.0)));
}

// --- structures: the grown machinery of each world -------------------------
// Everything here is a 2D silhouette with a fake 3D normal, so it can be lit like a real object:
// a cylinder seen side-on has normal (x across its width, 0, sqrt(1 - x^2)). Light comes from the surface above.

const vec3 LIGHT_DIR = vec3(-0.42, 0.78, 0.46); // from upper left, toward the viewer (normalised below)

// Lit material: soft diffuse, a tight highlight, a little ambient. albedo is the base colour.
vec3 shade(vec3 n, vec3 albedo, float lightAmt, float shininess, Realm rm) {
  vec3 L = normalize(LIGHT_DIR);
  float diff = max(dot(n, L), 0.0);
  float spec = pow(max(dot(n, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), shininess); // Blinn-Phong
  float wrap = 0.5 + 0.5 * n.y; // sky light: surfaces facing up see more of the bright water above
  return albedo * (rm.deep * 3.0 + rm.light * (diff * lightAmt + wrap * 0.18)) + rm.light * spec * lightAmt * 0.5;
}

// Caustics: the dancing net of light that waves focus onto surfaces. Edges of a slowly moving Voronoi.
float caustics(vec2 p, float t, float seed) {
  p += 0.35 * vec2(noise(p * 0.8 + t * 0.2), noise(p * 0.8 + 7.0 - t * 0.2)); // warp: wobbly, not polygonal
  Cell c = cells(p, seed, t * 2.5);
  return pow(1.0 - smoothstep(0.0, 0.28, c.f2 - c.f1), 4.0);
}

// Profile of a spire: its half-width at height y. Ribs, a slow bulge, and now and then a swollen node.
float spireWidth(float y, vec3 h, float freq, float phase) {
  float ribs = pow(abs(sin(y * freq + phase)), 10.0) + 0.5 * pow(abs(sin(y * freq * 0.5 + 1.0)), 40.0);
  float node = exp(-pow((fract(y * 0.45 + h.y) - 0.5) / 0.06, 2.0));
  return (0.025 + 0.03 * h.x) * (1.0 + 0.2 * sin(y * 1.7 + h.z * 9.0) + 0.3 * ribs + 0.7 * node);
}

// Spires: tall ribbed bio-mechanical towers, at most one per column of width CELL, swaying slightly.
// Returns colour (rgb) and coverage (a). density 0..1 = share of columns that hold a spire.
vec4 spires(vec2 p, float seed, float density, float px, float t, Realm rm) {
  const float CELL = 0.42;
  float ci = floor(p.x / CELL);
  vec3 h = hash3(vec2(ci, seed));
  if (h.y > density) return vec4(0.0);

  float cx = (ci + 0.5 + (h.z - 0.5) * 0.25) * CELL + 0.045 * sin(p.y * 1.3 + h.z * 6.0 + t * 0.05);
  float freq = 7.0 + 7.0 * h.z;
  float phase = h.x * 6.2831;
  float top = 0.1 + 1.2 * h.x;
  float taper = smoothstep(top + 0.3, top - 0.25, p.y);
  float w = spireWidth(p.y, h, freq, phase) * taper;
  w += (noise(vec2(p.x * 7.0, p.y * 5.0) + seed) - 0.5) * 0.008 * taper; // weathering
  float slope = (spireWidth(p.y + 0.01, h, freq, phase) * taper - w) * 100.0; // > 0: widening upward

  float dx = p.x - cx;
  float cov = smoothstep(px, -px, abs(dx) - w);
  if (cov <= 0.0) return vec4(0.0);

  float nx = clamp(dx / max(w, 1e-4), -1.0, 1.0);
  vec3 n = normalize(vec3(nx, -slope * 0.6, sqrt(1.0 - nx * nx))); // widening upward = facing down
  float lightAmt = mix(0.15, 1.0, smoothstep(-1.2, 0.9, p.y));
  vec3 albedo = mix(rm.shallow, vec3(0.5, 0.52, 0.48), 0.3);
  vec3 col = shade(n, albedo, lightAmt, 24.0, rm);
  col += rm.light * caustics(p * 7.0, t, seed) * 0.12 * lightAmt * smoothstep(-0.3, 0.6, n.y - n.x * 0.5);
  // Glowing pores on some ribs: the machinery is alive
  float pore = pow(abs(sin(p.y * freq + phase)), 40.0) * smoothstep(0.25, 0.0, abs(nx - 0.3 * sin(p.y * 3.0 + phase)))
    * smoothstep(0.4, 0.9, sin(p.y * freq / 3.0 + h.y * 7.0)); // smooth gate: only every few ribs
  col += rm.accent * pore * rm.shape.w * 0.7;
  return vec4(col, cov);
}

// The cradle that holds a vessel: a riveted ring around the glass, segmented arms curling away into the murk,
// and two cables rising to the surface. q is vessel space (radius 1). Returns colour (rgb) and coverage (a).
vec4 cradle(vec2 q, float px, float t, float seed, Realm rm) {
  float r = length(q);
  float a = atan(q.y, q.x);
  vec3 albedo = vec3(0.5, 0.4, 0.27) * mix(vec3(1.0), rm.shallow * 3.0, 0.25); // tarnished bronze, tinted by the water
  float lightAmt = mix(0.35, 1.0, smoothstep(-1.5, 1.5, q.y));
  vec3 murk = rm.deep * 2.5 + rm.shallow * 0.5;                       // what far parts fade into
  vec4 outCol = vec4(0.0);

  // Arms: N curling ribs. Bend the angle with radius so they curl, then find the nearest arm.
  const float N = 6.0;
  float sector = 6.2831 / N;
  float aa = a + 0.2 - 0.5 * (r - 1.05) + 0.04 * sin(t * 0.25 + r * 2.0 + seed);
  float k = floor(aa / sector + 0.5);
  vec3 h = hash3(vec2(k, seed));
  float len = 0.8 + 1.4 * h.x;                                    // how far out this arm reaches
  float along = clamp((r - 1.05) / len, 0.0, 1.0);
  float seg = smoothstep(0.55, 1.0, abs(sin(r * 11.0 + h.y * 6.0)));  // joints between segments
  float aw = 0.13 * (1.0 - along * 0.8) * (1.0 + 0.2 * seg);
  float across = (aa - k * sector) * r;                           // distance from the arm's spine
  float armCov = smoothstep(px, -px, abs(across) - aw) * step(1.1, r) * smoothstep(1.05 + len, 0.95 + len, r);
  if (armCov > 0.0) {
    float s = clamp(across / max(aw, 1e-4), -1.0, 1.0);
    vec2 tangent = vec2(-sin(a), cos(a));
    vec3 n = normalize(vec3(tangent * s, sqrt(1.0 - s * s) - seg * 0.3));
    vec3 c = shade(n, albedo * 0.8, lightAmt, 30.0, rm) * (1.0 - 0.35 * seg);
    c += rm.accent * rm.shape.w * 0.5 * seg * smoothstep(0.5, 0.0, abs(s)) * step(0.55, h.z); // lit joints
    outCol = vec4(mix(c, murk, along * 0.75), armCov);           // the arm curls away from us into the fog
  }

  // The ring: a torus seen face-on, grooved, with rivets around it
  float band = (r - 1.1) / 0.1;
  float ringCov = smoothstep(px, -px, abs(r - 1.1) - 0.1);
  if (ringCov > 0.0) {
    float b = clamp(band, -1.0, 1.0);
    vec2 radial = q / max(r, 1e-4);
    float groove = smoothstep(0.12, 0.0, abs(abs(b) - 0.55));
    vec3 n = normalize(vec3(radial * b, sqrt(1.0 - b * b)));
    vec3 ring = shade(n, albedo, lightAmt, 60.0, rm) * (1.0 - 0.5 * groove);
    vec2 rv = vec2((fract(a * 32.0 / 6.2831) - 0.5) * 6.2831 * r / 32.0, r - 1.1); // rivet space
    float rivet = smoothstep(0.018, 0.008, length(rv));
    ring += rm.light * rivet * 0.25 * lightAmt;
    outCol = vec4(mix(outCol.rgb, ring, ringCov), max(outCol.a, ringCov));
  }

  // Two cables rising from the ring to the surface far above, sagging slightly
  for (int i = 0; i < 2; i++) {
    float side = float(i) * 2.0 - 1.0;
    vec2 anchor = vec2(side * 0.62, 0.86);
    float y = q.y - anchor.y;
    float x = anchor.x + side * (0.25 * y + 0.04 * y * y);
    float cw = 0.03;
    float cc = smoothstep(px, -px, abs(q.x - x) - cw) * step(0.0, y);
    if (cc > 0.0) {
      float s = clamp((q.x - x) / cw, -1.0, 1.0);
      vec3 c = shade(vec3(s, 0.0, sqrt(1.0 - s * s)), albedo * 0.7, lightAmt, 20.0, rm);
      c = mix(c, murk, smoothstep(0.0, 3.0, y) * 0.6);
      outCol = vec4(mix(outCol.rgb, c, cc * (1.0 - outCol.a)), max(outCol.a, cc));
    }
  }
  return outCol;
}

// The floor of a world: a ridge of grown rock and coral along the bottom, lit along its top edge.
// Returns colour (rgb) and coverage (a).
vec4 seabed(vec2 p, float seed, float px, float t, Realm rm) {
  float hgt = -0.42 + 0.3 * (fbm(vec2(p.x * 1.3, seed)) - 0.5) + 0.06 * pow(abs(sin(p.x * 7.0 + seed)), 4.0)
    + 0.015 * (noise(vec2(p.x * 24.0, seed)) - 0.5);
  float d = p.y - hgt;
  float cov = smoothstep(px, -px, d);
  if (cov <= 0.0) return vec4(0.0);
  float depth = clamp(-d / 0.15, 0.0, 1.0);                       // 0 at the lit top edge, 1 deep inside
  float tex = fbm(p * vec2(9.0, 14.0) + seed);
  vec3 n = normalize(vec3((tex - 0.5) * 1.2, 1.0 - depth, 0.6));
  vec3 col = shade(n, mix(rm.shallow, vec3(0.45, 0.42, 0.35), 0.4) * (0.6 + 0.6 * tex), 0.8, 16.0, rm);
  col += rm.light * caustics(p * 6.0, t, seed) * 0.18 * (1.0 - depth);
  col = mix(col, rm.deep * 1.5, smoothstep(0.1, 1.0, depth) * 0.85);
  return vec4(col, cov);
}

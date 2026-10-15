// Seeded inhabitants share the same fine bioluminescent material, with different silhouettes.
vec3 inhabitants(vec2 p, float seed, float kind, float px, Realm rm) {
  vec3 col = vec3(0.0);
  for (int i = 0; i < 7; i++) {
    float fi = float(i);
    vec3 h = hash3(vec2(seed + 84.0, fi));
    vec2 centre = vec2((h.x - 0.5) * 2.6, (h.y - 0.5) * 1.25);
    centre += vec2(sin(uTime * (0.08 + h.z * 0.09) + fi) * 0.12,
                   cos(uTime * 0.12 + fi * 2.0) * 0.045);
    float size = 0.035 + 0.055 * h.z;
    vec2 q = (p - centre) / size;
    float aa = px / size + 0.015;
    // Bodies flex continuously from head to tail rather than moving as rigid symbols.
    q.y += 0.10 * sin(q.x * 2.1 - uTime * (0.7 + h.z * 0.5) + fi)
      * smoothstep(-0.8, 1.4, q.x);
    q.x *= 1.0 + 0.035 * sin(uTime * 0.9 + fi) + uMood.x * 0.09 * sin(uTime * 3.0 + fi);
    float glow = 0.0;
    if (kind < 1.0) {
      // Manta-like kites with rippling wings and a long filament tail.
      float wingX = abs(q.x) / 1.8;
      float wingCurve = 0.28 * sin(wingX * 2.8 - uTime * 0.8 + fi);
      float wing = length(vec2(q.x / 1.8,
        (q.y - wingCurve) / max(0.12, 0.50 * (1.0 - 0.65 * wingX))));
      glow = exp(-pow((wing - 1.0) / (0.045 + aa), 2.0)) * 0.55;
      glow += exp(-pow(q.x / (0.16 + aa), 2.0)) * exp(-q.y * q.y * 2.0) * 0.24;
      glow += exp(-wing * wing * 2.5) * 0.12;
      float tail = q.x - 0.14 * sin(q.y * 3.0 + uTime);
      glow += exp(-pow(tail / (0.018 + aa), 2.0)) * smoothstep(-2.7, -0.7, q.y) * (1.0 - smoothstep(-0.6, -0.2, q.y)) * 0.4;
    } else if (kind < 2.0) {
      // Tiny luminous fish, with translucent bodies and forked tails.
      float taper = 0.72 + 0.28 * smoothstep(-0.9, 0.5, q.x);
      float body = length(vec2(q.x * 0.85, q.y * 2.7 / taper));
      glow = exp(-pow((body - 0.8) / (0.06 + aa), 2.0)) * 0.55;
      glow += exp(-body * body * 3.0) * 0.15;
      float tail = abs(q.y + 0.12 * sin(uTime * 2.0 + fi)) - (q.x + 1.25) * 0.7;
      glow += exp(-pow(tail / (0.035 + aa), 2.0)) * smoothstep(-1.3, -1.1, q.x) * (1.0 - smoothstep(-0.9, -0.75, q.x)) * 0.45;
    } else {
      // Sinuous comb creatures: a glowing spine crossed by fine swimming cilia.
      float spine = q.y - 0.22 * sin(q.x * 2.3 + uTime * 0.8 + fi) - 0.07 * sin(q.x * 5.1 - uTime + fi);
      float ends = 1.0 - smoothstep(1.2, 1.8, abs(q.x));
      glow = exp(-pow(spine / (0.035 + aa), 2.0)) * ends * 0.5;
      float cilia = pow(max(cos(q.x * 26.0 + sin(q.x * 7.0 + fi) + uTime * 0.7), 0.0), 12.0);
      glow += cilia * exp(-pow(spine / 0.35, 2.0)) * ends * 0.35;
    }
    col += mix(rm.light, rm.accent, h.y * 0.6) * glow * 0.65;
  }
  return col * (1.0 + uMood.x * (1.1 + 0.3 * sin(uTime * 3.0 + seed)));
}

vec3 garden(vec2 p, float seed, float kind, float px, Realm rm) {
  vec3 col = vec3(0.0);
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    vec3 h = hash3(vec2(seed + 143.0, fi));
    float height = 0.20 + h.y * 0.44;
    float y = p.y + 0.48;
    float base = (h.x - 0.5) * 2.3;
    float sway = sin(y * 5.0 + uTime * 0.45 + fi) * y * 0.14;
    float x = p.x - base - sway;
    float gate = smoothstep(0.0, 0.025, y) * (1.0 - smoothstep(height - 0.03, height, y));
    float stem = exp(-pow(x / (0.0012 + px), 2.0));
    float detail;
    if (kind < 0.5) {
      // Feather gardens: paired luminous fronds along a fine swaying stalk.
      float branch = abs(x) - 0.065 * sin(clamp(y / height, 0.0, 1.0) * 3.14159)
        * (0.85 + 0.15 * sin(y * 33.0 + fi));
      detail = pow(max(cos(y * 100.0 - abs(x) * 65.0), 0.0), 18.0)
        * exp(-pow(branch / 0.04, 4.0)) * 0.45;
    } else {
      // Bulbous anemones: irregular petals grow around a gently breathing centre.
      vec2 q = vec2(x, (y - height * 0.72) * 1.25);
      float angle = atan(q.y, q.x);
      float petals = 0.048 + h.z * 0.024
        + 0.012 * sin(angle * 7.0 + sin(angle * 3.0 + fi) + uTime * 0.35);
      float membrane = length(q) - petals;
      detail = exp(-pow(membrane / (0.0025 + px), 2.0)) * 0.45;
      detail += exp(-dot(q, q) / 0.001) * 0.12;
    }
    col += (rm.light * stem * 0.25 + rm.accent * detail) * gate;
  }
  return col;
}

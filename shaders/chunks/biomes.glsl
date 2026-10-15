// Distinct materials for the three deeper realms, anchored in world coordinates.
vec3 biomeDetail(vec2 p, float seed, float realmIdx, float px, Realm rm) {
  vec3 col = vec3(0.0);
  if (realmIdx > 2.5 && realmIdx < 3.5) {
    // Thermal vents: broad, rising columns of luminous mineral silt.
    for (int i = 0; i < 4; i++) {
      float fi = float(i);
      float x = (hash(vec2(seed, fi + 92.0)) - 0.5) * 2.8;
      float y = p.y + 0.55;
      float sway = sin(y * 6.0 - uTime * 0.6 + fi) * max(y, 0.0) * 0.09;
      float width = 0.018 + max(y, 0.0) * 0.10;
      float plume = exp(-pow((p.x - x - sway) / width, 2.0));
      float billow = 0.45 + 0.55 * noise(vec2(p.x * 17.0 + seed, y * 9.0 - uTime * 0.8));
      float gate = smoothstep(0.0, 0.06, y) * exp(-max(y, 0.0) * 1.6);
      col += mix(rm.accent, rm.light, billow) * plume * billow * gate * 0.26;
    }
  } else if (realmIdx > 3.5 && realmIdx < 4.5) {
    // Silk membranes: layered, wide ribbons flowing through an open world.
    for (int i = 0; i < 3; i++) {
      float fi = float(i);
      float curve = (fi - 1.0) * 0.30 + 0.10 * sin(p.x * 2.5 + uTime * 0.18 + seed + fi);
      float d = p.y - curve;
      float folds = 0.5 + 0.5 * sin(p.x * 13.0 + sin(p.x * 4.0 + fi) - uTime * 0.35);
      float membrane = exp(-pow(d / 0.045, 2.0));
      float edge = exp(-pow((abs(d) - 0.055) / (0.004 + px), 2.0));
      col += mix(rm.accent, rm.light, folds) * (membrane * 0.065 + edge * 0.06);
    }
  } else if (realmIdx > 4.5) {
    // Crystal clusters: tapered facets with a solid, refracting interior.
    for (int i = 0; i < 7; i++) {
      float fi = float(i);
      vec3 h = hash3(vec2(seed + 216.0, fi));
      float height = 0.22 + h.y * 0.7;
      vec2 q = p - vec2((h.x - 0.5) * 2.6, -0.55);
      q.x -= q.y * (h.z - 0.5) * 0.4;
      float width = (0.025 + h.z * 0.055) * (1.0 - q.y / height);
      float gate = smoothstep(0.0, 0.02, q.y) * (1.0 - smoothstep(height - 0.015, height, q.y));
      float body = (1.0 - smoothstep(width, width + px * 2.0, abs(q.x))) * gate;
      float facet = 0.4 + 0.6 * smoothstep(-width, width, q.x);
      float edge = exp(-pow((abs(q.x) - width) / (0.002 + px), 2.0)) * gate;
      col += rm.light * (body * (0.7 + facet * 0.3) * 0.13 + edge * 0.075);
    }
  }
  return col;
}

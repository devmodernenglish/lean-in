// --- glass: clear bubbles, seen from outside and through -------------------
// q is "bubble space": the centre is 0 and the radius is 1. A sphere's surface normal there is
// (q, sqrt(1 - |q|^2)). Fresnel: glass reflects more at grazing angles, so the edge is bright and the middle clear.

const float GLASS_CLEAR = 0.7; // inside this radius the glass is perfectly clear: no tint, no bend, no highlight.
                               // This is what makes crossing in seamless: by the time a bubble fills the screen
                               // only its clear middle is on screen, so it looks exactly like the world inside.

// Refraction near the edge: the view bends outward, so the inner world bulges a little like through a lens
vec2 refractRim(vec2 q) {
  float s = smoothstep(GLASS_CLEAR, 1.0, length(q));
  return q * (1.0 + 0.3 * s * s);
}

// Looking through the glass from outside. Returns light added (rgb) and transmittance (a).
// look (-1..1) is where the viewer is: reflections slide the other way, like real glass.
// cue (0..1) brightens the edge of the bubble you are heading into.
vec4 glassFront(vec2 q, vec2 look, Realm rm, float cue) {
  float r = length(q);
  float rim = smoothstep(GLASS_CLEAR, 1.0, r);
  float nz = sqrt(max(1.0 - r * r, 0.0));
  float fresnel = pow(1.0 - nz, 5.0) * rim; // a thin edge, not a thick ring
  // Reflected environment: the bright surface above shows on the upper half
  vec3 env = mix(rm.shallow * 1.5, rm.light, smoothstep(-0.5, 0.9, q.y));
  // Faint dispersion: the very edge splits warm inside, cool outside, like a real lens
  vec3 disp = mix(vec3(1.2, 0.95, 0.85), vec3(0.85, 1.0, 1.25), smoothstep(0.93, 1.0, r));
  vec3 add = env * fresnel * 0.8 * disp;

  // Two soft speculars from the light above: a broad window and a small sharp glint
  vec2 lp = normalize(vec2(-0.55, 0.83)) - look * 0.08;
  vec2 hw = (q - lp * 0.8) * vec2(1.0, 1.6);
  add += rm.light * 0.22 * exp(-dot(hw, hw) * 30.0) * rim;
  vec2 hg = q - lp * 0.86;
  add += vec3(1.0) * 0.6 * exp(-dot(hg, hg) * 900.0) * rim;
  // Light focused through the sphere pools faintly on its lower inside edge
  add += rm.light * 0.12 * exp(-pow((r - 0.94) / 0.03, 2.0)) * smoothstep(-0.2, -0.9, q.y) * rim;
  // The target cue: the edge quietly brightens
  add += rm.light * cue * 0.35 * exp(-pow((r - 0.97) / 0.03, 2.0));

  float trans = 1.0 - 0.18 * rim * rim; // a touch of absorption at the edge only
  return vec4(add, trans);
}

// The outside of the edge: a hairline and a faint halo, so the edge reads as glass, not a hole.
vec3 glassOuterRim(float r, float px, Realm rm, float cue) {
  float line = exp(-pow((r - 1.0) / (0.008 + px), 2.0));
  return rm.light * (line * (0.5 + 0.4 * cue) + (0.05 + 0.12 * cue) * exp(-max(r - 1.0, 0.0) * 18.0));
}

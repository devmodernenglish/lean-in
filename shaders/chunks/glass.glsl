// --- glass: clear bubbles, seen from outside and through -------------------
// q is "bubble space": the centre is 0 and the radius is 1. A sphere's surface normal there is
// (q, sqrt(1 - |q|^2)). Fresnel: glass reflects more at grazing angles, so the edge is bright and the middle clear.

const float GLASS_CLEAR = 0.7; // inside this radius the glass is perfectly clear: no tint, no bend, no highlight.
                               // This is what makes crossing in seamless: by the time a bubble fills the screen
                               // only its clear middle is on screen, so it looks exactly like the world inside.

// Refraction near the edge: the view bends outward, so the inner world bulges a little like through a lens
vec2 refractRim(vec2 q) {
  float s = smoothstep(GLASS_CLEAR, 1.0, length(q));
  return q * (1.0 + 0.42 * s * s);
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
  vec3 add = env * fresnel * 0.32 * disp;

  // Broad pearly reflection stretched along the upper-left curve, like a sunlit soap bubble.
  vec2 lightDir = normalize(vec2(-0.55, 0.83) - look * 0.08);
  vec2 direction = q / max(r, 0.0001);
  float facing = max(dot(direction, lightDir), 0.0);
  float shoulder = exp(-pow((r - 0.89) / 0.075, 2.0));
  float crest = exp(-pow((r - 0.967) / 0.022, 2.0));
  vec3 pearl = vec3(0.88, 0.98, 1.0);
  add += pearl * shoulder * pow(facing, 18.0) * 0.60 * rim;
  add += vec3(1.0, 0.96, 0.88) * crest * pow(facing, 5.0) * 0.7 * rim;
  // A second faint curved reflection gives the transparent shell a little thickness.
  float innerArc = exp(-pow((r - 0.93) / 0.009, 2.0));
  add += pearl * innerArc * pow(facing, 3.0) * 0.16 * rim;
  vec2 glint = q - lightDir * 0.86;
  add += vec3(1.0, 0.98, 0.92) * exp(-dot(glint, glint) * 300.0) * 0.85 * rim;
  // Opposite the bright crest, a very fine champagne reflection catches the bottom curve.
  float lower = smoothstep(0.1, 0.85, -q.y);
  add += vec3(1.0, 0.71, 0.41) * 0.22 * lower
    * exp(-pow((r - 0.975) / 0.014, 2.0)) * rim;
  // A faint cool sidewall makes the surface read as a sphere around the clear centre.
  add += rm.light * 0.035 * exp(-pow((r - 0.91) / 0.07, 2.0)) * rim;
  // The target cue: the edge quietly brightens
  add += rm.light * cue * 0.35 * exp(-pow((r - 0.97) / 0.03, 2.0));

  float trans = 1.0 - 0.065 * rim * rim; // a touch of absorption at the edge only
  return vec4(add, trans);
}

// The outside of the edge: a hairline and a faint halo, so the edge reads as glass, not a hole.
vec3 glassOuterRim(vec2 q, float px, Realm rm, float cue) {
  float r = length(q);
  float line = exp(-pow((r - 1.0) / (0.003 + px * 0.65), 2.0));
  float upper = smoothstep(-0.5, 0.8, q.y - q.x * 0.4);
  vec3 reflection = mix(vec3(0.85, 0.58, 0.33), vec3(0.72, 0.94, 1.0), upper);
  return reflection * line * (0.26 + upper * 0.30 + 0.3 * cue)
    + rm.light * (0.009 + 0.03 * cue) * exp(-max(r - 1.0, 0.0) * 35.0);
}

// --- glass: the vessels, seen from outside and through ---------------------
// q is "vessel space": the vessel centre is 0 and its radius is 1. A sphere's surface normal there is
// (q, sqrt(1 - |q|^2)). Fresnel: glass reflects more at grazing angles, so the rim is bright and the middle clear.

const float GLASS_CLEAR = 0.7; // inside this radius the glass is perfectly clear: no tint, no bend.
                               // This is what makes the dive seamless: when the vessel fills the screen
                               // only its clear middle is on screen, so it looks exactly like the world inside.

// Refraction near the rim: bend the view outward so the inner world bulges like through a lens.
vec2 refractRim(vec2 q) {
  float s = smoothstep(GLASS_CLEAR, 1.0, length(q));
  return q * (1.0 + 0.35 * s * s);
}

// Looking through the glass from outside. Returns light added (rgb) and transmittance (a).
// look (-1..1) is where the viewer is: the window reflection slides the other way, like real glass.
vec4 glassFront(vec2 q, vec2 look, Realm rm) {
  float r = length(q);
  float rim = smoothstep(GLASS_CLEAR, 1.0, r);
  float nz = sqrt(max(1.0 - r * r, 0.0));
  float fresnel = pow(1.0 - nz, 3.0) * rim;
  // Reflected environment: the bright surface above shows on the top of the sphere
  vec3 env = mix(rm.deep * 2.0, rm.light * 0.8, smoothstep(-0.6, 0.9, q.y));
  vec3 add = env * fresnel * 0.9 * mix(vec3(1.25, 0.95, 0.8), vec3(0.8, 1.0, 1.25), smoothstep(0.9, 1.0, r)); // faint dispersion
  // A bright crescent along the upper-left rim (facing the light) and a soft window reflection
  float side = dot(q / max(r, 1e-4), normalize(vec2(-0.55, 0.85) - look * 0.12));
  add += rm.light * exp(-pow((r - 0.9) / 0.035, 2.0)) * smoothstep(0.55, 0.95, side) * 0.8;
  vec2 hp = (q - vec2(-0.42, 0.5) + look * 0.06) * vec2(1.0, 1.8);
  add += rm.light * 0.25 * smoothstep(0.22, 0.0, length(hp)) * rim;
  // Light focused through the sphere pools on its lower inside edge (a caustic)
  add += rm.light * 0.35 * exp(-pow((r - 0.93) / 0.04, 2.0)) * smoothstep(-0.2, -0.9, q.y) * rim;
  float trans = 1.0 - 0.45 * rim * rim; // thicker glass at the edge absorbs more
  return vec4(add, trans);
}

// The outside of the rim: a thin bright line and a faint halo, so the edge reads as glass, not a hole.
vec3 glassOuterRim(float r, float px, Realm rm) {
  float line = exp(-pow((r - 1.0) / (0.012 + px), 2.0));
  return rm.light * (line * 0.9 + 0.12 * exp(-max(r - 1.0, 0.0) * 14.0));
}

// Small distant bubble habitats: glass spheres you can see through, each holding a hint of another world.
// bg is what lies behind; returns the bubble composited over it, coverage in .a.
vec4 habitat(vec3 bg, vec2 q, float px, Realm rm, Realm inner, vec2 look) {
  float r = length(q);
  float cov = smoothstep(1.0 + px, 1.0 - px, r);
  if (cov <= 0.0) return vec4(0.0);
  vec3 tint = mix(inner.deep, inner.shallow, smoothstep(-1.0, 1.0, q.y)) * 1.6; // the world inside
  vec2 g = q + vec2(0.0, 0.45);
  vec3 inside = mix(bg, tint, 0.55) + inner.accent * 0.25 * exp(-dot(g, g) * 5.0); // something glowing inside
  vec4 gl = glassFront(q, look, rm);
  return vec4(inside * gl.a + gl.rgb + glassOuterRim(r, px, rm) * 0.4, cov);
}

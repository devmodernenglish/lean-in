// --- medium: the water (or nebula) every world floats in ------------------
// Light comes from a surface far above: bright near the top, murky below, with shafts of light fanning down.
// Coordinates are a world's own "home view" units: y spans -0.5..0.5 when that world fills the screen.

// One realm's look, unpacked from the REALMS table in DreamWorld.vue
struct Realm {
  vec3 deep;    // colour of the depths (bottom of the frame)
  vec3 shallow; // colour toward the light (top of the frame)
  vec3 light;   // colour of the light shafts, highlights and caustics
  vec3 accent;  // bioluminescence: plankton, pores on the spires
  vec4 shape;   // strengths: (light shafts, spire density, particles, bioluminescence)
};

const vec2 SUN = vec2(-0.5, 3.2); // where the shafts come from: above the frame, a little left

// Colour of the medium at p, without shafts. Also the fog colour: far things melt into this.
vec3 medium(vec2 p, Realm rm) {
  float up = smoothstep(-1.2, 1.0, p.y);
  vec3 col = mix(rm.deep, rm.shallow, up * up);
  col += rm.light * 0.16 * exp(-length((p - SUN) * vec2(0.6, 0.5)) * 0.9) * 3.0; // the surface glow above
  return col;
}

// Volumetric light shafts: rays fanning out from SUN. Two slow noises in angle make them shimmer like
// light through waves; they fade with distance from the source. Returns intensity 0..~1.
float shafts(vec2 p, float t, float seed) {
  vec2 d = p - SUN;
  float a = atan(d.x, -d.y); // angle of this pixel seen from the source (0 = straight down)
  float n = noise(vec2(a * 22.0 + seed, t * 0.06)) * noise(vec2(a * 53.0 - seed, t * 0.1 + 4.0));
  return n * n * 3.0 * smoothstep(-1.6, 0.6, p.y) * smoothstep(0.7, 0.15, abs(a));
}

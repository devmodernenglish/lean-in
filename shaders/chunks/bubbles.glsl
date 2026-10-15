// --- bubbles: where the glass bubbles of a world sit ----------------------
// MUST stay identical to utils/bubbles.js: JS decides when you cross into a bubble, the shader draws it.
// Both derive everything from a world's integer seed with the same 32-bit integer hash, so they agree exactly.

const float WORLD_H = 2.0; // a child world's units per bubble radius (its home view fits well inside the clear glass)
#define SLOTS 6
// Irregular anchor regions with seeded scatter and independent drifting speeds.
const vec2 SLOT_POS[SLOTS] = vec2[SLOTS](
  vec2(-0.06, -0.03), vec2(-0.57, 0.24), vec2(0.48, 0.29), vec2(-0.40, -0.31), vec2(0.59, -0.22), vec2(0.04, 0.39)
);

// Integer hash (Chris Wellons' lowbias32): scrambles all 32 bits. JS reproduces it with Math.imul.
uint hash32(uint x) {
  x ^= x >> 16u;
  x *= 0x7feb352du;
  x ^= x >> 15u;
  x *= 0x846ca68bu;
  x ^= x >> 16u;
  return x;
}

// Top 24 bits as a float 0..1: exact in float32, so JS and GLSL get the very same number
float u01(uint x) { return float(x >> 8u) / 16777216.0; }

struct Bubble {
  vec2 c;      // centre, in its world's units (with drift and parallax applied)
  float r;     // radius
  float depth; // 0 near .. 1 far: far ones move against the head and look hazier
  float child; // seed of the world inside (24-bit, exact as a float)
  float on;    // 1 if this slot holds a bubble
};

// Bubble in slot i of the world with this seed, seen at camera scale s (world units per screen height).
// While a bubble is small on screen it drifts and shows parallax; as it grows to fill the view it settles,
// so by the time you cross into it, it is perfectly still.
Bubble bubbleAt(uint seed, int i, float s, float t, vec2 head) {
  uint h = hash32(seed ^ (uint(i + 1) * 0x9E3779B9u));
  float f0 = u01(h); h = hash32(h);
  float f1 = u01(h); h = hash32(h);
  float f2 = u01(h); h = hash32(h);
  float f3 = u01(h); h = hash32(h);
  float f4 = u01(h); h = hash32(h);
  float f5 = u01(h);

  Bubble b;
  b.on = (i < 2 || f0 > 0.35) ? 1.0 : 0.0;
  b.r = i == 0 ? 0.09 + 0.05 * f3 : 0.05 + 0.08 * f3;
  b.depth = i == 0 ? 0.2 * f4 : f4;
  float settle = 1.0 - smoothstep(0.25, 0.6, b.r / s);
  float ph = f5 * 6.2831;
  vec2 drift = (0.009 + 0.012 * f0) * vec2(sin(t * (0.13 + 0.1 * f1) + ph), sin(t * (0.11 + 0.09 * f2) + ph * 1.3));
  vec2 par = head * mix(0.04, -0.05, b.depth) * min(s, 1.0);
  b.c = SLOT_POS[i] + (vec2(f1, f2) - 0.5) * 0.18 + settle * (drift + par);
  b.child = float(hash32(seed * 7u + uint(i) + 1u) & 0xFFFFFFu);
  return b;
}

// Realm (0..2) of the world inside a bubble: always different from its parent's, and varied between siblings
float childRealm(float realm, float childSeed) {
  return mod(realm + 1.0 + float(uint(childSeed) % 2u), 3.0);
}

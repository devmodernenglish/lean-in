#version 300 es
precision highp float;

// "Every vessel holds a world": a bottomless chain of underwater worlds.
// Each world is murky water lit from above, grown spires, drifting snow, and one glass vessel held in a
// bronze cradle. Inside that vessel is the next world, which has its own vessel, and so on forever.
// The camera dives straight into the chain, so nothing ever fades out: the vessel grows until its clear
// middle fills the screen, and at that moment the picture IS the next world at its home framing.

#define REALMS 3 // must match REALMS.length in DreamWorld.vue

uniform vec2 uResolution;          // canvas size in pixels (set by GlCanvas)
uniform float uTime;               // seconds since start (set by GlCanvas)
uniform vec2 uHeadOffset;          // @slider -0.5..0.5 default 0 "Viewer offset in screen units: drives parallax"
uniform float uDescent;            // @slider 0..20 default 0 "How deep we are, in octaves (log2 of zoom); endless"
uniform vec2 uLook;                // smoothed viewer position -1..1: glass reflections slide against it
uniform vec3 uRealm[REALMS * 4];   // per realm: deep, shallow, light, accent colours
uniform vec4 uShape[REALMS];       // per realm: light shafts, spire density, particles, bioluminescence
uniform vec4 uMood;                // (joy, sadness, surprise, tension) 0..1, see chunks/mood.glsl
uniform vec4 uGesture;             // (blink, mouth, wink, spare) 0..1, see chunks/gestures.glsl
uniform float uFade;               // @slider 0..1 default 1 "Fade in from black"

out vec4 fragColor;

#include "noise"
#include "cells"
#include "medium"
#include "structures"
#include "glass"
#include "particles"
#include "beings"
#include "tonemap"
#include "mood"
#include "gestures"

// --- The chain. Each world maps into the vessel of its parent by one fixed similarity transform:
//     parent = VESSEL_C + (VESSEL_R / WORLD_H) * rotate(TWIST) * child
// so one "level" deeper is always the same zoom, LEVEL_OCT octaves.
const vec2 VESSEL_C = vec2(0.14, -0.03); // where the vessel sits in its world's home view
const float VESSEL_R = 0.22;             // vessel radius in its world (screen height = 1)
const float WORLD_H = 1.5;               // the inner world's units per vessel radius. Must exceed the screen's
                                         // half-diagonal, so the glass rim is off screen when we cross over
const float TWIST = 0.25;                // radians the chain turns per level: a slow spiral dive
const float LEVEL_OCT = 2.7692;          // log2(WORLD_H / VESSEL_R): octaves of zoom per level
const float MIN_VESSEL = 0.006;          // vessels smaller than this on screen (~5 px) get a cheap glow inside

const vec3 BASE = vec3(0.020, 0.031, 0.078); // #050814: the colour we fade in from
const float EXPOSURE = 1.25;

mat2 rot(float a) { return mat2(cos(a), sin(a), -sin(a), cos(a)); }

Realm realm(float j) {
  int i = int(mod(j + 0.5, float(REALMS))); // j is a whole number; +0.5 guards against float error
  return Realm(uRealm[i * 4], uRealm[i * 4 + 1], uRealm[i * 4 + 2], uRealm[i * 4 + 3], uShape[i]);
}

// Where the vessel of world j sits: home spot plus a slow bob, different per level
vec2 vesselCenter(float j) {
  return VESSEL_C + 0.012 * vec2(sin(uTime * 0.19 + j * 1.7), sin(uTime * 0.23 + j * 2.9));
}

// The one point that stays still on screen while we dive (the fixed point of the parent<-child transform)
vec2 fixedPoint(vec2 c) {
  return inverse(mat2(1.0) - (VESSEL_R / WORLD_H) * rot(TWIST)) * c;
}

// Coordinates for one depth layer of world j, seen while the camera is fj levels into it (fj < 0: the world
// is still nested inside an outer vessel). rate < 1: far layers grow slower than the vessel as we dive;
// rate > 1: near layers rush past. par: parallax, in screen units per unit of head offset (negative = behind
// the vessel, positive = in front). Both only change things while the world is in front of us (fj > 0),
// so a nested world looks exactly like its own home view, which keeps the crossover seamless.
vec2 layerP(vec2 p, vec2 xs, float fj, float rate, float par) {
  float z = exp2(max(fj, 0.0) * LEVEL_OCT * (1.0 - rate));
  return xs + (p - xs) * z + uHeadOffset * par * min(1.0, exp2(-fj * LEVEL_OCT));
}

// Snow, bubbles and plankton drifting between us and world j's vessel. They fly past and are gone
// before the vessel fills the screen (fj -> 1).
vec3 frontParticles(vec2 p, vec2 xs, float j, float fj, float px, Realm rm) {
  // Fade out as they fly past (fj -> 1); and fade in as a nested world comes closer (fj from -1 to 0),
  // so a world far inside a vessel is not a glitter of sub-pixel specks
  float fade = smoothstep(0.95, 0.45, fj) * smoothstep(-0.8, 0.0, fj) * rm.shape.z;
  if (fade <= 0.0) return vec3(0.0);
  float seed = j * 7.31;
  vec2 a = layerP(p, xs, fj, 1.35, 0.05);
  float sn = snow(a, 24.0, uTime, seed, 0.0018, px * 1.5 + 0.0006);
  float pl = plankton(a + 0.37, 11.0, uTime, seed + 5.0);
  float bu = bubbles(layerP(p, xs, fj, 1.6, 0.09), 7.0, uTime, seed + 3.0, px);
  float bokeh = snow(layerP(p, xs, fj, 2.2, 0.16), 4.0, uTime * 0.7, seed + 9.0, 0.014, 0.012);
  return (rm.light * (sn * 0.25 + bu * 0.3 + bokeh * 0.08) + rm.accent * pl * rm.shape.w * 0.6) * fade;
}

// Far things melt into the water: mix toward the medium's colour, with a little of the light shafts
vec3 fogged(vec3 col, vec2 m, float amount, float shaft, Realm rm) {
  return mix(col, medium(m, rm) + rm.light * shaft * 0.12, amount);
}

// Everything in world j outside its vessel (or, for a vessel too small to enter, a glow inside it).
// p: world j coordinates. q, r: the pixel in vessel space and its distance from the vessel centre.
vec3 world(vec2 p, float j, float fj, vec2 c, vec2 q, float r, Realm rm) {
  float seed = j * 7.31;
  float px = exp2(-fj * LEVEL_OCT) / uResolution.y; // one pixel in world j's units: keeps edges crisp
  vec2 xs = fixedPoint(c);

  // Water, and light shafts far behind everything
  vec2 m = layerP(p, xs, fj, 0.3, -0.1);
  float shaft = shafts(m, uTime, seed) * rm.shape.x;
  vec3 col = medium(m, rm) + rm.light * shaft * 0.12;

  // Far spires: small, thin, deep in the fog
  vec2 s1 = layerP(p, xs, fj, 0.45, -0.07);
  vec4 sp = spires(s1 * 1.8 + vec2(seed * 0.37, 0.0), seed + 11.0, rm.shape.y, px * 10.0, uTime, rm); // soft edges: out of focus
  col = mix(col, fogged(sp.rgb, s1, 0.72, shaft, rm), sp.a);

  // Bubble habitats drifting at middle distance, each glowing with a hint of another world
  vec2 s2 = layerP(p, xs, fj, 0.6, -0.045);
  vec2 g = (s2 + vec2(uTime * 0.004, 0.0)) * 2.4;
  vec3 hh = hash3(floor(g) + seed);
  if (hh.y > 0.55) {
    vec2 pos = 0.3 + 0.4 * hh.xz + 0.04 * sin(uTime * 0.3 + hh.xy * 6.2831);
    float rad = 0.07 + 0.11 * hh.z;
    vec4 hb = habitat(col, (fract(g) - pos) / rad, px * 8.0 / rad, rm, realm(j + 1.0 + floor(hh.x * 2.0)), uLook);
    col = mix(col, fogged(hb.rgb, s2, 0.45, shaft, rm), hb.a);
  }

  // Near spires: bigger, clearer, with caustics and glowing pores
  vec2 s3 = layerP(p, xs, fj, 0.75, -0.025);
  sp = spires(s3 * 0.9 + vec2(seed * 0.53 + 0.21, 0.0), seed + 23.0, rm.shape.y * 0.8, px * 3.0, uTime, rm);
  col = mix(col, fogged(sp.rgb, s3, 0.3, shaft, rm), sp.a);

  // The floor, at about the same depth as the vessel
  vec2 s4 = layerP(p, xs, fj, 0.85, -0.012);
  vec4 sb = seabed(s4, seed, px * 2.0, uTime, rm);
  col = mix(col, fogged(sb.rgb, s4, 0.25, shaft, rm), sb.a);

  // Drifting murk: slow clouds of silt between the spires and the vessel, then a last veil of light
  float murk = smoothstep(0.4, 0.85, fbm(m * 1.4 + vec2(uTime * 0.012, seed)));
  col = mix(col, medium(m, rm) * 1.15, murk * 0.55);
  col += rm.light * shaft * 0.08;

  // Drifters: translucent bell-creatures, between the murk and the vessel
  vec2 s5 = layerP(p, xs, fj, 0.9, -0.01);
  col += drifters(s5 + vec2(seed * 0.29, 0.0), 1.8, uTime, seed + 31.0, px, rm) * 0.8;

  // The vessel itself
  if (r < 1.0) {
    // Too small to enter: fill it with the average look of the world inside
    Realm inner = realm(j + 1.0);
    vec3 inside = mix(inner.deep, inner.shallow, smoothstep(-1.0, 1.0, q.y) * 0.8) + inner.light * 0.06;
    vec4 gl = glassFront(q, uLook, rm);
    col = inside * gl.a + gl.rgb;
  } else {
    vec4 cr = cradle(q, px / VESSEL_R, uTime, seed, rm);
    col = mix(col, fogged(cr.rgb, p, 0.08, shaft, rm), cr.a);
    col += glassOuterRim(r, px / VESSEL_R, rm); // the glass lip, over the inner edge of the ring
  }

  return col + frontParticles(p, xs, j, fj, px, rm);
}

void main() {
  // Centred, aspect-correct coords: y spans -0.5..0.5, x wider on landscape screens.
  vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution) / uResolution.y;
  vec2 screenUv = uv;
  uv = gestureWarp(uv, uGesture, uTime); // HOOK: keep

  // Which level we are in (k) and how far through it (f, 0..1)
  float level = uDescent / LEVEL_OCT;
  float k = floor(level);
  float f = level - k;

  // Camera: zoom (and turn) about the fixed point. At f = 1 this lands exactly on world k+1's home view.
  vec2 xs = fixedPoint(vesselCenter(k));
  vec2 p = xs + exp2(-f * LEVEL_OCT) * (rot(TWIST * f) * (uv - xs));

  // Walk inward: while the pixel is inside a vessel, add that world's glass and particles in front,
  // then step into the world inside. The world the pixel finally lands in is drawn in full.
  vec3 add = vec3(0.0); // light from things in front (glass reflections, particles)
  float trans = 1.0;    // how much of what lies behind still shows through
  vec3 col = vec3(0.0);
  for (int d = 0; d < 4; d++) {
    float j = k + float(d);
    float fj = f - float(d);
    Realm rm = realm(j);
    vec2 c = vesselCenter(j);
    vec2 q = (p - c) / VESSEL_R;
    float r = length(q);
    bool enter = r < 1.0 && d < 3 && VESSEL_R * exp2(fj * LEVEL_OCT) > MIN_VESSEL;
    if (!enter) {
      col = world(p, j, fj, c, q, r, rm);
      break;
    }
    add += trans * frontParticles(p, fixedPoint(c), j, fj, exp2(-fj * LEVEL_OCT) / uResolution.y, rm);
    vec4 gl = glassFront(q, uLook, rm);
    add += trans * gl.rgb;
    trans *= gl.a;
    p = rot(-TWIST) * refractRim(q) * WORLD_H; // into the child world's coordinates
  }

  col = mix(BASE, add + trans * col, uFade);
  col = gestureLight(col, screenUv, uGesture, uTime); // HOOK: keep
  col = moodGrade(col, screenUv, uMood, uTime);       // HOOK: keep
  col *= vignette(screenUv);
  col = tonemap(col * EXPOSURE);
  fragColor = vec4(dither(col, gl_FragCoord.xy), 1.0);
}

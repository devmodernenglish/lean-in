#version 300 es
precision highp float;
precision highp int;

// "Every bubble holds a world": an endless tree of underwater worlds.
// Each world is murky water lit from above, grown spires, drifting snow and jellies, and a handful of clear
// glass bubbles. Inside each bubble is a whole new world with bubbles of its own, and so on forever.
// You steer toward a bubble with your head and lean in: nothing fades out, the bubble grows until its clear
// middle fills the screen, and from then on you are in the world inside it.

#define REALMS 6 // must match REALMS.length in DreamWorld.vue

uniform vec2 uResolution;          // canvas size in pixels (set by GlCanvas)
uniform float uTime;               // seconds, mood-scaled (set by DreamWorld)
uniform vec2 uHeadOffset;          // @slider -0.5..0.5 default 0 "Viewer offset in screen units: drives parallax"
uniform vec2 uLook;                // smoothed viewer position -1..1: glass reflections slide against it
uniform vec2 uRoot;                // (seed, realm 0..2) of the world we start drawing from: the parent of where you are
uniform vec3 uCam;                 // camera centre (x, y) and scale (world units per screen height), in uRoot's units
uniform float uTarget;             // seed of the bubble you are heading into (its rim brightens)
uniform float uCue;                // @slider 0..1 default 0 "How strongly the target bubble is marked"
uniform vec3 uRealm[REALMS * 4];   // per realm: deep, shallow, light, accent colours
uniform vec4 uShape[REALMS];       // per realm: light shafts, spire density, particles, bioluminescence
uniform vec4 uMood;                // (joy, sadness, surprise, tension) 0..1, see chunks/mood.glsl
uniform vec4 uGesture;             // (blink, mouth, wink, spare) 0..1, see chunks/gestures.glsl
uniform vec4 uPalm;
uniform vec4 uHandMotion; // hand velocity, depth pull, grip
uniform vec2 uHandAnchor; // gel grab position
uniform vec4 uHandTrail[12];
uniform vec4 uHandBurst;
uniform float uFade;               // @slider 0..1 default 1 "Fade in from black"

out vec4 fragColor;

#include "noise"
#include "cells"
#include "medium"
#include "structures"
#include "glass"
#include "particles"
#include "beings"
#include "bubbles"
#include "ecosystems"
#include "biomes"
#include "tonemap"
#include "mood"
#include "gestures"
#include "hands"

const float MIN_BUBBLE = 0.006; // bubbles smaller than this on screen (~5 px) get a cheap glow inside
const vec3 BASE = vec3(0.020, 0.031, 0.078); // #050814: the colour we fade in from
const float EXPOSURE = 1.25;
const float WATER_SHIMMER = 0.0012; // screen heights the view sways (~1-2 px); 0 turns the shimmer off

Realm realm(float idx) {
  int i = int(idx + 0.5) % REALMS; // idx is a whole number; +0.5 guards against float error
  return Realm(uRealm[i * 4], uRealm[i * 4 + 1], uRealm[i * 4 + 2], uRealm[i * 4 + 3], uShape[i]);
}

// A world's own scenery offset, from its seed (kept small for float precision)
float seedOffset(uint seed) { return float(seed % 997u) * 0.37; }

// Coordinates for one depth layer of a world seen with camera centre cam and scale s (s < 1: zoomed in past
// its home view; s > 1: the world is small, inside a bubble). rate < 1: far layers grow slower than the bubbles
// as you dive; rate > 1: near layers rush past. par: parallax per unit of head offset (negative = far).
// Both only act while zoomed in (s < 1), so a nested world looks exactly like its own home view.
vec2 layerP(vec2 p, vec2 cam, float s, float rate, float par) {
  float sc = min(s, 1.0);
  return cam + (p - cam) * pow(sc, rate - 1.0) + uHeadOffset * par * sc;
}

// Snow, rising bubbles and plankton drifting in front of everything. They fly past and are gone before any
// bubble can fill the screen (s -> 0.09), and fade in as a nested world comes closer (s from 4 to 1.3).
vec3 frontParticles(vec2 p, vec2 cam, float s, float seed, Realm rm) {
  float fade = smoothstep(0.09, 0.3, s) * smoothstep(4.0, 1.3, s) * rm.shape.z;
  if (fade <= 0.0) return vec3(0.0);
  float px = s / uResolution.y;
  vec2 a = layerP(p, cam, s, 1.35, 0.05);
  float sn = snow(a, 24.0, uTime, seed, 0.0012, px * 1.5 + 0.0005);
  float pl = plankton(a + 0.37, 11.0, uTime, seed + 5.0);
  float bu = bubbles(layerP(p, cam, s, 1.6, 0.09), 7.0, uTime, seed + 3.0, px);
  float bokeh = snow(layerP(p, cam, s, 2.2, 0.16), 4.0, uTime * 0.7, seed + 9.0, 0.014, 0.012);
  return (rm.light * (sn * 0.25 + bu * 0.3 + bokeh * 0.08) + rm.accent * pl * rm.shape.w * 0.6) * fade;
}

// How strongly bubble b is marked as where you are heading
float cueOf(Bubble b) { return abs(b.child - uTarget) < 0.5 ? uCue : 0.0; }

// Far things melt into the water: mix toward the medium's colour, with a little of the light shafts
vec3 fogged(vec3 col, vec2 m, float amount, float shaft, Realm rm) {
  return mix(col, medium(m, rm) + rm.light * shaft * 0.12, amount);
}

// Everything in one world that is not inside an entered bubble. p: this world's coordinates.
vec3 scenery(vec2 p, vec2 cam, float s, uint wseed, float realmIdx, Realm rm) {
  float seed = seedOffset(wseed);
  float px = s / uResolution.y; // one pixel in this world's units: keeps edges crisp

  // Water, and light shafts far behind everything
  vec2 m = layerP(p, cam, s, 0.3, -0.1);
  float shaft = shafts(m, uTime, seed) * rm.shape.x;
  vec3 col = medium(m, rm) + rm.light * shaft * 0.12;

  // Far spires: small, thin, deep in the fog
  vec2 terrainStretch = realmIdx < 0.5 ? vec2(0.8, 1.4) : realmIdx < 1.5 ? vec2(1.5, 0.65) : realmIdx < 2.5 ? vec2(0.65, 1.8) : realmIdx < 3.5 ? vec2(1.3, 1.8) : vec2(1.0);
  vec2 s1 = layerP(p, cam, s, 0.45, -0.07);
  vec4 sp = spires(s1 * terrainStretch * 1.8 + vec2(seed * 0.37, 0.0), seed + 11.0, rm.shape.y * (0.35 + 0.65 * hash(vec2(seed, 72.0))), px * 10.0, uTime, rm); // soft edges: out of focus
  col = mix(col, fogged(sp.rgb, s1, 0.72, shaft, rm), sp.a);

  // Near spires: bigger, clearer, with caustics and glowing pores
  vec2 s3 = layerP(p, cam, s, 0.75, -0.025);
  sp = spires(s3 * terrainStretch * 0.9 + vec2(seed * 0.53 + 0.21, 0.0), seed + 23.0, rm.shape.y * (0.25 + 0.65 * hash(vec2(seed, 19.0))), px * 3.0, uTime, rm);
  col = mix(col, fogged(sp.rgb, s3, 0.3, shaft, rm), sp.a);

  // The floor
  vec2 s4 = layerP(p, cam, s, 0.85, -0.012);
  vec4 sb = seabed(s4, seed, px * 2.0, uTime, rm);
  float floorAmount = realmIdx > 3.5 && realmIdx < 4.5 ? 0.0 : 1.0;
  col = mix(col, fogged(sb.rgb, s4, 0.25, shaft, rm), sb.a * floorAmount);

  // Drifting murk: slow clouds of silt, then a last veil of light
  float murk = smoothstep(0.4, 0.85, fbm(m * 1.4 + vec2(uTime * 0.012, seed)));
  col = mix(col, medium(m, rm) * 1.15, murk * 0.55);
  col += rm.light * shaft * 0.08;

  // Each realm has a distinct ecosystem, with stable variation from its seed.
  vec2 s5 = layerP(p, cam, s, 0.9, -0.01);
  float species = realmIdx < 0.5 ? 0.0 : realmIdx < 1.5 ? 3.0 : realmIdx < 2.5 ? 1.0 + float(wseed % 2u) : realmIdx < 3.5 ? 3.0 : realmIdx < 4.5 ? 1.0 : 0.0;
  if (species < 0.5) {
    col += drifters(s5 + vec2(seed * 0.29, 0.0), 1.8, uTime, seed + 31.0, px, rm) * 0.8;
  } else {
    col += inhabitants(s5, seed, species - 1.0, px, rm);
  }
  if (realmIdx > 0.5 && realmIdx < 2.5) {
    float reef = step(1.5, realmIdx);
    col += garden(s4 * vec2(mix(0.7, 1.6, reef), 1.0), seed, 1.0 - reef, px, rm) * mix(0.5, 1.7, reef);
  }

  col += biomeDetail(s4, seed, realmIdx, px, rm);
  return col;
}

vec3 world(vec2 p, vec2 cam, float s, uint wseed, float realmIdx, Realm rm) {
  float seed = seedOffset(wseed);
  float px = s / uResolution.y;
  vec3 col = scenery(p, cam, s, wseed, realmIdx, rm);

  // The bubbles, seen from outside: a thin bright lip and halo; one too small to enter gets a glow inside
  for (int i = 0; i < SLOTS; i++) {
    Bubble b = bubbleAt(wseed, i, s, uTime, uHeadOffset);
    if (b.on < 0.5) continue;
    vec2 q = (p - b.c) / b.r;
    float r = length(q);
    float haze = 1.0 - 0.45 * b.depth; // far bubbles are softer
    if (r < 1.0) {
      Realm inner = realm(childRealm(realmIdx, b.child));
      vec3 inside = mix(inner.deep, inner.shallow, smoothstep(-1.0, 1.0, q.y) * 0.8) + inner.light * 0.06;
      vec4 gl = glassFront(q, uLook, rm, cueOf(b));
      col = mix(col, inside * gl.a, 0.30) + gl.rgb * haze;
    } else if (r < 2.0) {
      col += glassOuterRim(q, px / b.r, rm, cueOf(b)) * haze;
    }
  }

  return col + frontParticles(p, cam, s, seed, rm);
}

void main() {
  // Centred, aspect-correct coords: y spans -0.5..0.5, x wider on landscape screens.
  vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution) / uResolution.y;
  vec2 screenUv = uv;
  // Water shimmer: two slow, crossing sine swells bend the view by a pixel or two, like looking through water.
  // Screen-space and the same on both sides of a bubble crossing, so it never shows a seam.
  uv += WATER_SHIMMER * vec2(
    sin(uv.y * 9.0 + uTime * 0.7) + 0.5 * sin(uv.x * 13.0 - uTime * 0.45),
    cos(uv.x * 8.0 - uTime * 0.6) + 0.5 * cos(uv.y * 11.0 + uTime * 0.5)
  );
  uv = handWarp(uv);
  uv = gestureWarp(uv, uGesture, uTime); // HOOK: keep

  // Start in the root world (the parent of where you are), then walk inward: while the pixel is inside a
  // bubble, add that bubble's glass and the particles in front of it, and step into the world inside.
  // The world the pixel finally lands in is drawn in full.
  vec2 cam = uCam.xy;
  float s = uCam.z;
  vec2 p = cam + uv * s;
  uint wseed = uint(uRoot.x); // seeds are whole numbers below 2^24: exact in float32 (never add 0.5: above 2^23 that rounds up)
  float realmIdx = uRoot.y;

  vec3 add = vec3(0.0); // light from things in front (glass reflections, particles)
  float trans = 1.0;    // how much of what lies behind still shows through
  vec3 col = vec3(0.0);
  for (int d = 0; d < 4; d++) {
    Realm rm = realm(realmIdx);
    Bubble hit = Bubble(vec2(0.0), 1.0, 0.0, 0.0, 0.0);
    for (int i = 0; i < SLOTS; i++) {
      Bubble b = bubbleAt(wseed, i, s, uTime, uHeadOffset);
      if (b.on > 0.5 && length(p - b.c) < b.r) hit = b;
    }
    if (hit.on < 0.5 || d == 3 || hit.r / s < MIN_BUBBLE) {
      col = world(p, cam, s, wseed, realmIdx, rm);
      break;
    }
    vec2 q = (p - hit.c) / hit.r;
    add += trans * frontParticles(p, cam, s, seedOffset(wseed), rm);
    // Small bubbles let the surrounding scenery show through their miniature world.
    // Become fully immersive before crossing the clear centre, preserving the seamless dive.
    float interiorOpacity = mix(0.30, 1.0, smoothstep(0.22, 0.85, hit.r / s));
    add += trans * (1.0 - interiorOpacity) * scenery(p, cam, s, wseed, realmIdx, rm);
    trans *= interiorOpacity;
    vec4 gl = glassFront(q, uLook, rm, cueOf(hit));
    add += trans * gl.rgb;
    // The world inside reads a touch brighter while the bubble is small; exactly 1 by the time it fills the view
    trans *= gl.a;
    // Into the child world's coordinates
    p = refractRim(q) * WORLD_H;
    cam = (cam - hit.c) / hit.r * WORLD_H;
    s *= WORLD_H / hit.r;
    wseed = uint(hit.child);
    realmIdx = childRealm(realmIdx, hit.child);
  }

  col = mix(BASE, add + trans * col, uFade);
  col = gestureLight(col, screenUv, uGesture, uTime); // HOOK: keep
  col += handLight(screenUv) * uFade;
  col = moodGrade(col, screenUv, uMood, uTime);       // HOOK: keep
  col *= vignette(screenUv);
  col = tonemap(col * EXPOSURE);
  fragColor = vec4(dither(col, gl_FragCoord.xy), 1.0);
}

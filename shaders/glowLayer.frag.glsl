#version 300 es
precision highp float;

// "Every light is a window": a strange ecosystem held in a web, one world per zoom octave.
// Every creature is a lens onto the world below it, and every creature watches you. Descending is endless.

#define LAYERS 6        // octaves visible at once
#define REALMS 3        // must match REALMS.length in DreamWorld.vue
#define REALM_SPAN 3.0  // octaves spent in one realm before the next takes over

uniform vec2 uResolution;           // canvas size in pixels (set by GlCanvas)
uniform float uTime;                // seconds since start (set by GlCanvas)
uniform vec2 uHeadOffset;           // @slider -0.5..0.5 default 0 "Viewer offset in screen units"
uniform float uDescent;             // @slider 0..20 default 0 "How deep we are, in octaves (log2 of zoom); endless"
uniform float uBaseScale;           // @slider 0.5..4 default 1.5 "Body count across the screen in the nearest layer"
uniform vec3 uPalette[REALMS * 4];  // cosine palette a, b, c, d per realm
uniform vec2 uLook;                 // smoothed viewer position -1..1: where the creatures' eyes turn
uniform vec4 uShape[REALMS];        // per realm: creature body, eye/highlight, web, nebula strengths
uniform vec4 uMood;                 // (joy, sadness, surprise, tension) 0..1, see chunks/mood.glsl
uniform vec4 uGesture;              // (blink, mouth, wink, spare) 0..1, see chunks/gestures.glsl
uniform float uFade;                // @slider 0..1 default 1 "Overall glow opacity"

out vec4 fragColor;

#include "noise"
#include "cells"
#include "creatures"
#include "palette"
#include "tonemap"
#include "mood"
#include "gestures"

const vec3 BASE = vec3(0.020, 0.031, 0.078);    // #050814
const vec3 HAZE_TINT = vec3(0.10, 0.16, 0.40);  // far worlds fade toward this deep blue
const float DEPTH_FALLOFF = 0.62;               // brightness kept per octave further away
const float LENS_INSIDE = 1.8;                  // the world below glows brighter seen through a body...
const float LENS_OUTSIDE = 0.45;                // ...and dimmer outside it

// One world at absolute octave k, seen at relative octave o (0 = nearest, grows with distance).
// Returns additive RGB in .rgb and the "inside a body" lens mask in .a.
vec4 world(vec2 uv, float k, float o) {
  int realm = int(mod(floor(k / REALM_SPAN), float(REALMS)));
  vec4 shape = uShape[realm];
  int pi = realm * 4;

  // Zoom: every octave closer doubles the size. Parallax: nearer octaves shift more.
  float scale = uBaseScale * exp2(o);
  vec2 p = (uv + uHeadOffset / exp2(o * 0.6)) * scale;
  float seed = k * 7.31;

  // Gentle domain warp so the web reads as grown, not drawn. The same noise doubles as nebula.
  vec2 q = vec2(fbm(p * 0.6 + seed), fbm(p * 0.6 + seed + 5.2));
  vec2 w = p + (q - 0.5) * 0.6;
  vec3 rgb = vec3(0.0);
  float inside = 0.0; // the lens mask: 1 inside any body's membrane

  // Bodies: draw the body of every neighbouring cell (not just the nearest), so a membrane wider
  // than its cell overlaps its neighbours instead of being clipped by the cell border.
  vec2 cell = floor(w);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 id = cell + vec2(x, y);
      vec3 h = hash3(id + seed * 17.13);
      if (h.y < 0.35) continue; // not every cell holds a creature

      // Same drifting point as cells(), so creatures sit at the hubs of the web
      vec2 pt = id + 0.5 + 0.36 * sin(uTime * (0.12 + 0.1 * h.z) + 6.2831 * h.xy);
      float size = mix(0.16, 0.3, h.x);
      vec2 l = (w - pt) / size; // creature space: unit = its radius
      if (dot(l, l) > 3.4) continue; // beyond its tentacle tips: skip the work

      float tilt = 0.25 * sin(uTime * 0.2 + h.z * 6.2831); // a slow sway
      l = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt)) * l;
      // Eyes follow the viewer, with a little wandering of their own
      vec2 look = clamp(uLook + 0.3 * vec2(sin(uTime * 0.31 + h.x * 6.0), sin(uTime * 0.23 + h.y * 6.0)), -1.0, 1.0);

      Creature cr; // (WebGL forbids ?: on structs)
      if (realm == 0) cr = seaDrifter(l, uTime, h, look);
      else if (realm == 1) cr = sporeLantern(l, uTime, h, look);
      else cr = coralStar(l, uTime, h, look);

      float pulse = 0.75 + 0.25 * sin(uTime * (0.35 + 0.4 * h.z) + h.x * 6.2831);
      vec3 hue = max(cosPalette(h.x * 0.7 + q.y * 0.3, uPalette[pi], uPalette[pi + 1], uPalette[pi + 2], uPalette[pi + 3]), 0.0);
      rgb += (hue * cr.body * shape.x * pulse + mix(hue, vec3(1.0), 0.6) * cr.accent * shape.y) * (1.0 - cr.pupil * 0.9);
      inside = max(inside, cr.inside);
    }
  }

  // Web: borders between cells, broken into threads by slow noise
  Cell c = cells(w, seed, uTime);
  float px = scale / uResolution.y; // one pixel, in this layer's units: keeps far threads crisp, not aliased
  float edge = c.f2 - c.f1;
  float web = exp(-pow(edge / (0.025 + px * 1.5), 2.0)) * smoothstep(0.3, 0.7, noise(w * 0.7 + seed));
  float nebula = pow(smoothstep(0.35, 0.85, q.x), 2.0);

  vec3 webHue = max(cosPalette(0.45 + q.x * 0.5, uPalette[pi], uPalette[pi + 1], uPalette[pi + 2], uPalette[pi + 3]), 0.0);
  rgb += webHue * web * shape.z * 0.55;
  rgb += webHue * nebula * shape.w * 0.12;
  return vec4(rgb, inside);
}

void main() {
  // Centred, aspect-correct coords: y spans -0.5..0.5, x wider on landscape screens.
  vec2 uv = (gl_FragCoord.xy - 0.5 * uResolution) / uResolution.y;
  vec2 screenUv = uv;
  uv = gestureWarp(uv, uGesture, uTime); // HOOK: keep

  float first = floor(uDescent);
  vec3 glow = vec3(0.0);
  float lens = 1.0; // brightness the nearer world grants to the next one through its bodies

  // Nearest to furthest. Each absolute octave k keeps its own content as it approaches, so the
  // descent has no seam: a world fades in far away, swells, passes the viewer and fades out.
  for (int i = 0; i < LAYERS; i++) {
    float k = first + float(i);
    float o = k - uDescent; // (-1, LAYERS - 1]
    float weight = smoothstep(-1.0, 0.0, o) * smoothstep(float(LAYERS) - 1.0, float(LAYERS) - 2.5, o);

    vec4 wd = world(uv, k, o);
    vec3 g = wd.rgb * weight * lens * pow(DEPTH_FALLOFF, max(o, 0.0));

    // Depth haze: further worlds lose saturation toward deep blue
    float haze = clamp(o / 4.0, 0.0, 1.0);
    g = mix(g, dot(g, vec3(0.3, 0.5, 0.2)) * HAZE_TINT * 3.0, haze * 0.6);
    glow += g;

    // Bodies of this world are windows: brighten what lies inside them, dim what lies outside
    lens = mix(1.0, mix(LENS_OUTSIDE, LENS_INSIDE, wd.a), weight);
  }

  vec3 col = BASE + glow * uFade;
  col = gestureLight(col, screenUv, uGesture, uTime); // HOOK: keep
  col = moodGrade(col, screenUv, uMood, uTime);       // HOOK: keep
  col *= vignette(screenUv);
  col = tonemap(col * 1.2);
  fragColor = vec4(dither(col, gl_FragCoord.xy), 1.0);
}

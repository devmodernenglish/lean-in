// --- gestures: how the world reacts to the viewer's face (shaped on the CPU in composables/useGestures.js)
// gesture.x  closed 0..1   eyes held shut: the world dims and recedes, holding its breath
// gesture.y  mouth  0..1   jaw open: the world breathes in; it swells and light is drawn toward the viewer
// gesture.z  wink  -1..1   a glint sweeping across from the winking eye's side; |z| = progress, sign = side
// gesture.w  bloom  0..1   progress of the ring of light that blooms when the eyes re-open after an intentional blink
// Everything is a few multiplies per pixel; the `if`s test uniforms (same answer for every pixel), so they cost
// nothing when idle. uv is centred and aspect-correct (y -0.5..0.5).

const vec3 GESTURE_TINT = vec3(0.55, 0.85, 1.0); // aqua-white: light seen through water

// Bloom: the ring races out then slows (ease-out), fades in fast and dies away slowly.
float bloomRadius(float p) { return 1.25 * (1.0 - pow(1.0 - p, 3.0)); }
float bloomStrength(float p) { return smoothstep(0.0, 0.06, p) * (1.0 - p) * (1.0 - p); }
// Wink: in and out softly, so starting and ending at 0 is invisible.
float winkEnvelope(float p) { return smoothstep(0.0, 0.15, p) * smoothstep(1.0, 0.55, p); }

mat2 gestureRot(float a) { return mat2(cos(a), -sin(a), sin(a), cos(a)); }

// Bend screen coordinates before the world is drawn. Shrinking uv = zooming in (things look bigger).
vec2 gestureWarp(vec2 uv, vec4 gesture, float time) {
  float r = length(uv);
  vec2 dir = uv / max(r, 1e-4); // unit vector pointing away from the centre

  // Eyes shut: the world draws back a little, as if it is listening
  uv *= 1.0 + 0.05 * gesture.x;

  // Mouth: inhale. Swell (zoom in up to 9%) plus faint ripples that travel INWARD:
  // sin(r*k + t*w) keeps its phase where r = (c - t*w)/k, which shrinks over time.
  float m = gesture.y;
  uv *= 1.0 - 0.09 * m;
  uv -= dir * 0.007 * m * sin(r * 22.0 + time * 3.0) * smoothstep(0.0, 0.15, r);

  // Bloom ring: a lens bulge where the ring passes. d * exp(-d^2) (a gaussian's slope) pushes pixels
  // outward just inside the ring and inward just outside it, so the world looks magnified under the ring.
  if (gesture.w > 0.0) {
    float d = r - bloomRadius(gesture.w);
    float k = d / 0.07;
    uv -= dir * 0.05 * bloomStrength(gesture.w) * k * exp(-k * k);
  }

  // Wink: a small swirl around the centre, turning toward the winking side, strongest in the middle
  if (gesture.z != 0.0) {
    float a = -sign(gesture.z) * 0.22 * winkEnvelope(abs(gesture.z)) * exp(-r * 2.5);
    uv = gestureRot(a) * uv;
  }
  return uv;
}

// Add light on the composited, linear colour (before mood grade, vignette, tonemap).
vec3 gestureLight(vec3 col, vec2 uv, vec4 gesture, float time) {
  float r = length(uv);
  float core = exp(-r * r * 7.0); // soft blob in the middle of the screen

  // Eyes shut: dim, the edges more than the centre (a natural blink only dips this ~10%)
  col *= 1.0 - gesture.x * (0.8 - 0.3 * core);

  // Mouth: light is drawn toward the viewer. The centre brightens and the edges give some of their light up,
  // with radial filaments flowing inward (the same inward-travelling sine as the warp).
  float m = gesture.y;
  if (m > 0.0) {
    col *= 1.0 + m * (0.8 * core - 0.3 * smoothstep(0.25, 0.8, r));
    float ang = atan(uv.y, uv.x);
    float rays = pow(0.5 + 0.5 * sin(ang * 13.0 + 1.5 * sin(ang * 5.0 + time * 0.3)), 6.0); // ~13 soft spokes
    float flow = 0.5 + 0.5 * sin(r * 14.0 + time * 3.0);
    float band = smoothstep(0.05, 0.3, r) * smoothstep(0.9, 0.3, r);
    col += GESTURE_TINT * m * (rays * flow * band * 0.07 + core * 0.05);
  }

  // Bloom: a wobbly ring of light expanding from the centre, and the world inside it flares then settles
  if (gesture.w > 0.0) {
    float p = gesture.w;
    float s = bloomStrength(p);
    vec2 dir = uv / max(r, 1e-4);
    float R = bloomRadius(p) + 0.035 * (noise(dir * 3.0 + time * 0.5) - 0.5); // organic, not a perfect circle
    float width = mix(0.025, 0.12, p); // the ring softens as it travels
    float d = (r - R) / width;
    col += GESTURE_TINT * exp(-d * d) * s * 0.55;
    col *= 1.0 + 0.9 * s * smoothstep(R + 0.05, 0.0, r);
  }

  // Wink: a tilted band of light sweeping from the winking side across to the other (a lighthouse wink)
  if (gesture.z != 0.0) {
    float p = abs(gesture.z);
    float u = sign(gesture.z) * uv.x + 0.35 * uv.y; // distance across the screen, measured from the winking side
    float c = mix(1.1, -1.1, smoothstep(0.0, 1.0, p));
    float k = (u - c) / 0.06;
    float glint = exp(-k * k) * winkEnvelope(p);
    col *= 1.0 + 1.6 * glint; // reveal what's there...
    col += GESTURE_TINT * glint * 0.08; // ...plus a little light of its own
  }
  return col;
}

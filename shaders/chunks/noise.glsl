// --- noise: hash, smooth value noise, fbm --------------------------------

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Value noise: random values on a grid, smoothly blended between corners. Range 0..1.
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0); // quintic fade: no grid creases
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// fbm: 5 octaves of noise, each twice as fine and half as strong. Rotating each octave hides the grid.
const mat2 FBM_ROT = mat2(0.8, 0.6, -0.6, 0.8);

float fbm(vec2 p) {
  float sum = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 5; i++) {
    sum += amp * noise(p);
    p = FBM_ROT * p * 2.02;
    amp *= 0.5;
  }
  return sum;
}

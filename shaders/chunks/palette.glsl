// --- palette: cosine gradient a + b * cos(2π(c*t + d)) --------------------

vec3 cosPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
  return a + b * cos(6.28318 * (c * t + d));
}

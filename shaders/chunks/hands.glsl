// Hand coordinates are mirrored camera coordinates, normalised to the viewport.
vec2 handPoint(vec2 p) { return (p - 0.5) * vec2(uResolution.x / uResolution.y, 1.0); }
vec2 handWarp(vec2 uv) {
  vec2 d = uv - handPoint(uPalm.xy);
  float falloff = exp(-dot(d, d) * 30.0) * uPalm.z;
  return uv + vec2(-d.y, d.x) * falloff * (0.09 + 0.18 * uPalm.w);
}
vec3 handLight(vec2 uv) {
  vec3 light = vec3(0.0);
  for (int i = 0; i < 12; i++) {
    vec4 point = uHandTrail[i];
    if (point.z < 0.001) continue;
    vec2 d = uv - handPoint(point.xy);
    float age = 1.0 - point.z;
    d += vec2(sin(age * 5.0 + point.w * 6.28), age * 0.8) * age * 0.025;
    float glow = exp(-dot(d, d) / (0.00012 + age * 0.0005));
    light += mix(vec3(0.25, 0.9, 1.0), vec3(1.0, 0.4, 0.85), point.w) * glow * point.z * 0.12;
  }
  float r = length(uv - handPoint(uPalm.xy));
  float size = 0.012 + uPalm.w * 0.035;
  light += vec3(0.5, 0.95, 1.0) * exp(-r * r / (size * size)) * uPalm.z * (0.12 + uPalm.w * 1.5);
  if (uHandBurst.z < 2.5 && uHandBurst.w > 0.0) {
    float age = uHandBurst.z;
    vec2 d = uv - handPoint(uHandBurst.xy) - vec2(0.0, age * 0.06);
    float radius = age * (0.16 + 0.15 * uHandBurst.w);
    float ring = exp(-pow((length(d) - radius) / (0.008 + age * 0.014), 2.0));
    float sparks = pow(0.5 + 0.5 * sin(atan(d.y, d.x) * 19.0 + age * 2.0), 8.0);
    light += vec3(0.6, 0.85, 1.0) * ring * (0.3 + sparks) * exp(-age * 1.6) * uHandBurst.w;
  }
  return light;
}

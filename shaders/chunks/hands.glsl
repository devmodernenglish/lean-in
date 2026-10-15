// Deform the scenery itself: inverse sampling makes liquid follow the hand.
vec2 handPoint(vec2 p) { return (p - 0.5) * vec2(uResolution.x / uResolution.y, 1.0); }
vec2 handWarp(vec2 uv) {
  vec2 centre = handPoint(uPalm.xy);
  vec2 d = uv - centre;
  float visible = uPalm.z;
  vec2 velocity = uHandMotion.xy * vec2(uResolution.x / uResolution.y, 1.0);
  float influence = exp(-dot(d, d) / 0.065) * visible;
  // Broad palm strokes entrain the water instead of carrying a separate particle.
  vec2 displacement = velocity * 0.075 * influence;
  for (int i = 0; i < 11; i += 2) {
    vec4 recent = uHandTrail[i];
    vec4 older = uHandTrail[i + 1];
    vec2 stroke = handPoint(recent.xy) - handPoint(older.xy);
    vec2 wake = uv - handPoint(recent.xy);
    float age = 1.0 - recent.z;
    float weight = exp(-dot(wake, wake) / (0.018 + age * 0.06));
    displacement += stroke * weight * recent.z * older.z * 0.4;
  }
  float grip = uHandMotion.w * visible;
  vec2 stretch = centre - handPoint(uHandAnchor);
  // Pinch anchors a patch; sideways travel stretches it, approach magnifies it toward the viewer.
  displacement += stretch * exp(-dot(d, d) / 0.10) * grip * 0.35;
  float bulge = (0.10 * uPalm.w + 0.24 * uHandMotion.z) * grip;
  displacement += d * bulge * exp(-dot(d, d) / 0.045);
  if (uHandBurst.z < 2.8 && uHandBurst.w > 0.0) {
    vec2 release = uv - handPoint(uHandBurst.xy);
    float radius = length(release);
    float age = uHandBurst.z;
    float wave = sin(radius * 38.0 - age * 9.0);
    float band = exp(-pow((radius - age * 0.21) / 0.12, 2.0));
    displacement += release / max(radius, 0.001) * wave * band * exp(-age * 1.8) * uHandBurst.w * 0.010;
  }
  // Bound the lens displacement even during a very fast sweep.
  return uv - displacement / (1.0 + length(displacement) * 5.0);
}
vec3 handLight(vec2 uv) {
  vec2 d = uv - handPoint(uPalm.xy);
  float radius = length(d);
  float grip = uHandMotion.w * uPalm.z;
  float size = 0.10 + uHandMotion.z * 0.08;
  // Soft refraction sheen across the stretched membrane, rather than an orb or sparks.
  float membrane = exp(-pow((radius - size) / 0.045, 2.0));
  float highlight = 0.5 + 0.5 * dot(d / max(radius, 0.001), normalize(vec2(-0.6, 1.0)));
  return vec3(0.35, 0.75, 0.85) * membrane * highlight * grip * (0.035 + uHandMotion.z * 0.07);
}

// World openings: flat translucent discs, with a soft edge and no spherical lighting.
// The centre stays perfectly clear for seamless entry into the world inside.
const float GLASS_CLEAR = 0.7;

vec2 refractRim(vec2 q) {
  return q; // no lens bulge: the inner world remains flat all the way to the edge
}

vec4 glassFront(vec2 q, vec2 look, Realm rm, float cue) {
  float r = length(q);
  float edge = smoothstep(GLASS_CLEAR, 1.0, r);
  // A quiet wash of the realm colour replaces glossy reflections and curved highlights.
  float line = exp(-pow((r - 0.994) / 0.012, 2.0));
  vec3 tint = mix(rm.accent, rm.light, 0.25);
  vec3 add = tint * (edge * 0.009 + line * (0.045 + cue * 0.10));
  return vec4(add, 1.0); // no dark sidewall or shaded shell
}

vec3 glassOuterRim(vec2 q, float px, Realm rm, float cue) {
  float distanceToEdge = max(length(q) - 1.0, 0.0);
  float width = max(0.005, px * 1.2);
  float line = exp(-pow(distanceToEdge / width, 2.0));
  vec3 tint = mix(rm.accent, rm.light, 0.25);
  return tint * line * (0.055 + 0.12 * cue);
}

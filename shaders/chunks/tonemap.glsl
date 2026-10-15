// --- tonemap: filmic curve, vignette, dither ------------------------------

// ACES fit (Narkowicz): rolls bright glow off softly instead of clipping to white.
vec3 tonemap(vec3 x) {
  return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

// 1 at the centre, easing darker toward the corners. uv is centred (0,0), aspect-corrected.
float vignette(vec2 uv) {
  return smoothstep(1.4, 0.3, length(uv));
}

// ±0.5/255 of noise per pixel breaks up banding in dark gradients.
vec3 dither(vec3 col, vec2 fragCoord) {
  return col + (hash(fragCoord) - 0.5) / 255.0;
}

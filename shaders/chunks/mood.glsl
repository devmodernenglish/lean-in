// --- mood: colourway from the viewer's emotion ----------------------------
// mood = (joy, sadness, surprise, tension), each 0..1, smoothed on the CPU (composables/useMood.js).
// Called by the main shader on the composited, LINEAR colour, before vignette and tonemapping.
//
// It is a colour GRADE, like an Instagram filter: it never draws anything new, it only bends the
// colours that are already there, so it works on whatever look the world has. Every step below is
// `mix(col, graded, amount)`, so at amount 0 it does nothing, and several moods simply stack.
// Cost: a handful of multiplies per pixel and one hash; no texture reads, no loops.

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722); // how bright each channel looks to the eye

vec3 moodGrade(vec3 col, vec2 uv, vec4 mood, float time) {
  // Neutral is an exact identity. `mood` is a uniform, so every pixel takes the same branch: free.
  if (dot(mood, vec4(1.0)) <= 0.0) return col;

  float joy = mood.x, sad = mood.y, sur = mood.z, ten = mood.w;
  float r = length(uv);          // 0 at the centre, ~0.8 in the corners
  col = max(col, 0.0);

  // SADNESS: the colour drains out, the light turns cool and dim, like dusk under water.
  // Desaturate = mix toward grey of the same brightness; then a blue-grey white balance and less exposure.
  float lum = dot(col, LUMA);
  col = mix(col, vec3(lum), 0.6 * sad);
  col *= mix(vec3(1.0), vec3(0.78, 0.9, 1.12), sad);
  col *= 1.0 - 0.32 * sad;

  // JOY: a rosy white balance, a little more light, and soft pink light bleeding in from above.
  // White balance alone only shifts a blue scene a little, so part of the colour is re-tinted: keep each
  // pixel's brightness (lum) but give it a lilac-pink hue (the tint's own luma is ~1, so brightness is
  // preserved). It stays soft and luminous; tension owns the hard red-magenta.
  // The bleed is a soft gradient (top of screen) that breathes slowly, scaled by the scene's own
  // brightness plus a small floor, so dark water glows rose instead of turning flat pink.
  col *= mix(vec3(1.0), vec3(1.12, 0.95, 1.08), joy);
  col = mix(col, dot(col, LUMA) * vec3(1.45, 0.8, 1.35), 0.4 * joy);
  col *= 1.0 + 0.45 * joy; // blue reads darker than its luma, so re-tinted blue needs a lift to feel brighter
  float above = smoothstep(-0.35, 0.6, uv.y) * (0.85 + 0.15 * sin(time * 0.5 + uv.x * 2.0));
  col += joy * above * vec3(1.0, 0.55, 0.95) * (0.06 + 0.6 * dot(col, LUMA));

  // TENSION: harder contrast, a red/magenta cast, the edges closing in, and a nervous flicker + grain.
  // Contrast: push each value away from a mid-grey pivot (power curve, so blacks stay black).
  const float PIVOT = 0.18;
  vec3 contrasty = PIVOT * pow(col / PIVOT, vec3(1.35));
  col = mix(col, contrasty, ten);
  col *= mix(vec3(1.0), vec3(1.14, 0.84, 0.98), ten);                // pull green out: red + magenta remain
  col = mix(col, dot(col, LUMA) * vec3(2.0, 0.62, 1.25), 0.3 * ten);  // re-tint part of it toward magenta-red
  col *= mix(1.0, smoothstep(1.05, 0.15, r), 0.55 * ten);            // tighter vignette
  float flicker = sin(time * 13.0) * sin(time * 7.3 + 1.7) * sin(time * 2.1); // irregular, never a clean strobe
  col *= 1.0 + ten * 0.035 * flicker;
  float grain = hash(gl_FragCoord.xy + fract(time * 7.0) * 517.0) - 0.5; // new noise every frame
  col *= 1.0 + ten * 0.18 * grain;

  // SURPRISE: a sudden clarity. Exposure lifts, the centre opens up, and bright things bloom.
  // "Bloom" without blurring: anything above a threshold gets extra light added on top (a soft knee),
  // so highlights flare while the darks stay clean.
  col *= 1.0 + 0.35 * sur;
  col *= 1.0 + 0.3 * sur * smoothstep(0.75, 0.0, r);
  vec3 hot = max(col - 0.25, 0.0);
  col += sur * hot * (0.9 + 0.6 * hot);
  col = mix(col, col * vec3(0.96, 1.0, 1.06), sur);                  // a crisp, slightly cool-white clarity

  return col;
}

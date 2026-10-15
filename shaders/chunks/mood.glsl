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

  // JOY: lift and saturate the world's own colour, so green stays green and yellow stays yellow.
  float joyGlow = 1.0 - pow(1.0 - joy, 1.5);
  float joyLum = dot(col, LUMA);
  col = max(mix(vec3(joyLum), col, 1.0 + 0.35 * joyGlow), 0.0);
  col *= 1.0 + 1.15 * joyGlow;
  vec3 radiant = col / max(max(col.r, max(col.g, col.b)), 0.001);
  float above = smoothstep(-0.5, 0.6, uv.y);
  float swell = 0.85 + 0.15 * sin(time * 1.3 + uv.x * 2.0);
  col += radiant * joyGlow * (0.045 + 0.12 * above) * swell;

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

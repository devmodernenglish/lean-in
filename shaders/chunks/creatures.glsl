// --- creatures: the strange ecosystem, one species per realm -------------
// Each is drawn in its own local space `l` (unit = creature radius, y up), from soft glowing lines.
// What they all share: one eye that turns to follow the viewer.

struct Creature {
  float body;   // glow in the realm's hue
  float accent; // near-white highlights: eyes, seed tips, moons
  float pupil;  // 0..1, darkens this creature where its pupil is
  float inside; // lens mask: 1 inside the creature's body (a window onto the world below)
};

// A soft glowing line: 1 on the line (d = 0), fading over width w
float glowLine(float d, float w) {
  return exp(-(d * d) / (w * w));
}

// An eye at c with radius rad. look (-1..1) moves the pupil toward the viewer.
void eye(inout Creature cr, vec2 l, vec2 c, float rad, vec2 look) {
  vec2 e = l - c;
  float d = length(e);
  cr.accent += glowLine(d - rad, rad * 0.18) * 0.9;     // bright rim
  cr.accent += smoothstep(rad, rad * 0.4, d) * 0.35;    // glowing white
  vec2 p = e - look * rad * 0.45;                       // pupil, shifted toward the viewer
  float pd = length(p);
  cr.accent += glowLine(pd - rad * 0.5, rad * 0.1) * 0.8; // iris ring
  cr.pupil = max(cr.pupil, smoothstep(rad * 0.36, rad * 0.26, pd));
}

// Sea: a lantern-drifter. Translucent bell, frilled skirt, swaying tentacles, an eye in the bell.
Creature seaDrifter(vec2 l, float t, vec3 h, vec2 look) {
  Creature cr = Creature(0.0, 0.0, 0.0, 0.0);
  vec2 b = (l - vec2(0.0, 0.05)) / vec2(0.62, 0.5);
  float e = length(b) - 1.0;                       // < 0 inside the bell ellipse
  float upper = smoothstep(-0.25, 0.05, b.y);      // keep the dome, drop the bottom of the ellipse
  cr.body += glowLine(e, 0.07) * upper;            // bell rim
  cr.body += smoothstep(0.0, -0.6, e) * upper * 0.18;

  float skirt = -0.075 + 0.035 * sin(l.x * 28.0 + t * 2.0 + h.z * 6.0);
  cr.body += glowLine(l.y - skirt, 0.03) * smoothstep(0.62, 0.45, abs(l.x)) * 0.8;

  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    float below = clamp(skirt - l.y, 0.0, 2.0); // distance down the tentacle
    float sway = 0.12 * sin(l.y * 4.5 + t * 1.3 + fi * 1.7 + h.x * 6.0) * below;
    float x0 = (fi - 1.5) * 0.22;
    cr.body += glowLine(l.x - x0 - sway, 0.035 * (1.0 - below * 0.4))
      * step(l.y, skirt) * smoothstep(1.6, 0.3, below) * 0.7;
  }

  eye(cr, l, vec2(0.0, 0.22), 0.2, look);
  cr.inside = smoothstep(0.1, -0.3, e) * upper;
  return cr;
}

// Forest: a spore-lantern. Curling stalk, a glowing pod that is its eye, a fan of seed filaments.
Creature sporeLantern(vec2 l, float t, vec3 h, vec2 look) {
  Creature cr = Creature(0.0, 0.0, 0.0, 0.0);
  float down = clamp(-l.y, 0.0, 1.6);
  float stalkX = 0.25 * sin(down * 1.8 + t * 0.4 + h.z * 6.0) * down;
  cr.body += glowLine(l.x - stalkX, 0.03) * step(l.y, -0.25) * smoothstep(1.6, 0.8, down) * 0.7;

  float r = length(l);
  cr.body += glowLine(r - 0.3, 0.04) + smoothstep(0.3, 0.0, r) * 0.25; // pod

  // Filaments in polar coords: N spokes; `arc` is the distance to the nearest spoke
  float a = atan(l.y, l.x) + 0.15 * sin(t * 0.7 + r * 4.0 + h.x * 6.0);
  float n = 11.0;
  float arc = (fract(a / 6.2831 * n + h.y) - 0.5) * 6.2831 / n * r;
  float fan = smoothstep(-0.5, 0.1, l.y / max(r, 0.001)); // fan upward, not into the stalk
  cr.body += glowLine(arc, 0.012 + r * 0.006) * smoothstep(0.32, 0.4, r) * smoothstep(0.85, 0.6, r) * fan * 0.6;
  cr.accent += glowLine(arc, 0.035) * glowLine(r - 0.82, 0.05) * fan; // glowing seed tips

  eye(cr, l, vec2(0.0), 0.17, look);
  cr.inside = smoothstep(0.32, 0.2, r);
  return cr;
}

// Cosmos: a coral-star. Breathing petal-shaped corona, a tilted orbit ring with a moon, an eye at its heart.
Creature coralStar(vec2 l, float t, vec3 h, vec2 look) {
  Creature cr = Creature(0.0, 0.0, 0.0, 0.0);
  float r = length(l);
  float a = atan(l.y, l.x);
  float breath = 1.0 + 0.08 * sin(t * 0.8 + h.z * 6.0);
  float lobes = 4.0 + floor(h.x * 4.0);
  float edge = 0.5 * breath * (1.0 + 0.22 * sin(lobes * a + t * 0.3 + h.y * 6.0));
  cr.body += glowLine(r - edge, 0.04) * 0.9;
  cr.body += smoothstep(edge, 0.0, r) * 0.3;

  float tilt = h.z * 3.0;
  vec2 ol = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * l;
  cr.body += glowLine(length(ol * vec2(1.0, 3.2)) - 0.95, 0.04) * 0.45; // flattened orbit ring
  float ma = t * (0.3 + 0.3 * h.x) + h.y * 6.0;
  vec2 moon = vec2(cos(ma), sin(ma) / 3.2) * 0.95;
  cr.accent += glowLine(length(ol - moon), 0.05);

  eye(cr, l, vec2(0.0), 0.2, look);
  cr.inside = smoothstep(edge, edge * 0.6, r);
  return cr;
}

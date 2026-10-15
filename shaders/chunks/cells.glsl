// --- cells: drifting Voronoi, the skeleton of every "thing" ----------------
// Scatter one point per grid cell; for each pixel find the nearest (f1) and second-nearest (f2) point.
// f1 small = near a body's centre. f2 - f1 small = on the border between two bodies (the web).

// 2D -> 3 random numbers in 0..1 (Dave Hoskins' hash)
vec3 hash3(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  q += dot(q, q.yxz + 33.33);
  return fract((q.xxy + q.yzz) * q.zyx);
}

struct Cell {
  float f1;   // distance to nearest point
  float f2;   // distance to second-nearest point
  vec3 rand;  // stable random numbers of the nearest point: use for size, colour, pulse phase
};

Cell cells(vec2 p, float seed, float time) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  Cell c = Cell(8.0, 8.0, vec3(0.0));
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(x, y);
      vec3 h = hash3(i + g + seed * 17.13);
      // Each point slowly orbits its cell centre, so bodies wander instead of sitting on a grid
      vec2 pt = g + 0.5 + 0.36 * sin(time * (0.12 + 0.1 * h.z) + 6.2831 * h.xy) - f;
      float d = length(pt);
      if (d < c.f1) {
        c.f2 = c.f1;
        c.f1 = d;
        c.rand = h;
      } else if (d < c.f2) {
        c.f2 = d;
      }
    }
  }
  return c;
}

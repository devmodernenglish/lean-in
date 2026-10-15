# TODO

## Next milestones (requested after MVP milestones 1–4)

### A. Less abstract: recognisable "things" (DONE)
One invented ecosystem, every creature has one eye that follows the viewer:
lantern-drifters (sea), spore-lanterns (forest), coral-stars (cosmos). See `shaders/chunks/creatures.glsl`.
Hook for B/C: creatures' eyes can blink back, squint, widen.

### B. Emotion changes the feel
- Turn on `outputFaceBlendshapes: true` in `useHeadPose` (same model, ~free). Gives 52 scores 0..1.
- Mood from blendshapes, spring-smoothed like everything else (slow: omega ~0.5, moods drift, never flip):
  - joy: `mouthSmileLeft/Right`, `cheekSquintLeft/Right`
  - sadness: `mouthFrownLeft/Right`, `browInnerUp`
  - surprise: `browOuterUpLeft/Right`, `eyeWideLeft/Right`, `jawOpen`
  - anger/tension: `browDownLeft/Right`, `mouthPressLeft/Right`
- Mood drives shader uniforms: palette warmth, pulse rate, drift speed, web tension, bloom.
- Mouse fallback: no mood (neutral), or a keyboard override for demos.

### C. Face gestures as events
- Blink (`eyeBlinkLeft/Right` > ~0.5 for both, short): a ripple / all bodies flash and dim like a heartbeat skip.
- Wink (one eye): ?
- Mouth open (`jawOpen`): the world "breathes in" (bodies swell, web brightens); hold it to pull light toward you.
- Use hysteresis (on > 0.55, off < 0.35) so gestures don't flicker.
- Keep effects spring-driven: an event sets a target, never snaps the picture.

## Stretch (from PRD)
- Depth-of-field blur by layer distance
- Slow generative drone that rises in pitch as you descend
- Palette shifts with scale (partly done via realms)

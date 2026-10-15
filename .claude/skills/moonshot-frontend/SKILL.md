---
name: moonshot-frontend
description: Project structure and styling conventions for this Nuxt project - atomic design component folders, BEM class naming, component-scoped SCSS, and where global styles live. Use whenever creating, moving, renaming, or styling any component, page, layout, composable, or stylesheet, when scaffolding the project, or when the user asks where something should go.
---

# Moonshot Frontend Conventions

## Stack
Nuxt (Vue 3, `<script setup>`, plain JS with JSDoc), SCSS via `sass`. Hackathon projects run as an SPA: `ssr: false` in `nuxt.config`. If SSR is ever enabled, WebGL, camera, audio and `window` access must live in `.client.vue` components or behind `import.meta.client`.

## Folder structure
Paths below are relative to the project root.
```
components/
  atoms/        smallest pieces, props in / events out, no app logic   (StatusDot, GlowText, IconButton)
  molecules/    atoms combined into one small job                       (HintLine, ControlSlider, PaletteSwatch)
  organisms/    self-contained sections; GL canvases live here          (DreamWorld, ReefScene, ControlPanel)
composables/    use*.js logic: useSpring, useRAF, useHeadPose, useColonyAudio
shaders/        *.glsl, plus chunks/ (noise, palette, tonemap)
utils/          pure functions (math, easing, parsers), auto-imported
layouts/        atomic "templates": page-level frames
pages/          atomic "pages": compose organisms only
assets/styles/  GLOBAL styles only (see below)
public/         static files (e.g. model files)
```
Drop `content/`, `server/`, `middleware/`, `plugins/` unless a task needs them.

### Atomic rules
- Atoms never import other components. Molecules import atoms only. Organisms import atoms and molecules. Pages and layouts import organisms (and below).
- State and side effects live in composables and organisms; atoms and molecules stay presentational.
- Promote or demote by use: if an organism has no reuse and no state, it may be a molecule.

### Nuxt component config (flat names, no folder prefix)
`nuxt.config.js` already sets SPA mode, flat component names, the global stylesheet, and injects `tokens`, `mixins` and `functions` into every component's SCSS:
```js
components: [{ path: '~/components', pathPrefix: false }],
css: ['~/assets/styles/main.scss'],
vite: { css: { preprocessorOptions: { scss: { additionalData: '@use "~/assets/styles/tokens.scss" as *; ...' } } } }
```

Component file names are PascalCase and globally unique (`GlowText.vue`), regardless of folder. Use as `<GlowText />`.

## BEM
- Block = component name in kebab-case: `GlowText.vue` -> `.glow-text`.
- Element: `.glow-text__label`. Modifier: `.glow-text--dim`, `.glow-text__label--large`.
- One block per component, the root element carries the block class. Never nest elements (`__a__b` is wrong; flatten to `__b`).
- Child components get their own block; style them from the parent only via a modifier prop or a mix: `<StatusDot class="control-panel__dot" />`.
- State classes are modifiers (`--active`, `--hidden`), not `is-*`.
- No tag or id selectors in component styles. Utility classes are not used.

```vue
<template>
  <p class="glow-text" :class="{ 'glow-text--dim': dim }">
    <span class="glow-text__label"><slot /></span>
  </p>
</template>

<script setup>
defineProps({ dim: { type: Boolean, default: false } })
</script>

<style lang="scss" scoped>
.glow-text {
  color: var(--color-text);
  &--dim { opacity: 0.5; }
  &__label { @include fade-in(900ms); letter-spacing: 0.12em; }
}
</style>
```

## Styles
- **Component styles are inline** in the SFC: `<style lang="scss" scoped>`, nested BEM with `&__` and `&--`.
- **Global only** in `assets/styles/`:
  - `reset.scss` (reset/normalise), `main.scss` (imports reset, sets `:root` tokens, body base)
  - `tokens.scss`: SCSS variables ONLY (colours, spacing, easing, durations). It is injected into every component, so it must emit no CSS. `main.scss` turns the tokens into `:root` CSS custom properties and holds global `@keyframes` (e.g. `fade-in`).
  - `mixins.scss` (e.g. `fade-in`, `glass`, `visually-hidden`), `functions.scss` (e.g. `rem()`, `space()`)
- Use CSS custom properties for anything the shaders or JS also need (palette, timing). Use SCSS variables for build-time values.
- No global component styles, no `!important`, no `:deep()` unless wrapping a third-party element.
- Motion in CSS uses the shared easing tokens; JS-driven motion goes through `useSpring`.

## Naming cheat-sheet
| Thing | Convention | Example |
|---|---|---|
| Component | PascalCase, unique | `ControlSlider.vue` |
| Composable | `useX.js` | `useHeadPose.js` |
| Shader | `name.frag.glsl` / `name.vert.glsl` | `glowLayer.frag.glsl` |
| BEM block | kebab-case of component | `.control-slider` |
| Util | camelCase function file | `easing.js` |

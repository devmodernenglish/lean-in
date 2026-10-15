<template>
  <p class="glow-text"><slot /></p>
</template>

<style lang="scss" scoped>
.glow-text {
  margin: 0;
  font-size: rem(17);
  letter-spacing: 0.14em;
  color: var(--color-text);
  // Soft light halo, plus a dark one underneath so it stays readable over bright glow
  text-shadow:
    0 0 rem(14) rgba($color-text, 0.45),
    0 0 rem(24) rgba($color-base, 0.9);
}
</style>

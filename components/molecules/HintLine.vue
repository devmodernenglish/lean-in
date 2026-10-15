<template>
  <div class="hint-line" aria-live="polite">
    <Transition
      mode="out-in"
      enter-active-class="hint-line__text--animating"
      leave-active-class="hint-line__text--animating"
      enter-from-class="hint-line__text--hidden"
      leave-to-class="hint-line__text--hidden"
    >
      <GlowText v-if="text" :key="text" class="hint-line__text">{{ text }}</GlowText>
    </Transition>
  </div>
</template>

<script setup>
defineProps({
  /** Empty string fades the line out */
  text: { type: String, default: '' },
})
</script>

<style lang="scss" scoped>
.hint-line {
  min-height: rem(28);
  text-align: center;

  &__text--animating {
    transition:
      opacity 900ms $ease-in-out,
      filter 900ms $ease-in-out;
  }
  &__text--hidden {
    opacity: 0;
    filter: blur(rem(6));
  }
}
</style>

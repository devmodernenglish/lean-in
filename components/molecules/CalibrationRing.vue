<template>
  <svg class="calibration-ring" :class="{ 'calibration-ring--hidden': !visible }" viewBox="0 0 100 100" aria-hidden="true">
    <circle class="calibration-ring__track" cx="50" cy="50" :r="R" />
    <circle
      class="calibration-ring__progress"
      cx="50"
      cy="50"
      :r="R"
      :stroke-dasharray="CIRCUMFERENCE"
      :stroke-dashoffset="CIRCUMFERENCE * (1 - progress)"
    />
  </svg>
</template>

<script setup>
defineProps({
  /** 0..1 */
  progress: { type: Number, default: 0 },
  visible: { type: Boolean, default: false },
})

const R = 44
const CIRCUMFERENCE = 2 * Math.PI * R
</script>

<style lang="scss" scoped>
.calibration-ring {
  width: rem(120);
  height: rem(120);
  transform: rotate(-90deg); // start the arc at 12 o'clock
  transition:
    opacity 1000ms $ease-in-out,
    transform 1000ms $ease-out;

  &--hidden {
    opacity: 0;
    transform: rotate(-90deg) scale(1.15);
  }

  &__track,
  &__progress {
    fill: none;
    stroke-width: 1.2;
  }
  &__track {
    stroke: rgba($color-text, 0.12);
  }
  &__progress {
    stroke: #9fefff;
    stroke-linecap: round;
    filter: drop-shadow(0 0 3px rgba(#7fe7ff, 0.9));
    transition: stroke-dashoffset 120ms linear; // smooths the ~30 Hz detection updates
  }
}
</style>

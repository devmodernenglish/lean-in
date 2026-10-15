<template>
  <span class="status-dot" :class="{ 'status-dot--live': live }" :title="label" role="status" :aria-label="label" />
</template>

<script setup>
defineProps({
  /** true = camera tracking, false = mouse fallback / waiting */
  live: { type: Boolean, default: false },
  label: { type: String, default: '' },
})
</script>

<style lang="scss" scoped>
.status-dot {
  display: block;
  width: rem(7);
  height: rem(7);
  border-radius: 50%;
  background: rgba($color-text, 0.25);
  transition:
    background $dur-ui $ease-in-out,
    box-shadow $dur-ui $ease-in-out;

  &--live {
    background: #7fe7ff;
    box-shadow: 0 0 rem(10) rgba(#7fe7ff, 0.8);
  }
}
</style>

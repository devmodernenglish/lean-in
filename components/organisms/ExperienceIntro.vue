<template>
  <section class="intro" aria-labelledby="intro-title">
    <div class="intro__card">
      <div class="intro__orb" aria-hidden="true"><span></span><i></i></div>
      <h1 id="intro-title">Lean in.</h1>
      <p class="intro__description">Lean closer. Smile. Express yourself.<br>Raise a hand and stir the light.</p>
      <div class="intro__action" aria-live="polite" aria-atomic="true">
        <template v-if="status === 'idle' || status === 'unavailable'">
          <p v-if="status === 'unavailable'" class="intro__message">Camera unavailable. Allow access in your browser or use your mouse.</p>
          <button class="intro__primary" type="button" @click="$emit('enable')">{{ status === 'unavailable' ? 'Try camera again' : 'Enable camera' }} <span aria-hidden="true">↗</span></button>
        </template>
        <template v-else-if="status === 'loading'">
          <p class="intro__message"><span class="intro__pulse"></span> Connecting to your camera…</p>
          <p class="intro__small">Choose “Allow” when your browser asks.</p>
        </template>
        <template v-else-if="status === 'calibrating'">
          <p class="intro__message">{{ progress > 0 ? 'Hold still for two seconds.' : 'Sit back and face your camera.' }}</p>
          <div class="intro__progress" role="progressbar" aria-label="Finding your starting position" :aria-valuenow="Math.round(progress * 100)" aria-valuemin="0" aria-valuemax="100"><span :style="{ width: `${progress * 100}%` }"></span></div>
          <p class="intro__small">Relax your face. We’re finding your starting point.</p>
        </template>
        <template v-else-if="status === 'lost'">
          <p class="intro__message">Move back into the camera’s view.</p>
          <p class="intro__small">We’ll pick up where you left off.</p>
        </template>
        <template v-else>
          <p class="intro__message">Ready. Lean closer and see what happens.</p>
          <button class="intro__primary" type="button" @click="$emit('enter')">Let’s go <span aria-hidden="true">↗</span></button>
        </template>
      </div>
      <p class="intro__small">Pinch to gather light; open your hand to release it.<br>With a mouse: move to look around; scroll to dive.<br>Smile and watch the creatures shimmer back.</p>
      <p class="intro__privacy">Camera stays private. Nothing recorded or uploaded.</p>
      <button class="intro__secondary" type="button" @click="$emit('enter')">{{ status === 'tracking' ? 'Return to exploring' : 'Use mouse instead' }}</button>
    </div>
  </section>
</template>

<script setup>
defineProps({ status: { type: String, required: true }, progress: { type: Number, default: 0 } })
defineEmits(['enable', 'enter'])
</script>

<style lang="scss" scoped>
.intro {
  position: absolute; inset: 0; z-index: 5; overflow-y: auto;
  display: flex; padding: 36px 20px; background: radial-gradient(ellipse at 50% 30%, #101c3266, #030812c9);
  backdrop-filter: blur(6px);
  &__card { width: 100%; max-width: 420px; margin: auto; text-align: center; }
  &__orb { position: relative; width: 70px; height: 70px; margin: 0 auto 32px; border: 1px solid #ccf7ff55; border-radius: 50%; background: radial-gradient(circle at 28% 22%, #cef6ff55, transparent 45%), radial-gradient(circle at 70% 85%, #81b7c944, #11203422 65%); box-shadow: inset -5px -7px 16px #afc9ff12, 0 0 55px #8ccde51c; span { position: absolute; inset: 8px -10px; border: 1px solid #c2e1f024; border-radius: 50%; transform: rotate(-35deg); } i { position: absolute; width: 5px; height: 5px; right: -2px; top: 12px; border-radius: 50%; background: #c3edf1; box-shadow: 0 0 12px #c3edf1; } }
  h1 { font-family: Georgia, serif; font-size: clamp(68px, 13vw, 104px); font-weight: 400; line-height: 1.1; letter-spacing: -.035em; color: #eef6fa; margin: 0; em { font-weight: 400; color: #bbd6e2; } }
  &__description { font-size: 13px; line-height: 1.8; color: #a8bacb; letter-spacing: .015em; margin: 24px 0 34px; }
  button { font-family: inherit; cursor: pointer; &:focus-visible { outline: 2px solid #cef5ff; outline-offset: 5px; } }
  &__primary { width: 100%; padding: 17px 24px; border: 1px solid #e1f7f4; border-radius: 50px; color: #142e3a; background: #d1e9e8; font-size: 13px; font-weight: 500; letter-spacing: .03em; display: flex; justify-content: space-between; transition: background .2s, box-shadow .2s; &:hover { background: #e4f6f3; box-shadow: 0 0 30px #c1e8e520; } }
  &__message { font-size: 13px; line-height: 1.7; color: #d1e6ec; margin: 0 0 14px; }
  &__small, &__privacy { font-size: 10px; line-height: 1.7; letter-spacing: .015em; color: #8ea6b8; }
  &__privacy { margin: 14px 0 16px; }
  &__secondary { border: 0; background: transparent; color: #bed0db; font-size: 12px; padding: 8px 14px; text-decoration: underline; text-decoration-color: #bed0db40; text-underline-offset: 5px; &:hover { color: #fff; } }
  &__progress { height: 3px; background: #c1e8e51a; border-radius: 5px; overflow: hidden; margin: 16px 0; span { display: block; height: 100%; background: #b9dfdf; transition: width .2s; } }
  &__pulse { display: inline-block; width: 6px; height: 6px; border-radius: 50%; background: #b9dfdf; margin-right: 8px; }
  @media (prefers-reduced-motion: reduce) { *, *::before, *::after { transition: none !important; } }
}
</style>

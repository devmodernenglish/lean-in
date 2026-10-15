export default defineNuxtConfig({
  ssr: false,
  devtools: { enabled: false },
  // Flat component names: components/atoms/GlowText.vue is used as <GlowText />
  components: [{ path: '~/components', pathPrefix: false }],
  css: ['~/assets/styles/main.scss'],
  // Agent worktrees live in .claude/worktrees with their own node_modules: never scan or watch them
  ignore: ['.claude/**'],
  vite: {
    server: { watch: { ignored: ['**/.claude/**'] } },
    css: {
      preprocessorOptions: {
        scss: {
          // Injected into every component's <style lang="scss">; tokens.scss must emit no CSS
          additionalData: '@use "~/assets/styles/tokens.scss" as *; @use "~/assets/styles/mixins.scss" as *; @use "~/assets/styles/functions.scss" as *;'
        }
      }
    }
  }
})

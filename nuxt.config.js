export default defineNuxtConfig({
  ssr: false,
  devtools: { enabled: false },
  // Static build for Cloudflare Pages, same output locally and in CI: `npm run generate` -> dist/
  // (adds _headers cache rules for /_nuxt and an SPA-safe _redirects). See DEPLOY.md.
  nitro: { preset: 'cloudflare-pages-static' },
  // Flat component names: components/atoms/GlowText.vue is used as <GlowText />
  components: [{ path: '~/components', pathPrefix: false }],
  css: ['~/assets/styles/main.scss'],
  vite: {
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

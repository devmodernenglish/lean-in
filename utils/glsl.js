// Tiny `#include "name"` resolver for shaders/chunks/*.glsl (one level, no nesting).

const chunks = import.meta.glob('../shaders/chunks/*.glsl', { query: '?raw', import: 'default', eager: true })

const byName = Object.fromEntries(
  Object.entries(chunks).map(([path, src]) => [path.split('/').pop().replace('.glsl', ''), src])
)

export function resolveGlsl(src) {
  return src.replace(/^#include\s+"(\w+)"\s*$/gm, (_, name) => {
    if (!(name in byName)) throw new Error(`Unknown GLSL chunk: ${name}`)
    return byName[name]
  })
}

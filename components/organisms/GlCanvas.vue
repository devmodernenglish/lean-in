<template>
  <canvas ref="canvas" class="gl-canvas" />
</template>

<script setup>
import vertexSrc from '~/shaders/fullscreen.vert.glsl?raw'

const props = defineProps({
  /** Fragment shader source; `#include "chunk"` lines are resolved */
  fragment: { type: String, required: true },
  /** Plain object the parent mutates in @frame: numbers or flat arrays / Float32Arrays */
  uniforms: { type: Object, default: () => ({}) },
  /** Cap on device pixel ratio; lower renders fewer pixels for heavy shaders */
  maxDpr: { type: Number, default: 2 },
})
const emit = defineEmits(['frame'])

const canvas = ref(null)

function compile(gl, type, src) {
  const shader = gl.createShader(type)
  gl.shaderSource(shader, src)
  gl.compileShader(shader)
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(shader)
    console.error(log, '\n', src.split('\n').map((l, i) => `${i + 1}: ${l}`).join('\n'))
    throw new Error('Shader compile failed')
  }
  return shader
}

function createProgram(gl, vs, fs) {
  const program = gl.createProgram()
  gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, vs))
  gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fs))
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program))
  return program
}

// Map each active uniform name ("uPalette[0]" -> "uPalette") to a setter taking a number or array
function uniformSetters(gl, program) {
  const setters = {}
  const count = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS)
  for (let i = 0; i < count; i++) {
    const { name, type } = gl.getActiveUniform(program, i)
    const loc = gl.getUniformLocation(program, name)
    const set = {
      [gl.FLOAT]: (v) => (typeof v === 'number' ? gl.uniform1f(loc, v) : gl.uniform1fv(loc, v)),
      [gl.FLOAT_VEC2]: (v) => gl.uniform2fv(loc, v),
      [gl.FLOAT_VEC3]: (v) => gl.uniform3fv(loc, v),
      [gl.FLOAT_VEC4]: (v) => gl.uniform4fv(loc, v),
    }[type]
    if (set) setters[name.replace('[0]', '')] = set
  }
  return setters
}

onMounted(() => {
  const el = canvas.value
  const gl = el.getContext('webgl2', { antialias: false, alpha: false, powerPreference: 'high-performance' })
  if (!gl) {
    console.error('WebGL2 not available')
    return
  }

  const program = createProgram(gl, vertexSrc, resolveGlsl(props.fragment))
  const setters = uniformSetters(gl, program)
  gl.useProgram(program)
  gl.bindVertexArray(gl.createVertexArray())

  const resolution = new Float32Array(2)
  const resize = () => {
    const dpr = Math.min(window.devicePixelRatio || 1, props.maxDpr)
    el.width = Math.round(el.clientWidth * dpr)
    el.height = Math.round(el.clientHeight * dpr)
    resolution.set([el.width, el.height])
    gl.viewport(0, 0, el.width, el.height)
  }
  const observer = new ResizeObserver(resize)
  observer.observe(el)
  resize()

  const stop = useRAF((dt, time) => {
    emit('frame', { dt, time }) // parent writes uniforms synchronously here
    setters.uTime?.(time)
    setters.uResolution?.(resolution)
    for (const name in props.uniforms) setters[name]?.(props.uniforms[name])
    gl.drawArrays(gl.TRIANGLES, 0, 3)
  })

  onBeforeUnmount(() => {
    stop()
    observer.disconnect()
    gl.deleteProgram(program)
  })
})
</script>

<style lang="scss" scoped>
.gl-canvas {
  width: 100%;
  height: 100%;
}
</style>

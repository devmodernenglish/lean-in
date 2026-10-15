import test from 'node:test'
import assert from 'node:assert/strict'
import { createHandSmoother } from '../utils/handSmoothing.js'
const hand = (pinching = false, x = .5) => ({x,y:.5,size:.1,pinching})
test('brief pinch and release glitches do not toggle grip', () => {
  const s = createHandSmoother()
  s.step(hand(),0)
  assert.equal(s.step(hand(true),.04).pinching,false)
  assert.equal(s.step(hand(),.08).pinching,false)
  s.step(hand(true),.12)
  assert.equal(s.step(hand(true),.28).pinching,true)
  assert.equal(s.step(hand(),.32).pinching,true)
  assert.equal(s.step(hand(true),.36).pinching,true)
  s.step(hand(),.40)
  assert.equal(s.step(hand(),.62).pinching,false)
})
test('stationary landmark jitter is attenuated', () => {
  const s = createHandSmoother()
  s.step(hand(),0)
  let max = 0
  for(let i=1;i<40;i++) {
    const out=s.step(hand(false,.5+(i%2 ? .01 : -.01)),i*.04)
    max=Math.max(max,Math.abs(out.x-.5))
  }
  assert.ok(max < .004)
})
test('loss of tracking cancels grip and stale filter history', () => {
  const s = createHandSmoother()
  s.step(hand(true),0);s.step(hand(true),.2)
  assert.equal(s.step(hand(true,.8),1).pinching,false)
  s.reset()
  assert.equal(s.step(hand(),2).x,.5)
})

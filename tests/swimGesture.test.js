import test from 'node:test'
import assert from 'node:assert/strict'
import { createSwimDetector } from '../utils/swimGesture.js'
const pair = (spread=.2,size=.1,y=.6) => [{x:.5-spread/2,y,size},{x:.5+spread/2,y,size}]
function sequence(d, stages, start=0) {
  let fired=0,time=start
  for(const [hands,frames=8] of stages) for(let i=0;i<frames;i++) {
    if(d.step(hands,time)) fired++
    time+=.05
  }
  return {fired,time}
}
const stroke = [[pair()],[pair(.2,.14)],[pair(.55,.1)]]
test('full together, forward, apart-and-back sequence fires exactly once', () => {
  const d=createSwimDetector()
  const result=sequence(d,stroke)
  assert.equal(result.fired,1)
  assert.equal(sequence(d,stroke,result.time).fired,0)
})
test('outward or downward movement alone never triggers', () => {
  for(const stages of [ [[pair()],[pair(.6)]], [[pair()],[pair(.2,.1,.3)]], [[pair(.5)],[pair(.8)]] ]) {
    assert.equal(sequence(createSwimDetector(),stages).fired,0)
  }
})
test('must withdraw after pushing; spreading alone is insufficient', () => {
  assert.equal(sequence(createSwimDetector(),[[pair()],[pair(.2,.14)],[pair(.55,.14)]]).fired,0)
})
test('brief overlapping-hand dropout and result order swaps are tolerated', () => {
  const stages=[[pair()],[[],3],[pair(.2,.14).reverse()],[pair(.55,.1).reverse()]]
  assert.equal(sequence(createSwimDetector(),stages).fired,1)
})
test('extended tracking loss cancels a partial stroke', () => {
  assert.equal(sequence(createSwimDetector(),[[pair()],[pair(.2,.14)],[[],22],[pair(.55,.1)]]).fired,0)
})
test('one hand moving forward cannot arm the stroke', () => {
  const asymmetric=pair();asymmetric[0].size=.16
  assert.equal(sequence(createSwimDetector(),[[pair()],[asymmetric],[pair(.55,.1)]]).fired,0)
})
test('tiny depth jitter does not count as a forward push', () => {
  assert.equal(sequence(createSwimDetector(),[[pair()],[pair(.2,.104)],[pair(.55,.098)]]).fired,0)
})
test('new full strokes work after cooldown', () => {
  const d=createSwimDetector()
  assert.equal(sequence(d,stroke).fired,1)
  assert.equal(sequence(d,stroke,5).fired,1)
})

test('a continuous stroke needs no pause with hands together', () => {
  const d=createSwimDetector()
  assert.equal(sequence(d,[[pair(),1],[pair(.2,.14),5],[pair(.55,.1),10]]).fired,1)
})
test('a half-second hand occlusion retains forward-push evidence', () => {
  const d=createSwimDetector()
  assert.equal(sequence(d,[[pair()],[pair(.2,.14)],[[],10],[pair(.55,.1),10]]).fired,1)
})

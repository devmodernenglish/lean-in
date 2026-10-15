import test from 'node:test'
import assert from 'node:assert/strict'
import { readHand } from '../utils/handGesture.js'
const palm = () => Array.from({length:21}, (_,i) => ({x:.5+(i%5)*.015,y:.5+Math.floor(i/5)*.025,z:0}))
test('palm rotation does not masquerade as a depth change', () => {
  const points = palm(), aspect=4/3
  const original = readHand(points,false,aspect).swimSize
  const angle=.9
  const turned=points.map(p => ({...p,x:.5+(p.x-.5)*Math.cos(angle),z:(p.x-.5)*Math.sin(angle)}))
  assert.ok(Math.abs(readHand(turned,false,aspect).swimSize-original)<1e-8)
})
test('true camera approach increases palm size', () => {
  const points=palm()
  const near=points.map(p => ({x:.5+(p.x-.5)*1.3,y:.5+(p.y-.5)*1.3,z:p.z*1.3}))
  assert.ok(Math.abs(readHand(near).swimSize/readHand(points).swimSize-1.3)<1e-8)
})

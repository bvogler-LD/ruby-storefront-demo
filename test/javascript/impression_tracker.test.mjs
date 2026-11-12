// Unit tests for the visibility + de-duplication rule.
// Run with: node --test test/javascript
import { test } from "node:test"
import assert from "node:assert/strict"
import { ImpressionTracker } from "../../app/javascript/impression_tracker.js"

// Minimal fakes for timers and IntersectionObserver.
function harness(options = {}) {
  let now = 0
  let nextId = 1
  const timers = new Map()
  const sent = []
  const observed = new Set()
  let callback

  const tracker = new ImpressionTracker({
    ratio: 0.5,
    dwellMs: 1000,
    flushDelayMs: 400,
    send: (ids) => sent.push(ids),
    setTimer: (fn, ms) => { const id = nextId++; timers.set(id, { at: now + ms, fn }); return id },
    clearTimer: (id) => timers.delete(id),
    createObserver: (cb, config) => {
      callback = cb
      assert.deepEqual(config.threshold, [0.5])
      return { observe: (el) => observed.add(el), unobserve: (el) => observed.delete(el) }
    },
    ...options
  })

  // Moves the fake clock forward, firing timers in order at their due time
  // (including timers scheduled by other timers).
  const advance = (ms) => {
    const target = now + ms
    for (;;) {
      const due = [...timers].filter(([, timer]) => timer.at <= target).sort((a, b) => a[1].at - b[1].at)[0]
      if (!due) break
      now = due[1].at
      timers.delete(due[0])
      due[1].fn()
    }
    now = target
  }
  const card = (offerId, seen = false) => ({ dataset: seen ? { offerId, seen: "" } : { offerId } })
  const show = (el, ratio = 1) => callback([{ target: el, isIntersecting: ratio > 0, intersectionRatio: ratio }])
  const hide = (el) => show(el, 0)

  return { tracker, advance, card, show, hide, sent, observed }
}

test("a card counts after being at least 50% visible for one second", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a)
  h.show(a, 0.6)
  h.advance(999)
  assert.deepEqual(h.sent, [])
  h.advance(1)   // dwell reached
  h.advance(400) // batch flush
  assert.deepEqual(h.sent, [["1"]])
})

test("a card below the visibility threshold never counts", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a)
  h.show(a, 0.49)
  h.advance(5000)
  assert.deepEqual(h.sent, [])
})

test("scrolling past quickly does not count, and the dwell restarts from zero", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a)
  h.show(a); h.advance(600); h.hide(a)
  h.show(a); h.advance(600)
  assert.deepEqual(h.sent, [], "two partial views must not add up")
  h.advance(400); h.advance(400)
  assert.deepEqual(h.sent, [["1"]])
})

test("scrolling away and back does not report an offer twice", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a)
  h.show(a); h.advance(1400)
  h.hide(a); h.show(a); h.advance(5000)
  assert.deepEqual(h.sent, [["1"]])
  assert.equal(h.observed.has(a), false, "reported cards stop being observed")
})

test("re-rendered or re-loaded copies of the same offer are ignored", () => {
  const h = harness()
  const first = h.card("7")
  assert.equal(h.tracker.observe(first), true)
  assert.equal(h.tracker.observe(h.card("7")), false, "same offer already observed")
  h.show(first); h.advance(1400)

  const copy = h.card("7")
  assert.equal(h.tracker.observe(copy), false, "same offer already reported")
  h.advance(5000)
  assert.deepEqual(h.sent, [["7"]])
})

test("cards the server marked as already seen are never observed", () => {
  const h = harness()
  const seen = h.card("3", true)
  assert.equal(h.tracker.observe(seen), false)
  assert.equal(h.observed.size, 0)
})

test("cards that qualify together are sent in one batch", () => {
  const h = harness()
  const cards = ["1", "2", "3"].map((id) => h.card(id))
  cards.forEach((c) => { h.tracker.observe(c); h.show(c) })
  h.advance(1400)
  assert.deepEqual(h.sent, [["1", "2", "3"]])
})

test("time in a hidden tab does not count; a fresh dwell starts when visible again", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a)
  h.show(a); h.advance(500)
  h.tracker.pause(); h.advance(10000)
  assert.deepEqual(h.sent, [])
  h.tracker.resume(); h.advance(999)
  assert.deepEqual(h.sent, [])
  h.advance(1); h.advance(400)
  assert.deepEqual(h.sent, [["1"]])
})

test("flush sends queued impressions immediately and only once", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a)
  h.show(a); h.advance(1000)
  h.tracker.flush()
  h.advance(1000)
  assert.deepEqual(h.sent, [["1"]])
})

test("the same rule applies to cards added later (infinite scroll batches)", () => {
  const h = harness()
  const a = h.card("1")
  h.tracker.observe(a); h.show(a); h.advance(1400)
  const later = h.card("25")
  h.tracker.observe(later); h.show(later, 0.5); h.advance(1400)
  assert.deepEqual(h.sent, [["1"], ["25"]])
})

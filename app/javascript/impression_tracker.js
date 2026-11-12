// Decides when an offer card counts as "seen" and reports it once.
//
// Rule (same for pagination and infinite scroll):
//   a card is an impression when at least `ratio` of it has been inside the
//   viewport continuously for `dwellMs`, while the tab is visible. Each offer
//   is reported at most once per page lifetime; cards the server marks as
//   already seen (data-seen) are never observed, and the server de-duplicates
//   again per shopper session.
//
// Everything browser-specific is injected so the rule can be unit-tested
// without a DOM (see test/javascript/impression_tracker.test.mjs).
export class ImpressionTracker {
  constructor({ ratio = 0.5, dwellMs = 1000, flushDelayMs = 400, send, createObserver,
                setTimer = (fn, ms) => setTimeout(fn, ms), clearTimer = (id) => clearTimeout(id) }) {
    this.ratio = ratio
    this.dwellMs = dwellMs
    this.flushDelayMs = flushDelayMs
    this.send = send
    this.setTimer = setTimer
    this.clearTimer = clearTimer

    this.reported = new Set()   // offer ids already reported (or known seen)
    this.elements = new Map()   // offer id -> element being observed
    this.inView = new Set()     // offer ids currently meeting the ratio
    this.dwellTimers = new Map()
    this.queue = []
    this.flushTimer = null
    this.paused = false

    this.observer = createObserver((entries) => this.handleEntries(entries), { threshold: [this.ratio] })
  }

  // Start watching a card. Safe to call repeatedly for the same offer.
  observe(element) {
    const id = element.dataset.offerId
    if (!id) return false
    if ("seen" in element.dataset) { this.reported.add(id); return false }
    if (this.reported.has(id) || this.elements.has(id)) return false

    this.elements.set(id, element)
    this.observer.observe(element)
    return true
  }

  handleEntries(entries) {
    for (const entry of entries) {
      const id = entry.target.dataset.offerId
      if (!id || this.reported.has(id)) continue

      if (entry.isIntersecting && entry.intersectionRatio >= this.ratio) {
        this.inView.add(id)
        if (!this.paused) this.startDwell(id)
      } else {
        this.inView.delete(id)
        this.cancelDwell(id)
      }
    }
  }

  // Tab hidden: nothing is being seen, so dwell timers stop.
  pause() {
    this.paused = true
    for (const id of [...this.dwellTimers.keys()]) this.cancelDwell(id)
  }

  // Tab visible again: cards still in view start a fresh dwell.
  resume() {
    this.paused = false
    for (const id of this.inView) this.startDwell(id)
  }

  startDwell(id) {
    if (this.dwellTimers.has(id)) return
    this.dwellTimers.set(id, this.setTimer(() => this.qualify(id), this.dwellMs))
  }

  cancelDwell(id) {
    if (!this.dwellTimers.has(id)) return
    this.clearTimer(this.dwellTimers.get(id))
    this.dwellTimers.delete(id)
  }

  qualify(id) {
    this.dwellTimers.delete(id)
    if (this.reported.has(id)) return

    this.reported.add(id)
    this.inView.delete(id)
    const element = this.elements.get(id)
    if (element) { this.observer.unobserve(element); this.elements.delete(id) }

    this.queue.push(id)
    if (this.flushTimer === null) {
      this.flushTimer = this.setTimer(() => this.flush(), this.flushDelayMs)
    }
  }

  // Send everything queued in one request.
  flush() {
    if (this.flushTimer !== null) { this.clearTimer(this.flushTimer); this.flushTimer = null }
    if (this.queue.length === 0) return null

    const ids = this.queue
    this.queue = []
    return this.send(ids)
  }
}

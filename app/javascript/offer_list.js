// Wires up the offer list: impression tracking for both experiences, plus
// batch loading when the server rendered the infinite-scroll experience.
// The browser never chooses the experience, the event names, or the identity.
import { ImpressionTracker } from "impression_tracker"
import { InfiniteScroll } from "infinite_scroll"

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}

function start() {
  const list = document.querySelector("[data-offer-list]")
  if (!list || !("IntersectionObserver" in window)) return

  const createObserver = (callback, options) => new IntersectionObserver(callback, options)
  const devCount = document.querySelector("[data-dev-impressions]")
  const devEnd = document.querySelector("[data-dev-end]")

  const send = async (offerIds) => {
    try {
      const response = await fetch(list.dataset.impressionsUrl, {
        method: "POST",
        credentials: "same-origin",
        keepalive: true, // lets the request finish if the page is being left
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": csrfToken() },
        body: JSON.stringify({ offer_ids: offerIds.map(Number) })
      })
      if (!response.ok) return
      const result = await response.json()
      if (devCount) devCount.textContent = result.session_total
      if (devEnd && result.end_reached) devEnd.textContent = "yes"
    } catch (error) {
      // Measurement must never break shopping; drop the batch.
    }
  }

  const tracker = new ImpressionTracker({
    ratio: Number(list.dataset.impressionRatio) || 0.5,
    dwellMs: Number(list.dataset.impressionDwellMs) || 1000,
    send,
    createObserver
  })
  const observeCards = (cards) => cards.forEach((card) => tracker.observe(card))
  observeCards([...list.querySelectorAll("[data-offer-card]")])

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) { tracker.pause(); tracker.flush() } else { tracker.resume() }
  })
  window.addEventListener("pagehide", () => tracker.flush())
  // Clicking a card navigates away: send what has been seen first.
  list.addEventListener("submit", () => tracker.flush())

  if (list.dataset.experience === "infinite_scroll") {
    const fetchBatch = async (after) => {
      const url = new URL(list.dataset.batchUrl, window.location.origin)
      url.searchParams.set("after", after)
      const response = await fetch(url, { credentials: "same-origin", headers: { "Accept": "application/json" } })
      if (!response.ok) throw new Error(`Batch request failed: ${response.status}`)
      return response.json()
    }

    new InfiniteScroll({
      list,
      statusElement: document.querySelector("[data-list-status]"),
      sentinel: document.querySelector("[data-scroll-sentinel]"),
      fetchBatch,
      onCardsAdded: observeCards,
      createObserver
    }).start()
  }
}

if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start)
else start()

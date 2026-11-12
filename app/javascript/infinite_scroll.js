// Loads further offer cards as the shopper nears the end of the list.
// Handles loading, end-of-list and error states, and never inserts an offer
// that is already on the page.
export class InfiniteScroll {
  constructor({ list, statusElement, sentinel, fetchBatch, onCardsAdded, createObserver }) {
    this.list = list
    this.statusElement = statusElement
    this.sentinel = sentinel
    this.fetchBatch = fetchBatch
    this.onCardsAdded = onCardsAdded
    this.nextAfter = Number(list.dataset.nextAfter || 0)
    this.hasMore = list.dataset.hasMore === "true"
    this.loading = false
    this.failed = false

    this.observer = createObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.loadMore()
    }, { rootMargin: "600px 0px" })
  }

  start() {
    this.statusElement.querySelector("[data-retry]")?.addEventListener("click", () => {
      this.failed = false
      this.loadMore()
    })
    if (this.hasMore) this.observer.observe(this.sentinel)
    else this.show("end")
  }

  async loadMore() {
    if (this.loading || this.failed || !this.hasMore) return
    this.loading = true
    this.show("loading")

    try {
      const batch = await this.fetchBatch(this.nextAfter)
      this.append(batch.html)
      this.nextAfter = batch.next_after
      this.hasMore = batch.has_more
      this.loading = false

      if (this.hasMore) {
        this.show(null)
        // Re-arm: if the sentinel is still near the viewport, load again.
        this.observer.unobserve(this.sentinel)
        this.observer.observe(this.sentinel)
      } else {
        this.observer.disconnect()
        this.show("end")
      }
    } catch (error) {
      this.loading = false
      this.failed = true
      this.show("error")
    }
  }

  append(html) {
    const template = document.createElement("template")
    template.innerHTML = html
    const added = []

    for (const card of template.content.querySelectorAll("[data-offer-card]")) {
      const id = CSS.escape(card.dataset.offerId)
      if (this.list.querySelector(`[data-offer-id="${id}"]`)) continue // duplicate guard
      this.list.appendChild(card)
      added.push(card)
    }
    this.onCardsAdded(added)
  }

  show(state) {
    for (const element of this.statusElement.querySelectorAll("[data-state]")) {
      element.hidden = element.dataset.state !== state
    }
  }
}

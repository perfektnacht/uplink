import { Controller } from "@hotwired/stimulus"

// Suggestions as chips under the field rather than a native <datalist>.
//
// A datalist opens its own popup in exactly the corner of the input where a
// password manager puts its icon and its own dropdown, so the two overlap and
// the arrow becomes hard to hit. These are ordinary buttons: nothing pops up,
// nothing overlaps, and every option is visible at once instead of hidden
// behind a control you have to discover.
export default class extends Controller {
  static targets = ["field"]

  pick({ params }) {
    this.fieldTarget.value = params.value
    this.fieldTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.#mark()
  }

  connect() { this.#mark() }
  mark() { this.#mark() }

  #mark() {
    const current = this.fieldTarget.value.trim().toLowerCase()
    for (const chip of this.element.querySelectorAll("[data-suggest-value-param]")) {
      chip.classList.toggle("chip--on", chip.dataset.suggestValueParam.toLowerCase() === current)
    }
  }
}

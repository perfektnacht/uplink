import { Controller } from "@hotwired/stimulus"

// The inspector is a Turbo frame; closing it is emptying it. Escape closes it
// too, because a panel you opened with a click should not need a second one.
export default class extends Controller {
  connect() {
    this.onKey = this.#key.bind(this)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  close(event) {
    event?.preventDefault()
    this.element.querySelector("turbo-frame").innerHTML = ""
  }

  #key(event) {
    if (event.key === "Escape") this.close()
  }
}

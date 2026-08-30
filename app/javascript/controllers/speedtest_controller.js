import { Controller } from "@hotwired/stimulus"

// Kicks off a measurement and then gets out of the way: the result arrives as
// a Turbo Stream when the job finishes, so there is nothing to poll and
// nothing to wait on here.
export default class extends Controller {
  static values = { url: String }

  async run() {
    this.element.disabled = true
    this.element.textContent = "measuring…"

    await fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content }
    })

    // The button is only a trigger; the number lives in the HUD.
    setTimeout(() => {
      this.element.disabled = false
      this.element.textContent = "run speedtest"
    }, 4000)
  }
}

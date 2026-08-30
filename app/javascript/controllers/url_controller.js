import { Controller } from "@hotwired/stimulus"
import { tidy } from "urls"

// Repairs a URL field when you leave it, so what you see is what will be
// saved. The server tidies the same way on the way in — this exists because
// watching a field hold something you did not type, until a save silently
// fixes it, is unnerving even when the result is right.
export default class extends Controller {
  tidy() {
    const before = this.element.value

    // Never turn an empty field into "http://" while someone is still
    // deciding what to put in it.
    if (before.trim() === "") return

    const after = tidy(before)
    if (after !== before) this.element.value = after
  }
}

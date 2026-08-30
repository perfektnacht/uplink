import { Controller } from "@hotwired/stimulus"
import { repair, tidy } from "urls"

// Keeps a URL field honest. The server applies the same rules on save; this
// exists so the field shows what will be saved rather than holding something
// you did not type until a save silently fixes it.
export default class extends Controller {
  // Something between the keyboard and this field eats the second slash of
  // "http://" when a paste lands after it. Repair runs immediately because it
  // only ever undoes damage.
  paste() {
    requestAnimationFrame(() => this.#apply(repair(this.element.value)))
  }

  // Assuming http:// for a scheme-less address is a guess, so it waits until
  // you have finished with the field.
  tidy() {
    if (this.element.value.trim() !== "") this.#apply(tidy(this.element.value))
  }

  #apply(value) {
    const field = this.element
    if (value === field.value) return

    const atEnd = field.selectionStart === field.value.length
    field.value = value
    if (atEnd) field.setSelectionRange(value.length, value.length)
  }
}

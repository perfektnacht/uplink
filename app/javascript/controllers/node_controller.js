import { Controller } from "@hotwired/stimulus"

const GRID = 8

// Dragging one card. Position is written straight to the element's custom
// properties during the drag — no re-render, no round trip — and saved once on
// drop. The cables redraw themselves by listening for uplink:moved.
export default class extends Controller {
  static values = { url: String }

  start(event) {
    if (!this.#editing || event.button !== 0) return
    event.preventDefault()
    event.stopPropagation()

    const style = getComputedStyle(this.element)
    this.origin = {
      pointer: { x: event.clientX, y: event.clientY },
      node: { x: parseFloat(style.getPropertyValue("--x")), y: parseFloat(style.getPropertyValue("--y")) },
      scale: this.#scale
    }

    this.element.setPointerCapture(event.pointerId)
    this.element.classList.add("node--dragging")

    this.onMove = this.#move.bind(this)
    this.onUp = this.#drop.bind(this)
    this.element.addEventListener("pointermove", this.onMove)
    this.element.addEventListener("pointerup", this.onUp)
    this.element.addEventListener("pointercancel", this.onUp)
  }

  // Dragging from the wire handle draws a cable instead of moving the card.
  wire(event) {
    if (!this.#editing) return
    event.preventDefault()
    event.stopPropagation()
    this.dispatch("wire", { detail: { from: this.element.id }, prefix: "uplink", target: document })
  }

  #move(event) {
    // Divide by the canvas scale so the card tracks the cursor exactly rather
    // than drifting away from it as you zoom out.
    const dx = (event.clientX - this.origin.pointer.x) / this.origin.scale
    const dy = (event.clientY - this.origin.pointer.y) / this.origin.scale

    this.x = Math.max(0, Math.round((this.origin.node.x + dx) / GRID) * GRID)
    this.y = Math.max(0, Math.round((this.origin.node.y + dy) / GRID) * GRID)

    this.element.style.setProperty("--x", `${this.x}px`)
    this.element.style.setProperty("--y", `${this.y}px`)
    this.dispatch("moved", { prefix: "uplink", target: document })
  }

  async #drop(event) {
    this.element.releasePointerCapture(event.pointerId)
    this.element.classList.remove("node--dragging")
    this.element.removeEventListener("pointermove", this.onMove)
    this.element.removeEventListener("pointerup", this.onUp)
    this.element.removeEventListener("pointercancel", this.onUp)

    if (this.x === undefined) return

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: JSON.stringify({ node: { x: this.x, y: this.y } })
    })

    this.x = this.y = undefined
  }

  get #editing() {
    return this.element.closest(".stage")?.classList.contains("stage--editing")
  }

  get #scale() {
    const viewport = this.element.closest(".stage__viewport")
    return new DOMMatrixReadOnly(getComputedStyle(viewport).transform).a || 1
  }
}

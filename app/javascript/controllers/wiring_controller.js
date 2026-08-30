import { Controller } from "@hotwired/stimulus"

// Drawing a cable. The wire handle on a card starts it, a rubber band follows
// the cursor, and dropping on another card creates the link. Nothing is saved
// until the drop lands on something real.
export default class extends Controller {
  connect() {
    this.onWire = this.#begin.bind(this)
    document.addEventListener("uplink:wire", this.onWire)
  }

  disconnect() {
    document.removeEventListener("uplink:wire", this.onWire)
    this.#end()
  }

  #begin(event) {
    this.from = document.getElementById(event.detail.from)
    if (!this.from) return

    this.band = document.createElementNS("http://www.w3.org/2000/svg", "path")
    this.band.setAttribute("class", "cable cable--drawing")
    this.element.querySelector(".cables").appendChild(this.band)

    this.onMove = this.#drag.bind(this)
    this.onUp = this.#drop.bind(this)
    document.addEventListener("pointermove", this.onMove)
    document.addEventListener("pointerup", this.onUp, { once: true })
    document.body.classList.add("wiring")
  }

  #drag(event) {
    const start = this.#center(this.from)
    const point = this.#toCanvas(event.clientX, event.clientY)
    this.band.setAttribute("d", `M ${start.x} ${start.y} L ${point.x} ${point.y}`)

    const over = this.#nodeUnder(event)
    for (const card of this.element.querySelectorAll(".node")) {
      card.classList.toggle("node--target", card === over && card !== this.from)
    }
  }

  async #drop(event) {
    const target = this.#nodeUnder(event)
    const from = this.from
    this.#end()

    if (!target || target === from) return

    await fetch("/links", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: JSON.stringify({
        link: {
          from_node_id: from.id.replace("node_", ""),
          to_node_id: target.id.replace("node_", ""),
          kind: event.shiftKey ? "logical" : "ethernet"
        }
      })
    })
  }

  #end() {
    document.removeEventListener("pointermove", this.onMove)
    document.body.classList.remove("wiring")
    this.band?.remove()
    this.band = this.from = null
    for (const card of this.element.querySelectorAll(".node--target")) {
      card.classList.remove("node--target")
    }
  }

  // elementFromPoint sees the rubber band, which follows the cursor and would
  // otherwise be the only thing ever under it.
  #nodeUnder(event) {
    this.band.style.display = "none"
    const element = document.elementFromPoint(event.clientX, event.clientY)
    this.band.style.display = ""
    return element?.closest(".node")
  }

  #center(card) {
    return { x: card.offsetLeft + card.offsetWidth / 2, y: card.offsetTop + card.offsetHeight / 2 }
  }

  // Screen pixels back into canvas coordinates, undoing the viewport transform.
  #toCanvas(x, y) {
    const viewport = this.element.querySelector(".stage__viewport")
    const rect = viewport.getBoundingClientRect()
    const scale = new DOMMatrixReadOnly(getComputedStyle(viewport).transform).a || 1
    return { x: (x - rect.left) / scale, y: (y - rect.top) / scale }
  }
}

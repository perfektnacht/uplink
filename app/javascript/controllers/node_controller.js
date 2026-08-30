import { Controller } from "@hotwired/stimulus"

const GRID = 8
const SNAP = 10   // how close a card has to get before it locks onto a neighbour

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

    // Capture keeps the pointer aimed at this card, but it is an optimisation,
    // not a requirement — and it throws outright on a pointer id the browser
    // does not consider active. The listeners go on the document either way,
    // so a fast drag that outruns the card still tracks.
    this.pointerId = event.pointerId
    try { this.element.setPointerCapture(event.pointerId) } catch {}
    this.element.classList.add("node--dragging")

    this.onMove = this.#move.bind(this)
    this.onUp = this.#drop.bind(this)
    document.addEventListener("pointermove", this.onMove)
    document.addEventListener("pointerup", this.onUp)
    document.addEventListener("pointercancel", this.onUp)
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

    let x = Math.max(0, Math.round((this.origin.node.x + dx) / GRID) * GRID)
    let y = Math.max(0, Math.round((this.origin.node.y + dy) / GRID) * GRID)

    // A cable leaves a card from the middle of a face, so it only looks
    // straight when the two cards' centres line up. Cards are different widths,
    // so an 8px grid never achieves that on its own — hence snapping to the
    // neighbours themselves, and showing why.
    const guides = this.#align(x, y)
    if (guides.x !== undefined) x = guides.x
    if (guides.y !== undefined) y = guides.y
    this.#drawGuides(guides)

    this.x = x
    this.y = y
    this.element.style.setProperty("--x", `${x}px`)
    this.element.style.setProperty("--y", `${y}px`)
    this.dispatch("moved", { prefix: "uplink", target: document })
  }

  // Looks for a neighbour this card is nearly in line with, and returns the
  // exact coordinate that would make it flush.
  //
  // Centres outrank edges even when an edge is closer, because a cable leaves
  // a card from the middle of a face: aligning centres is what makes the line
  // straight, while aligning edges only makes the layout tidy.
  #align(x, y) {
    const others = [ ...document.querySelectorAll(".node") ].filter(node => node !== this.element)
    const result = {}

    const settle = (position, size, lineOf) => {
      let best = null

      for (const other of others) {
        const { start, extent } = lineOf(other)

        for (const [ line, mine, centre ] of [
          [ start + extent / 2, size / 2, true ],
          [ start, 0, false ],
          [ start + extent, size, false ]
        ]) {
          const distance = Math.abs(line - mine - position)
          if (distance > SNAP) continue
          if (!best || (centre && !best.centre) || (centre === best.centre && distance < best.distance)) {
            best = { at: Math.round(line - mine), line, centre, distance }
          }
        }
      }

      return best
    }

    const horizontal = settle(x, this.element.offsetWidth,
      node => ({ start: node.offsetLeft, extent: node.offsetWidth }))
    const vertical = settle(y, this.element.offsetHeight,
      node => ({ start: node.offsetTop, extent: node.offsetHeight }))

    if (horizontal) { result.x = horizontal.at; result.vertical = horizontal.line }
    if (vertical) { result.y = vertical.at; result.horizontal = vertical.line }

    return result
  }

  #drawGuides({ vertical, horizontal }) {
    const svg = document.querySelector(".cables")
    let layer = svg.querySelector("#guides")
    if (!layer) {
      layer = document.createElementNS("http://www.w3.org/2000/svg", "g")
      layer.id = "guides"
      svg.appendChild(layer)
    }
    layer.replaceChildren()

    const line = (x1, y1, x2, y2) => {
      const el = document.createElementNS("http://www.w3.org/2000/svg", "line")
      el.setAttribute("class", "guide")
      el.setAttribute("x1", x1); el.setAttribute("y1", y1)
      el.setAttribute("x2", x2); el.setAttribute("y2", y2)
      layer.appendChild(el)
    }

    if (vertical !== undefined) line(vertical, 0, vertical, 3000)
    if (horizontal !== undefined) line(0, horizontal, 4000, horizontal)
  }

  async #drop() {
    try { this.element.releasePointerCapture(this.pointerId) } catch {}
    this.element.classList.remove("node--dragging")
    document.removeEventListener("pointermove", this.onMove)
    document.removeEventListener("pointerup", this.onUp)
    document.removeEventListener("pointercancel", this.onUp)

    document.querySelector("#guides")?.replaceChildren()

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

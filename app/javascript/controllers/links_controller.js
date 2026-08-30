import { Controller } from "@hotwired/stimulus"

const RADIUS = 10   // corner rounding on the elbows
const STUB = 18     // how far a cable leaves a card before it turns

// Draws the cables. The server knows which nodes a link joins; only the
// browser knows where those nodes currently are, so the geometry lives here.
//
// Routing is orthogonal — cables leave a card square-on, turn at right angles,
// and arrive square-on — because that is how a rack diagram reads, and because
// a bezier between two boxes tells you nothing a straight line would not.
export default class extends Controller {
  static targets = ["svg"]

  connect() {
    this.draw = this.#schedule.bind(this)
    document.addEventListener("uplink:moved", this.draw)
    window.addEventListener("resize", this.draw)

    // Cards change size when a service goes down and grows an error line, and
    // Turbo replaces whole cards on a status change. Watch for both.
    this.observer = new MutationObserver(this.draw)
    this.observer.observe(document.getElementById("nodes"), {
      childList: true, subtree: true, attributes: true, attributeFilter: ["style", "class"]
    })

    this.#schedule()
  }

  disconnect() {
    document.removeEventListener("uplink:moved", this.draw)
    window.removeEventListener("resize", this.draw)
    this.observer?.disconnect()
  }

  // Clicking a cable opens it in the inspector. Setting a turbo-frame's src is
  // a frame navigation, which is exactly what the edit link on a card does —
  // an SVG path just cannot be an <a> without a great deal more ceremony.
  edit(event) {
    event.preventDefault()
    document.getElementById("inspector").src = event.currentTarget.dataset.url
  }

  #schedule() {
    if (this.pending) return
    this.pending = requestAnimationFrame(() => {
      this.pending = null
      this.#drawAll()
    })
  }

  #drawAll() {
    for (const cable of this.svgTarget.querySelectorAll(".cable")) {
      const from = document.getElementById(cable.dataset.from)
      const to = document.getElementById(cable.dataset.to)

      if (!from || !to) { cable.removeAttribute("d"); continue }
      cable.setAttribute("d", this.#route(this.#box(from), this.#box(to)))
    }
  }

  #box(el) {
    return { x: el.offsetLeft, y: el.offsetTop, w: el.offsetWidth, h: el.offsetHeight }
  }

  // Pick the pair of faces that point at each other, then elbow between them.
  #route(a, b) {
    const ac = { x: a.x + a.w / 2, y: a.y + a.h / 2 }
    const bc = { x: b.x + b.w / 2, y: b.y + b.h / 2 }
    const dx = bc.x - ac.x
    const dy = bc.y - ac.y

    if (Math.abs(dy) >= Math.abs(dx)) {
      // Mostly vertical: leave the bottom (or top) and turn at the midpoint.
      const down = dy > 0
      const start = { x: ac.x, y: down ? a.y + a.h : a.y }
      const end = { x: bc.x, y: down ? b.y : b.y + b.h }
      const mid = (start.y + end.y) / 2
      return this.#elbow(start, end, [
        { x: start.x, y: mid }, { x: end.x, y: mid }
      ])
    }

    const right = dx > 0
    const start = { x: right ? a.x + a.w : a.x, y: ac.y }
    const end = { x: right ? b.x : b.x + b.w, y: bc.y }
    const mid = (start.x + end.x) / 2
    return this.#elbow(start, end, [
      { x: mid, y: start.y }, { x: mid, y: end.y }
    ])
  }

  // Builds the path with a short straight stub off each card, then rounded
  // corners through the waypoints, so cables meet a card perpendicular.
  #elbow(start, end, waypoints) {
    const vertical = waypoints[0].x === start.x
    const stubStart = vertical
      ? { x: start.x, y: start.y + Math.sign(waypoints[0].y - start.y) * Math.min(STUB, Math.abs(waypoints[0].y - start.y)) }
      : { x: start.x + Math.sign(waypoints[0].x - start.x) * Math.min(STUB, Math.abs(waypoints[0].x - start.x)), y: start.y }

    const points = [start, stubStart, ...waypoints, end]
    let d = `M ${points[0].x} ${points[0].y}`

    for (let i = 1; i < points.length - 1; i++) {
      const previous = points[i - 1], current = points[i], next = points[i + 1]
      const into = this.#step(previous, current, RADIUS)
      const out = this.#step(next, current, RADIUS)
      d += ` L ${into.x} ${into.y} Q ${current.x} ${current.y} ${out.x} ${out.y}`
    }

    return `${d} L ${end.x} ${end.y}`
  }

  // A point `distance` back from `corner` along the line from `toward`.
  #step(toward, corner, distance) {
    const dx = toward.x - corner.x
    const dy = toward.y - corner.y
    const length = Math.hypot(dx, dy)
    if (length === 0) return corner
    const ratio = Math.min(distance, length / 2) / length
    return { x: corner.x + dx * ratio, y: corner.y + dy * ratio }
  }
}

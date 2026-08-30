import { Controller } from "@hotwired/stimulus"

// Pan, zoom, and the one global piece of state the canvas has: whether you are
// looking at the network or rearranging it. In view mode a node is a set of
// links you click; in edit mode it is a thing you drag. Keeping those apart is
// what stops the everyday case from being cluttered with handles you never use.
export default class extends Controller {
  static targets = ["viewport", "modeButton"]

  connect() {
    const saved = this.#restore()
    this.view = { x: 0, y: 0, scale: 1, ...saved }
    this.editing = false
    this.#apply()

    // Nothing saved means this browser has never seen the canvas. Frame the
    // network rather than opening on the empty corner of the sheet — but wait
    // a frame, because the cards have no measurable size until they lay out.
    if (!saved.scale) requestAnimationFrame(() => this.reset())

    this.onKey = this.#key.bind(this)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  // Middle-drag always pans. Left-drag pans only on the background, so a
  // left-drag that starts on a card can mean "move the card" instead.
  panStart(event) {
    const onBackground = event.target === this.element || event.target === this.viewportTarget
    if (event.button !== 1 && !(event.button === 0 && onBackground)) return

    event.preventDefault()
    this.panning = { x: event.clientX, y: event.clientY, ox: this.view.x, oy: this.view.y }
    this.element.setPointerCapture(event.pointerId)
    this.element.classList.add("stage--panning")
  }

  pan(event) {
    if (!this.panning) return
    this.view.x = this.panning.ox + (event.clientX - this.panning.x)
    this.view.y = this.panning.oy + (event.clientY - this.panning.y)
    this.#apply()
  }

  panEnd() {
    if (!this.panning) return
    this.panning = null
    this.element.classList.remove("stage--panning")
    this.#persist()
  }

  // Zoom toward the cursor, so the thing you are pointing at stays put.
  zoom(event) {
    if (!event.ctrlKey && !event.metaKey) return
    event.preventDefault()

    const rect = this.element.getBoundingClientRect()
    const px = event.clientX - rect.left
    const py = event.clientY - rect.top
    const next = Math.min(2.5, Math.max(0.25, this.view.scale * (event.deltaY < 0 ? 1.1 : 0.9)))
    const ratio = next / this.view.scale

    this.view.x = px - (px - this.view.x) * ratio
    this.view.y = py - (py - this.view.y) * ratio
    this.view.scale = next
    this.#apply()
    this.#persist()
  }

  // Frames everything on the canvas, rather than snapping the transform back to
  // the origin. The origin is the corner of a 4000x3000 sheet and the network
  // is rarely anywhere near it, so "reset" used to mean "look at empty grid".
  reset() {
    const box = this.#contents()
    if (!box) return

    const PAD = 56
    const stage = this.element.getBoundingClientRect()
    const hud = this.element.querySelector(".hud")?.offsetHeight ?? 0

    const width = Math.max(1, stage.width - PAD * 2)
    const height = Math.max(1, stage.height - hud - PAD * 2)

    // Never magnify past life size: a two-node network blown up to fill a
    // 27-inch display looks broken, not helpful.
    const scale = Math.max(0.2, Math.min(1, width / box.width, height / box.height))

    this.view = {
      scale,
      x: PAD + (width - box.width * scale) / 2 - box.x * scale,
      y: PAD + (height - box.height * scale) / 2 - box.y * scale
    }

    this.#apply()
    this.#persist()
  }

  // The bounding box of every card, in canvas coordinates.
  #contents() {
    const cards = this.element.querySelectorAll(".node")
    if (cards.length === 0) return null

    let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity

    for (const card of cards) {
      left = Math.min(left, card.offsetLeft)
      top = Math.min(top, card.offsetTop)
      right = Math.max(right, card.offsetLeft + card.offsetWidth)
      bottom = Math.max(bottom, card.offsetTop + card.offsetHeight)
    }

    return { x: left, y: top, width: Math.max(1, right - left), height: Math.max(1, bottom - top) }
  }

  toggleMode() {
    this.editing = !this.editing
    this.element.classList.toggle("stage--editing", this.editing)
    if (this.hasModeButtonTarget) this.modeButtonTarget.textContent = this.editing ? "edit" : "view"
  }

  // A keydown can be aimed at the document itself rather than an element, so
  // this asks whether the target is typeable rather than assuming it is an
  // Element with .matches.
  #key(event) {
    if (event.target instanceof Element && event.target.closest("input, textarea, select")) return
    if (event.key === "e") this.toggleMode()
    if (event.key === "0") this.reset()
  }

  #apply() {
    const { x, y, scale } = this.view
    this.viewportTarget.style.transform = `translate(${x}px, ${y}px) scale(${scale})`

    // The grid is painted on the stage, which never moves, so it has to be
    // told where the canvas went.
    this.element.style.setProperty("--grid", `${96 * scale}px`)
    this.element.style.setProperty("--grid-x", `${x}px`)
    this.element.style.setProperty("--grid-y", `${y}px`)
  }

  // Viewport position is a per-browser convenience, not data. It belongs in
  // localStorage, not in the database with the network itself.
  #persist() {
    try { localStorage.setItem("uplink:view", JSON.stringify(this.view)) } catch {}
  }

  #restore() {
    try { return JSON.parse(localStorage.getItem("uplink:view")) || {} } catch { return {} }
  }
}

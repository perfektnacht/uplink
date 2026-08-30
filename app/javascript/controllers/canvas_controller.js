import { Controller } from "@hotwired/stimulus"

// Pan, zoom, and the one global piece of state the canvas has: whether you are
// looking at the network or rearranging it. In view mode a node is a set of
// links you click; in edit mode it is a thing you drag. Keeping those apart is
// what stops the everyday case from being cluttered with handles you never use.
export default class extends Controller {
  static targets = ["viewport", "modeButton"]

  connect() {
    this.view = { x: 0, y: 0, scale: 1, ...this.#restore() }
    this.editing = false
    this.#apply()

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

  reset() {
    this.view = { x: 0, y: 0, scale: 1 }
    this.#apply()
    this.#persist()
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

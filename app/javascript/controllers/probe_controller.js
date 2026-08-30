import { Controller } from "@hotwired/stimulus"

// Shows only the fields the chosen probe actually reads. A ping has no port
// and no URL, so offering both — one of them with a "80" sitting in it —
// suggests icmp needs configuring that it will silently ignore.
export default class extends Controller {
  static targets = ["kind", "port", "url"]

  connect() { this.refresh() }

  refresh() {
    const kind = this.kindTarget.value
    this.portTarget.hidden = kind !== "tcp"
    this.urlTarget.hidden = kind !== "http"
  }
}

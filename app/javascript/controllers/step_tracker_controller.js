import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  activate(event) {
    this.itemTargets.forEach(el => el.classList.remove("active"))
    event.currentTarget.classList.add("active")
  }
}

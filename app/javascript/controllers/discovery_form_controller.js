import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values  = { cancelUrl: String }

  // Fires after Turbo has captured the request — safe to replace form content here.
  handleSubmit() {
    this.submitTarget.disabled    = true
    this.submitTarget.textContent = "Generating..."
    this.element.innerHTML        = this.loadingHTML()
  }

  loadingHTML() {
    const cancel = this.hasCancelUrlValue
      ? `<a href="${this.cancelUrlValue}" data-turbo-frame="step_content" class="btn btn-sm btn-outline-secondary mt-3">Cancel</a>`
      : ""
    return `
      <div class="text-center py-5" data-discovery-form-target="submit">
        <div class="spinner-border text-primary mb-3" role="status" style="width:2.5rem;height:2.5rem;">
          <span class="visually-hidden">Generating...</span>
        </div>
        <p class="text-muted mb-0">Generating AI analysis — usually 5–10 seconds.</p>
        ${cancel}
      </div>
    `
  }
}

# Prodmentum Demo — Phased Build Specification

**Source spec:** `docs/open-prodmentum/prodmentum-demo-spec.md`  
**Boilerplate:** Open Demo Starter v2.0  
**Task tracker:** `tasks.md` (project root)

---

## Implementation Notes (Read Before Building)

### Model name correction
The source spec (Section 7) lists `gemini-2.0-flash` for all five templates. Per `docs/ai-templates.md` and `CLAUDE.md`, this model is deprecated for new API keys and returns 404 on v1beta. **Use `gemini-2.5-flash` for all five templates.**

### CSS correction
The source spec references `app/assets/stylesheets/_accent.scss`. The boilerplate uses Propshaft — no SCSS compilation pipeline. **All CSS additions go into `app/assets/stylesheets/application.css`.** Add `--cta` variable and the two utility classes there.

### Markdown rendering
Step 3, 4, and 5 outputs contain markdown tables and structured content. Add the `redcarpet` gem in Phase 4 before implementing the output display. The source spec confirms this: "add `redcarpet` gem" and use `tables` extension.

### Step data flow across templates
Templates for steps 2–5 pull variables from prior steps:
- Steps 2, 3, 4, 5 → need `{{problem}}` from step 1's `user_input`
- Steps 4, 5 → need `{{solution_idea}}` from step 4's `user_input`
- The `step_variables(step)` private method in `DiscoveryStepsController` must load sibling steps and parse their `user_input` to supply these cross-step variables.

### user_input storage and parsing
`DiscoveryStep#user_input` stores a plain text blob assembled from the step's sub-fields. Sub-fields vary by step. The controller assembles `user_input` on save and also parses it back into named keys when building template variables. A simple `|FIELD_NAME|value` or key-value convention within `user_input` works; a YAML-style labeled block is also acceptable. **Pick one approach in Phase 3 and use it consistently across all five steps.**

Recommended convention (simple, parseable):
```
FIELD:problem
PMs have no lightweight way...
FIELD:constraints
2 engineers, 6 weeks...
```
Parse with a helper that splits on `FIELD:` markers. Document this convention in `DiscoveryStepsController` comments.

---

## Phase 0 — App Customization

**Goal:** Update all branding, accent color, landing page, and dashboard to match Prodmentum Demo identity.

### 0.1 Environment & Branding
- Update `.env.example`:
  - `APP_NAME="Prodmentum Demo"`
  - `APP_TAGLINE="Walk your product idea through a structured discovery process. AI guides you at every step."`
  - `APP_DESCRIPTION="An open source Rails 8 demo of AI-assisted product discovery using Cagan's continuous discovery framework."`

### 0.2 CSS — Accent & CTA Variables
In `app/assets/stylesheets/application.css`, add to `:root`:
```css
--cta: #ea580c;
--cta-hover: #c2410c;
```
Add utility classes at the bottom of the file:
```css
.step-locked {
  opacity: 0.45;
  pointer-events: none;
  cursor: default;
}

.step-complete-badge {
  color: var(--accent);
}
```
Active list-group override (for step tracker):
```css
.list-group-item.active {
  background-color: var(--accent);
  border-color: var(--accent);
}
```
CTA button class:
```css
.btn-cta {
  background-color: var(--cta);
  border-color: var(--cta);
  color: #fff;
}
.btn-cta:hover {
  background-color: var(--cta-hover);
  border-color: var(--cta-hover);
  color: #fff;
}
```

### 0.3 Home Page
Replace `app/views/home/index.html.erb` with:
- Hero section: `APP_NAME`, `APP_TAGLINE`, orange CTA button → sign-up or dashboard
- Five-step workflow summary (icons + step names)
- Brief explanation of the Cagan discovery framework
- "Start a Product Discovery" CTA (`.btn-cta`, links to `sign_up_path` for unauthenticated, `products_path` for signed-in)

### 0.4 Dashboard
Replace `app/views/dashboard/show.html.erb` with:
- Greeting with `current_user.first_name`
- List of the user's products (from `current_user.products.order(created_at: :desc)`)
- Count of completed steps per product
- "New Product" button

Note: This is a stub until Phase 2. After Phase 2, the dashboard can delegate to the Products controller's index logic, or stay as a standalone view. Per the spec, `products#index` is the canonical product list — the dashboard shows the same content.

### 0.5 Navbar
In `app/views/layouts/application.html.erb`, add a "My Products" nav link (only shown when signed in) pointing to `products_path`.

### Phase 0 Tests
**Manual:**
- Load `/` — see Prodmentum Demo name, tagline, CTA button
- Sign in — navbar shows "My Products"
- Load dashboard — no crash (stub content acceptable until Phase 2)
- Verify CTA button is orange, primary links are blue

---

## Phase 1 — Data Models

**Goal:** Create `Product` and `DiscoveryStep` models with all fields, validations, and associations.

### 1.1 Product Migration
```ruby
create_table :products, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string :name, null: false, limit: 120
  t.string :target_customer, null: false, limit: 200
  t.string :strategic_goal, null: false, limit: 300
  t.timestamps null: false
end
add_index :products, :user_id
add_index :products, :created_at
```

### 1.2 Product Model (`app/models/product.rb`)
```ruby
class Product < ApplicationRecord
  belongs_to :user
  has_many :discovery_steps, dependent: :destroy

  validates :name,            presence: true, length: { maximum: 120 }
  validates :target_customer, presence: true, length: { maximum: 200 }
  validates :strategic_goal,  presence: true, length: { maximum: 300 }
end
```

### 1.3 DiscoveryStep Migration
```ruby
create_table :discovery_steps, id: :uuid do |t|
  t.references :product, null: false, foreign_key: true, type: :uuid
  t.integer :step_number, null: false
  t.string  :step_name,   null: false
  t.text    :user_input
  t.text    :gemini_output
  t.text    :gemini_raw
  t.boolean :completed,   null: false, default: false
  t.timestamps null: false
end
add_index :discovery_steps, :product_id
add_index :discovery_steps, [:product_id, :step_number], unique: true
```

### 1.4 DiscoveryStep Model (`app/models/discovery_step.rb`)
```ruby
class DiscoveryStep < ApplicationRecord
  belongs_to :product
  has_one :user, through: :product

  STEP_NAMES = {
    1 => "Opportunity Framing",
    2 => "Customer Research Planning",
    3 => "Ideation and Prototyping",
    4 => "Risk Assessment",
    5 => "Iteration Planning"
  }.freeze

  validates :step_number, presence: true,
                          inclusion: { in: 1..5 },
                          uniqueness: { scope: :product_id }
  validates :step_name, presence: true
end
```

### 1.5 Factories
- `spec/factories/products.rb` — with traits or associations for `user`
- `spec/factories/discovery_steps.rb` — with traits for each step_number and for `:completed`

### 1.6 Model Specs
**`spec/models/product_spec.rb`:**
1. Validates presence of `name`, `target_customer`, `strategic_goal`
2. Validates `name` maximum 120 characters
3. `belongs_to :user`
4. `has_many :discovery_steps, dependent: :destroy` — destroy cascades
5. Scoping: user A's product is not in `user_b.products`

**`spec/models/discovery_step_spec.rb`:**
1. Validates presence of `step_number` and `step_name`
2. Validates `step_number` uniqueness scoped to `product_id`
3. Validates `step_number` inclusion in 1..5
4. `belongs_to :product`
5. `completed` defaults to false

### Phase 1 Tests
**Manual:**
- `rails db:migrate` runs without error
- `rails console` → `Product.new` and `DiscoveryStep.new` are available
- `Product.create!(name: "Test", target_customer: "PMs", strategic_goal: "grow", user: User.first)` persists

**RSpec:**
```bash
bundle exec rspec spec/models/product_spec.rb spec/models/discovery_step_spec.rb
```

---

## Phase 2 — Products CRUD

**Goal:** Full products controller and views. A user can create, view, edit, and delete products. The show page is the wizard shell (step content pane is a placeholder until Phase 3).

### 2.1 Routes
```ruby
resources :products do
  resources :steps, controller: "discovery_steps", only: [:show, :edit, :update]
end
```
This generates `product_steps_path` nested routes. Verify named helpers match the spec's route table — use shallow nesting if the spec's path style (`/products/:product_id/steps/:id`) is required.

### 2.2 ProductsController
Location: `app/controllers/products_controller.rb`

- `before_action :set_product, only: [:show, :edit, :update, :destroy]`
- `set_product` scopes to `current_user.products.find(params[:id])` — raises `ActiveRecord::RecordNotFound` (404) for other users' products
- **`index`:** `@products = current_user.products.order(created_at: :desc)` with completed step counts
- **`new`:** `@product = Product.new`
- **`create`:** Creates product, then creates 5 `DiscoveryStep` records using `DiscoveryStep::STEP_NAMES`. Redirects to `product_path(@product)` on success.
- **`show`:** Loads all 5 steps ordered by `step_number`. Sets `@active_step` to first incomplete step (default to step 1 if all complete).
- **`edit`/`update`:** Standard form. On success, redirect to `product_path(@product)`.
- **`destroy`:** Destroys product (cascades to steps). Redirects to `products_path`.

Private `create_discovery_steps` helper:
```ruby
def create_discovery_steps
  DiscoveryStep::STEP_NAMES.each do |num, name|
    @product.discovery_steps.create!(step_number: num, step_name: name)
  end
end
```

### 2.3 Views

**`products/index.html.erb`:**
- Bootstrap card grid, two columns on md+
- Per card: product name, target customer, strategic goal snippet, five-dot step progress indicator, "Continue Discovery" or "Start Discovery" button
- "Add New Product" card always last

Five-dot progress indicator (inline, no Stimulus needed):
```erb
<div class="d-flex gap-1">
  <% product.discovery_steps.order(:step_number).each do |step| %>
    <span class="<%= step.completed? ? 'text-primary' : 'text-muted' %>">&#9679;</span>
  <% end %>
</div>
```

**`products/_form.html.erb`:**
- Fields: `name`, `target_customer`, `strategic_goal`
- Primary submit button (blue `btn-primary`)
- Cancel link

**`products/new.html.erb`** and **`products/edit.html.erb`:** Render the form partial.

**`products/show.html.erb`:** Two-column wizard layout.
- Left (col-md-4): `render "products/step_tracker", product: @product, active_step: @active_step`
- Right (col-md-8): `turbo_frame_tag :step_content` with a GET to `discovery_steps#show` for `@active_step`
- Product name and edit/delete links in the page header

**`products/_step_tracker.html.erb`:**
Bootstrap `list-group list-group-flush`. Five items. Each item:
- Step number badge
- Step name
- Completed checkmark `bi-check-circle-fill step-complete-badge` if completed
- `active` class on current active step
- `step-locked` class on steps with step_number > first incomplete step
- Clickable `list-group-item-action` linking to `product_step_path` for completed steps
- One-line `gemini_output` preview (first 80 chars) for completed steps

### Phase 2 Tests
**Manual:**
- Create a product via form — verify 5 discovery steps are created in DB
- View product show page — wizard shell renders (step tracker visible, content pane loads)
- Edit product — updates persist
- Delete product — cascades to steps, redirects to index

**RSpec:**
```bash
bundle exec rspec spec/requests/products_spec.rb
```
Cover:
1. `GET /products` — signed-in user sees their products only
2. `POST /products` with valid params — creates product + 5 steps with correct names, `completed: false`
3. `POST /products` with invalid params — re-renders form, no product created
4. `DELETE /products/:id` — destroys product + steps, redirects to index
5. Unauthenticated `GET /products` → redirect to sign in

---

## Phase 3 — Step Wizard UI (Forms, No Gemini)

**Goal:** The full wizard is navigable. All five step forms render. Submitting a form saves `user_input` but does not call Gemini yet (Gemini integration is Phase 4).

### 3.1 DiscoveryStepsController (stub)
Location: `app/controllers/discovery_steps_controller.rb`

```ruby
class DiscoveryStepsController < ApplicationController
  before_action :set_step

  def show
    # renders show.html.erb — conditionally shows form or output
  end

  def edit
    render :show  # re-renders show with form visible
  end

  def update
    # Phase 3: save user_input only; Phase 4: add Gemini call
    assemble_user_input
    if @step.save
      respond_to do |format|
        format.turbo_stream { ... }
        format.html { redirect_to product_path(@step.product) }
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_step
    product = current_user.products.find(params[:product_id])
    @step   = product.discovery_steps.find(params[:id])
  end
end
```

### 3.2 `user_input` Assembly
Use the labeled-block convention. Each step has specific sub-fields:

**Step 1 sub-fields:** `problem`
**Step 2 sub-fields:** `interviewees`, `existing_knowledge`, `biggest_assumption`
**Step 3 sub-fields:** `solution_ideas`, `constraints`
**Step 4 sub-fields:** `solution_idea`, `value_risk_context`, `usability_risk_context`, `feasibility_risk_context`, `viability_risk_context`
**Step 5 sub-fields:** `learnings`, `changes`

Assembly in controller:
```ruby
def assemble_user_input
  fields = step_params.to_h.reject { |_, v| v.blank? }
  @step.user_input = fields.map { |k, v| "FIELD:#{k}\n#{v.strip}" }.join("\n---\n")
end
```

Parse back:
```ruby
def parse_user_input(input)
  return {} if input.blank?
  input.split("\n---\n").each_with_object({}) do |block, hash|
    lines = block.strip.split("\n", 2)
    key   = lines[0].sub("FIELD:", "").strip
    value = lines[1]&.strip || ""
    hash[key.to_sym] = value
  end
end
```

### 3.3 `discovery_steps/_step_form.html.erb`
Branches on `@step.step_number`. Each form:
- Wraps in `form_with model: [@step.product, @step]`
- Has labeled textareas/text fields per the spec's sub-field list
- Pre-populates from `parse_user_input(@step.user_input)` if step was previously saved
- Submit button: `.btn-cta` with `data-controller="discovery-form"` for loading state
- "Cancel" link restores the show view via Turbo Frame GET to `discovery_steps#show`

Step 1 note: Displays `product.target_customer` and `product.strategic_goal` as readonly context above the problem textarea.

### 3.4 `discovery_steps/show.html.erb`
Wrapped in `turbo_frame_tag :step_content`.

Conditional:
```erb
<% if @step.completed? %>
  <%# Phase 4: output display %>
  <p class="text-muted">Output will appear here after Phase 4.</p>
<% else %>
  <%= render "discovery_steps/step_form", step: @step %>
<% end %>
```

### 3.5 discovery-form Stimulus Controller
`app/javascript/controllers/discovery_form_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values  = { loading: Boolean }

  submit() {
    this.loadingValue = true
    this.submitTarget.disabled    = true
    this.submitTarget.textContent = "Generating..."
  }

  loadingValueChanged() {
    // handled via submit()
  }
}
```

In the form:
```erb
<div data-controller="discovery-form">
  ...
  <%= f.submit "Generate with AI",
        class: "btn btn-cta",
        data: { discovery_form_target: "submit",
                action: "click->discovery-form#submit" } %>
</div>
```

### Phase 3 Tests
**Manual:**
- Load `/products/:id` — wizard renders with step tracker
- Click each step in the tracker — correct form renders in right pane
- Step 1 form shows readonly product context, textarea for problem
- Submit step 1 form — `user_input` saved, step remains `completed: false` (no Gemini yet)
- "Generating..." text appears on submit button
- Locked steps (>1) show muted style, are not clickable

**RSpec:**
```bash
bundle exec rspec spec/requests/discovery_steps_spec.rb
```
Cover (Phase 3 subset):
1. `GET /products/:product_id/steps/:id` — renders step form for incomplete step
2. A step belonging to another user's product returns 404
3. `PATCH` with valid input — saves `user_input`, step stays incomplete

---

## Phase 4 — Gemini Integration

**Goal:** `DiscoveryStepsController#update` calls Gemini, stores output, marks step complete, updates the wizard via Turbo Streams.

### 4.1 Add redcarpet Gem
In `Gemfile`:
```ruby
gem "redcarpet"
```

Create a helper for safe markdown rendering (used in views):
```ruby
# app/helpers/markdown_helper.rb
module MarkdownHelper
  def render_markdown(text)
    return "" if text.blank?
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true)
    markdown = Redcarpet::Markdown.new(renderer,
      tables: true, autolink: true, fenced_code_blocks: true,
      strikethrough: true, no_intra_emphasis: true)
    raw markdown.render(text)
  end
end
```

### 4.2 GeminiService Call in `update`
Replace Phase 3 stub with the full flow:

```ruby
def update
  assemble_user_input
  @step.save!

  result = GeminiService.generate(
    template:  "prodmentum_step#{@step.step_number}_#{step_template_suffix}_v1",
    variables: step_variables(@step)
  )

  @step.update!(gemini_output: result, gemini_raw: result, completed: true)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: [
        turbo_stream.update("step_content") { render partial: "discovery_steps/step_output", locals: { step: @step } },
        turbo_stream.update("step_tracker") { render partial: "products/step_tracker", locals: { product: @step.product, active_step: @step } }
      ]
    end
  end

rescue GeminiService::BudgetExceededError
  render_step_error(:budget_exceeded)
rescue GeminiService::GatekeeperError
  render_step_error(:gatekeeper_blocked)
rescue GeminiService::TimeoutError
  render_step_error(:timeout)
rescue GeminiService::GeminiError
  render_step_error(:error)
end
```

### 4.3 Template Name Helper
```ruby
STEP_TEMPLATE_SUFFIXES = {
  1 => "opportunity",
  2 => "research",
  3 => "ideation",
  4 => "risk",
  5 => "iteration"
}.freeze

def step_template_suffix
  STEP_TEMPLATE_SUFFIXES[@step.step_number]
end
```

### 4.4 `step_variables` Private Method
Builds the variable hash for each step's template. Loads prior step data as needed:

```ruby
def step_variables(step)
  product = step.product
  steps   = product.discovery_steps.order(:step_number).index_by(&:step_number)
  step1   = parse_user_input(steps[1]&.user_input)
  step4   = parse_user_input(steps[4]&.user_input)
  current = parse_user_input(step.user_input)

  base = { product_name: product.name, problem: step1[:problem] }

  case step.step_number
  when 1
    base.merge(
      target_customer: product.target_customer,
      strategic_goal:  product.strategic_goal,
      problem:         current[:problem]
    )
  when 2
    base.merge(
      interviewees:       current[:interviewees],
      existing_knowledge: current[:existing_knowledge],
      biggest_assumption: current[:biggest_assumption]
    )
  when 3
    base.merge(
      solution_ideas: current[:solution_ideas],
      constraints:    current[:constraints]
    )
  when 4
    base.merge(
      solution_idea:          current[:solution_idea],
      value_risk_context:     current[:value_risk_context],
      usability_risk_context: current[:usability_risk_context],
      feasibility_risk_context: current[:feasibility_risk_context],
      viability_risk_context: current[:viability_risk_context]
    )
  when 5
    base.merge(
      solution_idea: step4[:solution_idea],
      learnings:     current[:learnings],
      changes:       current[:changes]
    )
  end
end
```

### 4.5 Output Display — `discovery_steps/_step_output.html.erb`
For completed steps. Renders:
1. The formatted `gemini_output` via `render_markdown(@step.gemini_output)`
2. Step 5 only: inline disclaimer near the iterate/pivot/proceed recommendation section
3. "Show raw response" Bootstrap collapse toggle (`btn-link btn-sm text-muted`)
4. `gemini_raw` content inside the collapse div
5. "Regenerate" button (blue, links via Turbo Frame GET to `discovery_steps#edit`)
6. "Continue to Next Step" button (orange `.btn-cta`) — links to next step's show action

The disclaimer for Step 5:
```erb
<% if @step.step_number == 5 %>
  <p class="text-muted small mt-2">
    This is an AI-assisted starting point. Your discovery data and judgment should drive the final call.
  </p>
<% end %>
```

### 4.6 Error Partial — `shared/_step_error.html.erb`
```erb
<%# locals: step:, error_type: %>
<div class="alert alert-danger">
  <strong>AI generation failed on <%= step.step_name %>.</strong>
  <%= render "shared/ai_error", error_type: error_type %>
  <%= link_to "Try Again", edit_product_step_path(step.product, step),
        data: { turbo_frame: :step_content }, class: "btn btn-sm btn-outline-secondary mt-2" %>
</div>
```

Private controller helper:
```ruby
def render_step_error(error_type)
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("step_content") {
        render partial: "shared/step_error",
               locals: { step: @step, error_type: error_type }
      }
    end
  end
end
```

### 4.7 Rate Limiting on Update
In `DiscoveryStepsController`:
```ruby
rate_limit to: 10, within: 1.minute, only: [:update],
           with: -> { redirect_to product_path(@step.product), alert: "Please wait before generating again." }
```

### Phase 4 Tests
**Manual:**
- Submit step 1 with problem text — Gemini returns output, step tracker updates
- Verify output renders with markdown (headers, bullets)
- Step 3 output — table renders correctly via redcarpet
- "Show raw response" toggle reveals raw text
- "Regenerate" button re-opens the form
- "Continue to Next Step" loads step 2 form
- Submit with prompt injection text — gatekeeper blocks, error partial shows
- Test all five steps end-to-end

**RSpec:**
```bash
bundle exec rspec spec/requests/discovery_steps_spec.rb
```
Full coverage:
1. `PATCH` step 1 with valid input → calls `GeminiService.generate` with `prodmentum_step1_opportunity_v1`; `LlmRequest` created; `gemini_output`/`gemini_raw` set; `completed: true`
2. Stubbed Gemini returns markdown → view renders without error
3. Step belonging to another user's product → 404
4. `PATCH` with missing required sub-field → does not call Gemini, re-renders form with error
5. `GeminiService::GeminiError` → step stays incomplete, error partial rendered

---

## Phase 5 — Seeds & Sample Data

**Goal:** All five AI templates seeded. One complete demo product with realistic inputs and seeded Gemini outputs. First-time visitor sees a finished example without needing an API key.

### 5.1 AI Template Seeds

Add to `db/seeds.rb` after the existing boilerplate seeds. Use exact system prompts, user prompt templates, model (`gemini-2.5-flash`), max_output_tokens, and temperature from the source spec Section 7.

Template names:
- `prodmentum_step1_opportunity_v1`
- `prodmentum_step2_research_v1`
- `prodmentum_step3_ideation_v1`
- `prodmentum_step4_risk_v1`
- `prodmentum_step5_iteration_v1`

Each uses `AiTemplate.find_or_create_by!(name: ...)`.

### 5.2 Demo Product Seed

After the templates, create the QuickFeedback demo product with all five steps populated. Use the sample inputs from spec Section 10. Write realistic markdown strings for `gemini_output` and `gemini_raw` matching what the templates would plausibly produce.

```ruby
demo_user = User.find_by!(email: "demo@example.com")
product   = Product.find_or_create_by!(name: "QuickFeedback", user: demo_user) do |p|
  p.target_customer = "B2B SaaS product managers at companies with 10 to 200 employees"
  p.strategic_goal  = "Increase feature adoption by 25% in Q3 by improving feedback loops between customers and product teams"
end

# Create or update each step with seeded inputs + outputs
```

For each step: set `user_input` (using the labeled-block format), `gemini_output` (realistic markdown), `gemini_raw` (same as output), `completed: true`.

The seeded `gemini_output` for each step should match the template's expected output format:
- Step 1: Three markdown sections (Sharpened Opportunity Statement, JTBD Summary, Discovery Questions)
- Step 2: Two sections (Interview Guide with 5 Q+A, What PMs Commonly Miss)
- Step 3: Idea comparison table + Wildcard Idea + Fastest Prototype Approach sections
- Step 4: Four risk sections + Overall Risk Summary
- Step 5: Next Experiments + Recommendation + Discovery Summary for Stakeholders

### Phase 5 Tests
**Manual:**
- `rails db:seed` runs without error
- Sign in as `demo@example.com` — products index shows QuickFeedback card with 5 filled dots
- Click QuickFeedback — all steps show as complete in tracker
- Click each step — seeded output renders correctly, tables render in step 3
- Verify "Show raw response" works on at least one step

**RSpec:**
```bash
bundle exec rspec spec/requests/admin/ai_templates_spec.rb
```
Cover:
1. All five `prodmentum_*_v1` templates present after `db:seed`
2. Admin can edit a template's `system_prompt` and change persists
3. Live test endpoint returns Turbo Stream response

---

## Phase 6 — README & Final Polish

**Goal:** README updated. Minor UI polish. All tests passing.

### 6.1 README
Add to `README.md` (per spec Section 11):
- App name and tagline
- Description paragraph
- "Why I Built This" section
- "Editing the AI Prompts" section
- Setup note (Gemini API key in `.env`)

### 6.2 Final UI Polish
- Verify all `--accent` (blue) and `--cta` (orange) applications match spec Section 12
- Step number badges use `--accent`
- Active list-group item uses `--accent` background
- "Generate with AI" submit buttons use `.btn-cta`
- "Continue to Next Step" uses `.btn-cta`
- "Start Discovery" CTA on landing page uses `.btn-cta`

### 6.3 Full Test Suite
Run the complete suite and confirm zero failures:
```bash
bundle exec rspec
```

Final manual walkthrough: create a new product, complete all five steps, verify end-to-end with a real Gemini API key.

---

## Route Name Reference

Use these named helpers everywhere (views, specs). Never use string paths.

| Helper | Path |
|---|---|
| `products_path` | `GET /products` |
| `new_product_path` | `GET /products/new` |
| `product_path(@product)` | `GET /products/:id` |
| `edit_product_path(@product)` | `GET /products/:id/edit` |
| `product_step_path(@product, @step)` | `GET /products/:product_id/steps/:id` |
| `edit_product_step_path(@product, @step)` | `GET /products/:product_id/steps/:id/edit` |
| `product_step_path(@product, @step), method: :patch` | `PATCH /products/:product_id/steps/:id` |

---

*Prodmentum Demo phased spec — built on Open Demo Starter v2.0*

# Prodmentum Demo — Build Tasks

**Spec:** `docs/open-prodmentum/prodmentum-demo-spec.md`  
**Phased spec:** `docs/open-prodmentum/phased-spec.md`  
**App:** Rails 8 + Gemini, single-user, five-step product discovery wizard

Track progress by checking off tasks as completed. Each phase ends with manual tests and an RSpec command.

---

## Phase 0 — App Customization

### 0.1 Environment & Branding
- [ ] Update `.env.example`: set `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION` to Prodmentum Demo values
- [ ] Verify all views that render `APP_NAME` use `ENV.fetch("APP_NAME", "Open Demo Starter")` — no hardcoded strings

### 0.2 CSS
- [ ] Add `--cta: #ea580c` and `--cta-hover: #c2410c` to `:root` in `application.css`
- [ ] Add `.btn-cta` and `.btn-cta:hover` classes to `application.css`
- [ ] Add `.step-locked` utility class to `application.css`
- [ ] Add `.step-complete-badge` utility class to `application.css`
- [ ] Add `.list-group-item.active` override for `--accent` background/border in `application.css`

### 0.3 Home Page
- [ ] Replace `app/views/home/index.html.erb` with Prodmentum landing page
  - [ ] Hero: `APP_NAME`, `APP_TAGLINE`, orange CTA button to sign-up / products
  - [ ] Five-step workflow summary section with step names
  - [ ] Brief Cagan framework explanation
- [ ] "Start a Product Discovery" CTA routes to `sign_up_path` (unauthenticated) or `products_path` (signed-in)

### 0.4 Dashboard
- [ ] Replace `app/views/dashboard/show.html.erb` with product list stub
  - [ ] Greeting with `current_user.first_name`
  - [ ] Placeholder "New Product" button (links to `new_product_path` — will 404 until Phase 2)
  - [ ] Note: full product list wired in Phase 2

### 0.5 Navbar
- [ ] Add "My Products" nav link in `application.html.erb` (authenticated only) → `products_path`

### Phase 0 Manual Tests
- [ ] Load `/` — shows "Prodmentum Demo", tagline, orange CTA button
- [ ] Sign in as `demo@example.com` — navbar shows "My Products"
- [ ] Load `/dashboard` — no crash, shows greeting
- [ ] Inspect CSS: CTA button is `#ea580c` orange, accent links are `#1d4ed8` blue

---

## Phase 1 — Data Models

### 1.1 Product Model
- [ ] Generate migration: `rails g migration CreateProducts`
- [ ] Migration: `id: :uuid`, `user_id: uuid FK`, `name (string, limit 120, null false)`, `target_customer (string, limit 200, null false)`, `strategic_goal (string, limit 300, null false)`, timestamps
- [ ] Add indexes on `user_id` and `created_at`
- [ ] Run `rails db:migrate`
- [ ] Create `app/models/product.rb` with `belongs_to :user`, `has_many :discovery_steps, dependent: :destroy`
- [ ] Add validations: `name` presence + max 120; `target_customer` presence + max 200; `strategic_goal` presence + max 300

### 1.2 DiscoveryStep Model
- [ ] Generate migration: `rails g migration CreateDiscoverySteps`
- [ ] Migration: `id: :uuid`, `product_id: uuid FK`, `step_number (integer, null false)`, `step_name (string, null false)`, `user_input (text)`, `gemini_output (text)`, `gemini_raw (text)`, `completed (boolean, null false, default false)`, timestamps
- [ ] Add unique index on `[product_id, step_number]`
- [ ] Run `rails db:migrate`
- [ ] Create `app/models/discovery_step.rb` with `belongs_to :product`, `has_one :user, through: :product`
- [ ] Add `STEP_NAMES` constant (hash 1..5 → step name strings)
- [ ] Add validations: `step_number` presence + inclusion 1..5 + uniqueness scoped to `product_id`; `step_name` presence

### 1.3 Factories
- [ ] Create `spec/factories/products.rb` (with `user` association, traits if needed)
- [ ] Create `spec/factories/discovery_steps.rb` (with `product` association; traits for `:completed`, `:step1` through `:step5`)

### 1.4 Model Specs
- [ ] Create `spec/models/product_spec.rb`
  - [ ] Validates presence of `name`, `target_customer`, `strategic_goal`
  - [ ] Validates `name` max 120 chars
  - [ ] `belongs_to :user`
  - [ ] `has_many :discovery_steps, dependent: :destroy` — destroying product destroys steps
  - [ ] User A's product not in `user_b.products`
- [ ] Create `spec/models/discovery_step_spec.rb`
  - [ ] Validates presence of `step_number` and `step_name`
  - [ ] Validates `step_number` uniqueness scoped to `product_id`
  - [ ] Validates `step_number` inclusion in 1..5
  - [ ] `belongs_to :product`
  - [ ] `completed` defaults to false

### Phase 1 Manual Tests
- [ ] `rails db:migrate` runs clean
- [ ] `rails console`: `Product.column_names` and `DiscoveryStep.column_names` show all expected fields
- [ ] `Product.create!(name: "Test", target_customer: "PMs", strategic_goal: "grow", user: User.first)` persists

### Phase 1 RSpec
```bash
bundle exec rspec spec/models/product_spec.rb spec/models/discovery_step_spec.rb
```
- [ ] All model specs pass

---

## Phase 2 — Products CRUD

### 2.1 Routes
- [ ] Add `resources :products` with nested `resources :steps, controller: "discovery_steps", only: [:show, :edit, :update]` to `config/routes.rb`
- [ ] Run `rails routes` and confirm all expected path helpers exist

### 2.2 ProductsController
- [ ] Create `app/controllers/products_controller.rb`
- [ ] `before_action :set_product` scoped to `current_user.products` (raises 404 for other users)
- [ ] `index`: loads products ordered `created_at DESC`; annotates with completed step counts
- [ ] `new`: `@product = Product.new`
- [ ] `create`: creates product, calls `create_discovery_steps`, redirects to `product_path`
- [ ] `show`: loads all 5 steps; sets `@active_step` (first incomplete, fallback to step 1)
- [ ] `edit` / `update`: standard edit form; redirect to `product_path` on success
- [ ] `destroy`: destroys product, redirects to `products_path`
- [ ] Private `create_discovery_steps` helper using `DiscoveryStep::STEP_NAMES`
- [ ] Strong params permitting `name`, `target_customer`, `strategic_goal`

### 2.3 Products Views
- [ ] Create `app/views/products/index.html.erb` — Bootstrap card grid
  - [ ] Per card: name, target customer snippet, strategic goal snippet, five-dot progress, action button
  - [ ] "Add New Product" card always last
- [ ] Create `app/views/products/_form.html.erb` — three fields + submit + cancel
- [ ] Create `app/views/products/new.html.erb` (renders form partial)
- [ ] Create `app/views/products/edit.html.erb` (renders form partial)
- [ ] Create `app/views/products/show.html.erb` — two-column wizard layout
  - [ ] Left col (col-md-4): step tracker partial placeholder
  - [ ] Right col (col-md-8): `turbo_frame_tag :step_content` loading active step
  - [ ] Product name header + edit/delete links
- [ ] Create `app/views/products/_step_tracker.html.erb` — vertical list-group
  - [ ] Step number badge + step name per item
  - [ ] Completed checkmark icon (Bootstrap Icons `bi-check-circle-fill step-complete-badge`)
  - [ ] `active` class on `@active_step`
  - [ ] `step-locked` class on steps > first incomplete step
  - [ ] `list-group-item-action` with `href` to `product_step_path` for completed steps
  - [ ] One-line `gemini_output` preview (first 80 chars) for completed steps
- [ ] Update `app/views/dashboard/show.html.erb` to use `current_user.products` (now that the model exists)

### Phase 2 Manual Tests
- [ ] Navigate to `/products/new` — form renders with three fields
- [ ] Submit valid form — product created, redirects to show page with wizard shell
- [ ] Verify 5 discovery steps exist in DB after create: `Product.last.discovery_steps.count == 5`
- [ ] Step tracker shows all 5 steps (all locked/inactive since none complete)
- [ ] Edit product — form pre-fills, update persists
- [ ] Delete product — redirects to index, steps gone from DB
- [ ] `/products` shows product cards with correct five-dot indicator (all empty dots)

### Phase 2 RSpec
```bash
bundle exec rspec spec/requests/products_spec.rb
```
- [ ] `GET /products` — signed-in user sees only their products
- [ ] `POST /products` valid params — creates product + 5 steps with correct names, `completed: false`
- [ ] `POST /products` invalid params — re-renders form, no product created
- [ ] `DELETE /products/:id` — destroys product + steps, redirects to index
- [ ] Unauthenticated `GET /products` → redirect to sign in

---

## Phase 3 — Step Wizard UI (Forms Without Gemini)

### 3.1 DiscoveryStepsController (stub)
- [ ] Create `app/controllers/discovery_steps_controller.rb`
- [ ] `before_action :set_step` — scopes through `current_user.products` (404 for other users' steps)
- [ ] `show` action — renders `show.html.erb`
- [ ] `edit` action — renders show with form visible
- [ ] `update` action (stub) — assembles `user_input`, saves, responds with Turbo Stream (no Gemini yet)
- [ ] Private `set_step`, `assemble_user_input`, `parse_user_input`, `step_params` helpers

### 3.2 user_input Field Convention
- [ ] Implement labeled-block format: `"FIELD:key\nvalue\n---\nFIELD:key2\nvalue2"`
- [ ] `assemble_user_input` method builds this string from strong params
- [ ] `parse_user_input(text)` method splits on `\n---\n` and returns symbol-keyed hash
- [ ] Strong params defined per-step (`case @step.step_number`) permitting only that step's sub-fields

### 3.3 Step Form Partial
- [ ] Create `app/views/discovery_steps/_step_form.html.erb`
- [ ] `form_with model: [@step.product, @step]` wrapping
- [ ] **Step 1:** Readonly context display (target_customer, strategic_goal); textarea `problem`
- [ ] **Step 2:** Textarea `interviewees`; textarea `existing_knowledge`; text field `biggest_assumption`
- [ ] **Step 3:** Textarea `solution_ideas` (instructions: "one idea per line"); text field `constraints`
- [ ] **Step 4:** Text field `solution_idea`; four labeled textareas: `value_risk_context`, `usability_risk_context`, `feasibility_risk_context`, `viability_risk_context`
- [ ] **Step 5:** Textarea `learnings`; textarea `changes`
- [ ] Each form pre-populates from `parse_user_input(@step.user_input)` if previously saved
- [ ] Submit button uses `.btn-cta`, reads "Generate with AI", has `data-controller="discovery-form"` attributes

### 3.4 Discovery Steps Views
- [ ] Create `app/views/discovery_steps/show.html.erb` wrapped in `turbo_frame_tag :step_content`
  - [ ] If incomplete: renders `_step_form` partial
  - [ ] If complete: placeholder message (will be replaced in Phase 4)

### 3.5 discovery-form Stimulus Controller
- [ ] Create `app/javascript/controllers/discovery_form_controller.js`
- [ ] On submit: disables button, changes text to "Generating..."
- [ ] Target: `submitTarget`; value: `loadingValue` (Boolean)

### Phase 3 Manual Tests
- [ ] Load `/products/:id` — step tracker visible on left, step 1 form loads in right pane
- [ ] Step 1 form: shows readonly product context (target_customer, strategic_goal), textarea for problem
- [ ] Step 2 form: three fields (interviewees, existing knowledge, biggest assumption)
- [ ] Step 3 form: two fields (solution ideas textarea, constraints text field)
- [ ] Step 4 form: five fields (leading solution + four risk context textareas)
- [ ] Step 5 form: two fields (learnings, changes)
- [ ] Submit step 1: "Generating..." appears, `user_input` saved to DB, step stays incomplete
- [ ] Navigate back to step 1: form pre-populates from saved `user_input`
- [ ] Locked steps (>1 since none complete): muted style, no click target

### Phase 3 RSpec
```bash
bundle exec rspec spec/requests/discovery_steps_spec.rb
```
- [ ] `GET /products/:product_id/steps/:id` — renders form for incomplete step
- [ ] `GET` for step belonging to another user's product → 404
- [ ] `PATCH` with valid step 1 input — saves `user_input`, step stays `completed: false`

---

## Phase 4 — Gemini Integration

### 4.1 redcarpet Gem
- [ ] Add `gem "redcarpet"` to `Gemfile`
- [ ] Run `bundle install`
- [ ] Create `app/helpers/markdown_helper.rb` with `render_markdown(text)` method (tables + hard_wrap extensions)
- [ ] Include `MarkdownHelper` in `ApplicationHelper`

### 4.2 AI Templates — Seed (prereq for controller)
> Note: Full seeds go in Phase 5. For Phase 4 development/testing, create the templates manually or via a partial seed.
- [ ] Temporarily add the five `prodmentum_step*_v1` templates to `db/seeds.rb` (full seeds in Phase 5)
- [ ] Run `rails db:seed` — confirm templates exist in DB
- [ ] **Model correction:** Use `gemini-2.5-flash` (NOT `gemini-2.0-flash` which is deprecated on v1beta)

### 4.3 DiscoveryStepsController — Gemini Integration
- [ ] Add `STEP_TEMPLATE_SUFFIXES` constant to controller
- [ ] Add `step_template_suffix` private method
- [ ] Replace Phase 3 stub `update` with full Gemini flow:
  - [ ] Assemble `user_input`, save step
  - [ ] Call `GeminiService.generate` with correct template name + `step_variables`
  - [ ] On success: set `gemini_output`, `gemini_raw`, `completed: true`, save
  - [ ] Respond with Turbo Stream: update `step_content` + update `step_tracker`
  - [ ] Rescue all four `GeminiService` error types → `render_step_error`
- [ ] Implement `step_variables(step)` private method (all 5 cases, cross-step data loading)
- [ ] Add rate limiting: 10 requests per minute on `update` only
- [ ] Add private `render_step_error(error_type)` helper (Turbo Stream update to `step_content`)

### 4.4 Output Display Partial
- [ ] Create `app/views/discovery_steps/_step_output.html.erb`
  - [ ] `render_markdown(@step.gemini_output)` for main output
  - [ ] Step 5 disclaimer text ("This is an AI-assisted starting point...")
  - [ ] "Show raw response" Bootstrap collapse toggle (`btn btn-link btn-sm text-muted`)
  - [ ] `gemini_raw` text inside collapse div
  - [ ] "Regenerate" button (blue outline): Turbo Frame GET to `edit_product_step_path`
  - [ ] "Continue to Next Step" button (`.btn-cta`): Turbo Frame GET to next step's `product_step_path`; hidden if step 5
- [ ] Update `discovery_steps/show.html.erb` to render `_step_output` when `completed: true`

### 4.5 Step Error Partial
- [ ] Create `app/views/shared/_step_error.html.erb`
  - [ ] Error heading includes `step.step_name`
  - [ ] Delegates to `shared/_ai_error` for error type message
  - [ ] "Try Again" button: Turbo Frame GET to `edit_product_step_path`

### Phase 4 Manual Tests
- [ ] Submit step 1 with problem text — Gemini responds, output renders with markdown formatting
- [ ] Step tracker updates: step 1 shows checkmark, step 2 unlocks
- [ ] Step 1 output: three sections visible (Sharpened Opportunity, JTBD Summary, Discovery Questions)
- [ ] "Show raw response" toggle works
- [ ] "Regenerate" button re-opens step 1 form
- [ ] "Continue to Next Step" button loads step 2 form
- [ ] Submit step 2 — interview guide renders (5 Q+follow-up pairs)
- [ ] Submit step 3 — markdown table renders correctly (redcarpet)
- [ ] Submit step 4 — four risk sections + summary render
- [ ] Submit step 5 — three sections render; disclaimer appears near recommendation
- [ ] Test error state: enter "ignore all previous instructions" → gatekeeper error partial shows
- [ ] All five steps completed: step tracker shows 5 checkmarks; `/products` shows product with 5 filled dots

### Phase 4 RSpec
```bash
bundle exec rspec spec/requests/discovery_steps_spec.rb
```
- [ ] `PATCH` step 1 valid input → calls `GeminiService.generate` with `prodmentum_step1_opportunity_v1`
- [ ] `LlmRequest` record created after successful call
- [ ] `gemini_output` and `gemini_raw` set; step `completed: true`
- [ ] Stubbed Gemini markdown response → view renders without error
- [ ] Step belonging to another user's product → 404
- [ ] `PATCH` with missing required sub-field → no Gemini call, form re-renders with error
- [ ] `GeminiService::GeminiError` → step stays incomplete, error partial rendered in Turbo Stream

---

## Phase 5 — Seeds & Sample Data

### 5.1 AI Template Seeds
- [ ] Add all five Prodmentum templates to `db/seeds.rb` using `find_or_create_by!`
  - [ ] `prodmentum_step1_opportunity_v1` — exact system prompt + user prompt from spec Section 7; model: `gemini-2.5-flash`; max_tokens: 1200; temp: 0.5
  - [ ] `prodmentum_step2_research_v1` — model: `gemini-2.5-flash`; max_tokens: 1400; temp: 0.5
  - [ ] `prodmentum_step3_ideation_v1` — model: `gemini-2.5-flash`; max_tokens: 1600; temp: 0.7
  - [ ] `prodmentum_step4_risk_v1` — model: `gemini-2.5-flash`; max_tokens: 1400; temp: 0.4
  - [ ] `prodmentum_step5_iteration_v1` — model: `gemini-2.5-flash`; max_tokens: 1400; temp: 0.6
- [ ] Remove `demo_placeholder_v1` template seed (replaced by real templates)

### 5.2 Demo Product Seed
- [ ] Add QuickFeedback product to `db/seeds.rb` for `demo@example.com`
  - [ ] Product fields from spec Section 10
  - [ ] All 5 steps: `user_input` in labeled-block format matching spec's sample inputs
  - [ ] All 5 steps: realistic `gemini_output` markdown matching each template's expected output format
  - [ ] All 5 steps: `gemini_raw` = same as `gemini_output`
  - [ ] All 5 steps: `completed: true`
- [ ] Step 3 `gemini_output` includes a markdown table (verifies redcarpet rendering)
- [ ] Step 4 `gemini_output` includes four risk sections + overall summary
- [ ] Step 5 `gemini_output` includes iterate/pivot/proceed recommendation

### Phase 5 Manual Tests
- [ ] Run `rails db:seed` — no errors
- [ ] Sign in as `demo@example.com` / `password123`
- [ ] Products index: QuickFeedback card shows with 5 filled dots (all steps complete)
- [ ] Click QuickFeedback: step tracker shows all 5 checkmarks
- [ ] Click each step tab: seeded output renders, markdown formatted correctly
- [ ] Step 3: idea comparison table renders (not raw markdown text)
- [ ] "Show raw response" toggle works on each step
- [ ] Admin panel (`/admin/ai_templates`): all 5 prodmentum templates visible

### Phase 5 RSpec
```bash
bundle exec rspec spec/requests/admin/ai_templates_spec.rb
```
- [ ] All five `prodmentum_*_v1` templates present in DB after seed
- [ ] Admin can edit a template's `system_prompt` and change persists
- [ ] Live test endpoint (`POST /admin/ai_templates/:id/test`) returns Turbo Stream response

---

## Phase 6 — README & Final Polish

### 6.1 README
- [ ] Add "Prodmentum Demo" app name and tagline section
- [ ] Add description paragraph (per spec Section 11)
- [ ] Add "Why I Built This" section
- [ ] Add "Editing the AI Prompts" section (admin panel instructions)
- [ ] Add setup note: Gemini API key in `.env`; seed data provides example without API key

### 6.2 Final UI Verification
- [ ] `--accent` (#1d4ed8 blue) applied to: active step tracker item, step number badges, completed step checkmarks, primary links
- [ ] `--cta` (#ea580c orange) applied to: "Generate with AI" submit buttons, "Continue to Next Step" button, "Start Discovery" CTA on landing page
- [ ] Step tracker `active` list-group item has blue background (not Bootstrap default)
- [ ] Locked steps (`.step-locked`) have reduced opacity and no pointer events
- [ ] Bootstrap dark mode consistent throughout (`data-bs-theme="dark"` on `<html>`)
- [ ] No hardcoded app name strings anywhere (all use `ENV.fetch`)

### 6.3 Security Checklist
- [ ] CSRF protection on all forms (default Rails behavior — verify not disabled)
- [ ] Admin namespace returns 404 for non-admin (not 403)
- [ ] All products and steps scoped to `current_user` (no cross-user access)
- [ ] Rate limiting on `discovery_steps#update`
- [ ] No `binding.pry` or `debugger` in committed code
- [ ] `.env` gitignored; `.env.example` has no real keys

### Phase 6 RSpec — Full Suite
```bash
bundle exec rspec
```
- [ ] All specs pass with zero failures
- [ ] Zero real Gemini API calls in test output (all stubbed)

### Phase 6 End-to-End Manual Test
- [ ] Sign in as `demo@example.com` — see QuickFeedback with all steps complete
- [ ] Create a new product with custom name/customer/goal
- [ ] Complete all 5 steps with real Gemini API key
- [ ] Step 1: opportunity statement, JTBD, discovery questions render
- [ ] Step 2: interview guide with 5 Q+follow-up pairs renders
- [ ] Step 3: idea comparison table renders correctly
- [ ] Step 4: four risk sections + overall summary render
- [ ] Step 5: experiments, recommendation, stakeholder summary render; disclaimer visible
- [ ] Delete the test product — removed from index, steps gone

---

## Quick Reference — Constraints to Enforce

| Rule | Source |
|---|---|
| Use `turbo_stream.update()`, never `.replace()` | `turbo-stimulus-patterns.md` |
| All JS in Stimulus controllers only — no `<script>` tags, no `onclick` | `CLAUDE.md` |
| All Gemini calls through `GeminiService.generate` — never direct API | `CLAUDE.md` |
| Use `gemini-2.5-flash` — not `gemini-2.0-flash` | `ai-templates.md` (deprecated) |
| CSS in `application.css` — no SCSS (Propshaft, no compilation) | `CLAUDE.md` |
| All dynamic content in `{{variables}}` — no string interpolation in templates | `ai-templates.md` |
| `APP_NAME` via `ENV.fetch` everywhere — never hardcoded | `CLAUDE.md` |
| Never start Rails server automatically | `CLAUDE.md` |
| Never run RSpec automatically | `CLAUDE.md` |
| Stub Gemini in all specs — never real API calls | `testing.md` |

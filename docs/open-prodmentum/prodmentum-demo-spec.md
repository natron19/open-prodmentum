# Prodmentum Demo - App Spec

**Built on:** Open Demo Starter v2.0
**Version:** 1.0
**License:** MIT
**Accent Color:** `#1d4ed8` (blue) / CTA buttons: `#ea580c` (orange)
**UX Pattern:** Five-step wizard with vertical progress tracker

---

## 1. App Overview

Prodmentum Demo is a single-user Rails 8 app that walks a product manager through a structured five-step discovery workflow modeled on Marty Cagan's continuous discovery framework. The user creates a Product and advances through five steps: Opportunity Framing, Customer Research Planning, Ideation and Prototyping, Risk Assessment, and Iteration Planning. At each step, the user fills out a short form; Gemini returns targeted, step-specific output tailored to what the user has entered. Steps are saved individually so the user can pause, return to any step, and iterate freely.

The demo showcases one of the core workflows of Prodmentum, a multi-tenant AI-powered product management platform the author is building. In the production version, products are scoped to organizations, teams can collaborate on the same discovery workflow, AI outputs feed into an initiative backlog, and the full OKR hierarchy connects discovery to execution. This demo strips everything except the single most valuable thing: having an AI thinking partner at every step of a structured discovery process.

The problem this solves is real and common. Most PMs skip from idea directly to backlog. Cagan's discovery process exists to de-risk that jump by answering four questions before engineering begins: do users want it, can they figure it out, can we build it, and does it work commercially? Few teams run the process consistently because it requires structure and coaching that most PMs do not have access to. This demo shows how AI can substitute for that coaching at low cost, making structured product discovery accessible to any PM - not just those at well-resourced companies with senior mentors.

This demo is open source under the MIT license, scoped to a single signed-in user, and runs locally with no deployment configuration needed.

---

## 2. Customizations Applied to the Boilerplate

- `APP_NAME` set to `Prodmentum Demo` in `.env.example`
- `APP_TAGLINE` set to `Walk your product idea through a structured discovery process. AI guides you at every step.`
- `APP_DESCRIPTION` set to `An open source Rails 8 demo of AI-assisted product discovery using Cagan's continuous discovery framework.`
- Accent color `#1d4ed8` (blue) set as `--accent` in `app/assets/stylesheets/_accent.scss`; `--accent-hover` set to `#1e40af`; CTA override variable `--cta` set to `#ea580c` (orange) for primary submit buttons
- Navbar links: "My Products" (links to `products#index`) added as the primary authenticated nav item
- `home/index.html.erb` replaced with a landing pitch describing the five-step discovery workflow, a "Start a Product Discovery" CTA button, and a brief explanation of the Cagan framework
- `dashboard/show.html.erb` replaced with a list of the user's Products, a count of completed discovery steps per product, and a "New Product" button
- UX pattern: five-step wizard with a vertical Bootstrap list-group progress tracker on the left and the active step's form on the right
- AI templates seeded into `db/seeds.rb`: `prodmentum_step1_opportunity_v1`, `prodmentum_step2_research_v1`, `prodmentum_step3_ideation_v1`, `prodmentum_step4_risk_v1`, `prodmentum_step5_iteration_v1`

---

## 3. Data Model

### Product

The top-level record the user creates to begin a discovery workflow.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; `belongs_to :user` |
| `name` | string | **(template variable)** for all five steps |
| `target_customer` | string | **(template variable)** for step 1 |
| `strategic_goal` | string | The OKR or strategic objective this product supports; **(template variable)** for step 1 |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :user`; `has_many :discovery_steps, dependent: :destroy`

**Validations:** `name` present, maximum 120 characters; `target_customer` present, maximum 200 characters; `strategic_goal` present, maximum 300 characters

### DiscoveryStep

One record per step per product. Created empty when the product is created (five records, steps 1-5). The user fills in `user_input`, saves, and the controller calls Gemini.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `product_id` | uuid | Foreign key; `belongs_to :product` |
| `step_number` | integer | 1 through 5; unique per product |
| `step_name` | string | Human label (e.g., "Opportunity Framing") |
| `user_input` | text | The user's form submission for this step; **(template variable)** - full content varies by step |
| `gemini_output` | text | The parsed, formatted response displayed to the user |
| `gemini_raw` | text | **(Gemini output, used for Show raw response toggle)** |
| `completed` | boolean | Default false; set to true when Gemini output is saved |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:** `belongs_to :product`; `has_one :user, through: :product`

**Validations:** `step_number` present, inclusion in 1..5; `step_number` unique scoped to `product_id`; `step_name` present

**Step-specific `user_input` fields:** Each step collects different inputs. The `user_input` column stores a plain text blob that the controller assembles from the step's sub-fields before calling Gemini. The step form renders appropriate labeled inputs depending on `step_number` (handled in a partial). Sub-fields are assembled into `user_input` on save and are also used as individual template variables via a helper that parses `user_input` back into named keys.

---

## 4. Routes

| HTTP Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/products` | `products#index` | List user's products (same as dashboard) |
| GET | `/products/new` | `products#new` | Form to create a new product |
| POST | `/products` | `products#create` | Create product and seed five blank discovery steps |
| GET | `/products/:id` | `products#show` | Show product with vertical step wizard |
| GET | `/products/:id/edit` | `products#edit` | Edit product metadata |
| PATCH | `/products/:id` | `products#update` | Update product metadata |
| DELETE | `/products/:id` | `products#destroy` | Delete product and all steps |
| GET | `/products/:product_id/steps/:id` | `discovery_steps#show` | Show a single step's output (Turbo Frame target) |
| GET | `/products/:product_id/steps/:id/edit` | `discovery_steps#edit` | Form for a single step (Turbo Frame target) |
| PATCH | `/products/:product_id/steps/:id` | `discovery_steps#update` | Save step input, call Gemini, store output |

---

## 5. Controllers and Actions

### `ProductsController`

Inherits from `ApplicationController`. Scopes all queries to `current_user.products`.

- **`index`:** Retrieves all products for `current_user`, ordered by `created_at DESC`. Each product is annotated with a count of completed steps for display in the dashboard card.
- **`new`:** Instantiates a blank `Product` for the form.
- **`create`:** Creates the `Product` and immediately creates five `DiscoveryStep` records (step_number 1-5, completed: false). Redirects to `products#show`.
- **`show`:** Loads the product and all five steps ordered by `step_number`. Determines the current active step (first incomplete step, defaulting to step 1 if all complete). Sets `@active_step` for the view.
- **`edit` / `update`:** Standard edit form for product name, target_customer, and strategic_goal. On update, redirects to `products#show`.
- **`destroy`:** Deletes the product and all associated steps. Redirects to `products#index`.

### `DiscoveryStepsController`

Inherits from `ApplicationController`. Scopes through `current_user.products` to prevent cross-user access.

- **`show`:** Loads the step and renders its current state (input form if incomplete, output display if complete). Used as a Turbo Frame target so individual steps can refresh without a full page reload.
- **`edit`:** Loads the step and renders the input form partial for that step number.
- **`update`:** Assembles `user_input` from strong-params sub-fields for the given step. Calls `GeminiService.generate(template: "prodmentum_step#{step.step_number}_..._v1", variables: step_variables(step))` where `step_variables` returns a hash of named inputs for the template. On success, sets `gemini_output` to the formatted response, sets `gemini_raw`, marks `completed: true`, saves, and responds with a Turbo Stream that updates the step panel and re-renders the progress tracker. On `GeminiService::GeminiError`, renders the boilerplate's inline error partial within the step's Turbo Frame.

---

## 6. Views

### `products/index.html.erb`

Renders a card grid of the user's products (Bootstrap cards, two columns on medium screens). Each card shows the product name, target customer, strategic goal, a mini five-dot step progress indicator (filled dots for completed steps), and a "Continue Discovery" or "Start Discovery" button. An "Add New Product" card is always the last item in the grid.

### `products/new.html.erb` and `products/edit.html.erb`

Simple form with three fields: product name, target customer, and strategic goal. Blue primary button for submit. Cancel link returns to `products#index` or `products#show`.

### `products/show.html.erb`

The main wizard view. Two-column Bootstrap layout: left column (one-third width on medium screens) shows the vertical step progress tracker; right column (two-thirds) shows the active step content in a Turbo Frame.

The left column renders `products/_step_tracker.html.erb`. Each of the five steps is rendered as a list-group item with: a step number badge, the step name, a completed checkmark (if `completed: true`), and a collapsed one-line summary of the Gemini output for completed steps. Clicking a completed step re-opens it in the right column via a Turbo Frame GET to `discovery_steps#show`. Future steps (step number greater than the first incomplete step) are displayed but locked with a muted style and no click target.

The right column is a single Turbo Frame (`turbo_frame_tag :step_content`) that loads the active step via `discovery_steps#show`.

### `discovery_steps/show.html.erb`

Conditionally renders two layouts:

- **If `completed: false` (or first visit):** Renders `discovery_steps/_step_form.html.erb` for the current step number.
- **If `completed: true`:** Renders the step's formatted `gemini_output` using `simple_format` or a structured partial depending on the step. Below the output, renders a "Show raw response" Bootstrap collapse toggle that reveals `gemini_raw`. A "Regenerate" button re-opens the form partial (via Turbo Frame GET to `discovery_steps#edit`) so the user can revise inputs and re-run Gemini. A "Continue to Next Step" button (orange CTA, `var(--cta)`) expands the next step in the tracker.

### `discovery_steps/_step_form.html.erb`

A partial that branches on `@step.step_number` to render the appropriate labeled inputs:

- **Step 1:** Textarea for problem being solved (pre-populated from product's target_customer and strategic_goal as readonly display, not editable here).
- **Step 2:** Textarea for who to interview, text area for what they already know, text field for biggest assumption.
- **Step 3:** Textarea for 2-3 rough solution ideas (one per line), text field for constraints.
- **Step 4:** Text field for leading solution idea, textarea for one sentence of context per risk area (four labeled textareas: value risk, usability risk, feasibility risk, business viability risk).
- **Step 5:** Textarea for what they learned, textarea for what they want to change.

Each form submits via `PATCH` to `discovery_steps#update`. The submit button uses the orange CTA color and reads "Generate with AI" with a Stimulus-powered loading spinner on submit (Stimulus controller: `discovery-form` with a `loadingValue` boolean that swaps button text to "Generating..." and disables the button on submit).

### `products/_step_tracker.html.erb`

Bootstrap list-group vertical nav. Each item is an anchor tag pointing to a Turbo Frame GET. Completed steps have a `bi-check-circle-fill` Bootstrap icon in blue. The active step has an `active` list-group class. Locked steps have `disabled` muted styling and no href.

### `shared/_step_error.html.erb`

Extends the boilerplate's error partial to include the step name in the error heading ("AI generation failed on Opportunity Framing"). Provides a retry button that re-renders `discovery_steps#edit` within the Turbo Frame.

---

## 7. AI Templates and Gemini Integration

### Template 1: `prodmentum_step1_opportunity_v1`

**Description:** Sharpens a product opportunity statement, extracts jobs-to-be-done, and surfaces discovery questions for step 1 of the Prodmentum discovery workflow.

**System Prompt:**
```
You are an experienced product coach who specializes in Marty Cagan's continuous discovery framework.
Your role is to help product managers think more clearly about the opportunity they are exploring.
You write with precision and directness. You do not use buzzwords or filler.
You always output in clean, structured markdown using headers and bullet points.
You do not editorialize beyond what the user has given you. If the inputs are thin, you still produce useful output and note where the PM needs to do more thinking.
```

**User Prompt Template:**
```
A product manager is beginning a product discovery on the following:

Product Name: {{product_name}}
Target Customer: {{target_customer}}
Strategic Goal (OKR): {{strategic_goal}}
Problem Being Solved: {{problem}}

Please return the following in clean markdown:

## Sharpened Opportunity Statement
Write one or two sentences that clearly state: who has the problem, what the problem is, and why solving it matters for the stated strategic goal. Be specific. Remove vague language.

## Jobs to Be Done Summary
Identify the primary functional job, emotional job, and social job this product addresses for the target customer. Use the JTBD format: "When [situation], I want to [motivation], so I can [expected outcome]."

## Discovery Questions
List 2 to 3 questions the team should be able to answer before committing to this opportunity. These are not interview questions - they are strategic questions about whether the opportunity is real and worth pursuing. Frame each question as a one-sentence hypothesis the team needs to validate or invalidate.
```

**Variables consumed:**
- `{{product_name}}` - `Product#name`
- `{{target_customer}}` - `Product#target_customer`
- `{{strategic_goal}}` - `Product#strategic_goal`
- `{{problem}}` - `DiscoveryStep#user_input` (step 1: problem being solved)

**Model:** `gemini-2.0-flash`
**Max output tokens:** 1200
**Temperature:** 0.5

**Notes:** Lower temperature produces more structured, actionable output. The main failure mode is the model being too vague on the opportunity statement when inputs are thin - the system prompt explicitly addresses this. Watch for the JTBD format being ignored; if the model produces prose instead of the three-part format, reduce temperature further or make the format directive more explicit. The discovery questions are the most useful output; if they become generic ("Is there a market for this?"), add a few negative examples to the system prompt.

**Called from:** `DiscoveryStepsController#update` when `step.step_number == 1`

**Expected output format:** Markdown with three sections. No JSON.

**How parsed:** `gemini_raw` stores the full text response. `gemini_output` stores the same text (no additional parsing needed; `simple_format` renders it in the view). The "Show raw response" toggle reveals `gemini_raw` directly.

---

### Template 2: `prodmentum_step2_research_v1`

**Description:** Generates a five-question discovery interview guide and flags commonly missed research pitfalls for step 2 of the discovery workflow.

**System Prompt:**
```
You are a UX research coach who helps product managers design customer discovery interviews.
You apply Teresa Torres's continuous discovery framework and Steve Portigal's interviewing principles.
You write with clarity and precision. You do not pad responses.
You output in clean structured markdown.
You know that most PMs ask about solutions instead of exploring problems, and you design questions that avoid this mistake.
```

**User Prompt Template:**
```
A product manager is planning customer research for the following opportunity:

Product Name: {{product_name}}
Problem Being Solved: {{problem}}
Who They Plan to Interview: {{interviewees}}
What They Already Know About These Users: {{existing_knowledge}}
Their Biggest Assumption: {{biggest_assumption}}

Please return the following in clean markdown:

## Discovery Interview Guide
Write a five-question interview guide. Each question must:
- Explore behavior and context, not opinions about solutions
- Use open-ended phrasing
- Build progressively (context first, specifics later)
- Include one follow-up probe after each question

Format each question as:
**Q[number]: [question text]**
Follow-up: [probe text]

## What PMs Commonly Miss
List exactly 2 things to watch for when conducting research on this type of problem - things that PMs who have done this before know to look for, but first-timers typically overlook. Be specific to this opportunity, not generic research advice.
```

**Variables consumed:**
- `{{product_name}}` - `Product#name`
- `{{problem}}` - `DiscoveryStep#user_input` from step 1 (carried forward from step 1's saved `user_input`)
- `{{interviewees}}` - parsed from step 2's `user_input` (who to interview sub-field)
- `{{existing_knowledge}}` - parsed from step 2's `user_input` (existing knowledge sub-field)
- `{{biggest_assumption}}` - parsed from step 2's `user_input` (biggest assumption sub-field)

**Model:** `gemini-2.0-flash`
**Max output tokens:** 1400
**Temperature:** 0.5

**Notes:** The controller assembles prior step inputs (step 1 problem) into this template's variables, not just the current step's input. This is intentional - each step builds on prior context. The most common failure mode is generic interview questions. The system prompt addresses this explicitly; if it still happens, add two or three example bad questions and why they fail. The "commonly missed" section is high-value but often becomes generic advice ("make sure to listen"); tighten the user prompt if needed.

**Called from:** `DiscoveryStepsController#update` when `step.step_number == 2`

**Expected output format:** Markdown with two sections.

**How parsed:** Stored and displayed as markdown text. No JSON. `gemini_raw` and `gemini_output` store the same content.

---

### Template 3: `prodmentum_step3_ideation_v1`

**Description:** Compares solution ideas across effort and user value, generates a wildcard idea, and suggests the fastest prototype test for each idea for step 3.

**System Prompt:**
```
You are a product design coach with deep experience in lean experimentation and rapid prototyping.
You draw on the IDEO design thinking process and the Lean Startup validated learning loop.
You are practical and opinionated. When you suggest prototype approaches, you name the specific type: concierge test, clickable prototype, fake door test, Wizard of Oz, paper prototype, landing page experiment, or smoke test.
You do not recommend overbuilding. Your first suggestion is always the fastest way to learn.
You write in clean structured markdown.
```

**User Prompt Template:**
```
A product manager is evaluating solution ideas for:

Product Name: {{product_name}}
Opportunity: {{problem}}
Their Solution Ideas: {{solution_ideas}}
Constraints (time, tech, team size): {{constraints}}

Please return the following in clean markdown:

## Idea Comparison
For each idea the PM listed, provide a one-row summary in a markdown table with these columns: Idea Name | Estimated Effort (Low/Medium/High) | Estimated User Value (Low/Medium/High) | Key Assumption to Test | Risk if Wrong

## Wildcard Idea
Suggest one idea the PM probably has not considered. It should be meaningfully different from their list - not a variation. Briefly explain why it is worth considering and what assumption it would test fastest.

## Fastest Prototype Approach
For each of the PM's ideas (not the wildcard), recommend the fastest prototype type to test the key assumption. Name the prototype type, explain it in one sentence, and describe what a successful outcome would look like in concrete terms.
```

**Variables consumed:**
- `{{product_name}}` - `Product#name`
- `{{problem}}` - `DiscoveryStep#user_input` from step 1
- `{{solution_ideas}}` - parsed from step 3's `user_input` (2-3 rough ideas sub-field)
- `{{constraints}}` - parsed from step 3's `user_input` (constraints sub-field)

**Model:** `gemini-2.0-flash`
**Max output tokens:** 1600
**Temperature:** 0.7

**Notes:** Higher temperature is justified here - ideation benefits from more variance. The wildcard idea is the highest-value output; if it becomes obvious, increase temperature to 0.8. The markdown table for idea comparison sometimes breaks in `simple_format`; render this section using `raw(redcarpet_render(step.gemini_output))` or a minimal markdown renderer rather than `simple_format`. Known failure mode: the model suggests "build an MVP" as a prototype instead of naming a specific lean test type. The system prompt lists exact prototype names; if this fails, move the list into the user prompt as an explicit constraint.

**Called from:** `DiscoveryStepsController#update` when `step.step_number == 3`

**Expected output format:** Markdown with a table and two prose sections.

**How parsed:** Rendered using a markdown renderer (add `redcarpet` gem) to preserve table formatting. `gemini_raw` stores the full text; `gemini_output` stores the same. The table renders best with `redcarpet` + `tables` extension enabled.

---

### Template 4: `prodmentum_step4_risk_v1`

**Description:** Generates a structured four-risk scorecard (Value, Usability, Feasibility, Business Viability) with ratings and mitigations for step 4.

**System Prompt:**
```
You are a product risk coach who uses Marty Cagan's four product risks framework: Value Risk, Usability Risk, Feasibility Risk, and Business Viability Risk.
You are direct and specific. You do not soften ratings to make them more palatable.
You give each risk a clear Low, Medium, or High rating with a concrete one-sentence rationale.
You suggest specific, actionable mitigations - not generic advice.
You write in clean structured markdown.
```

**User Prompt Template:**
```
A product manager is assessing risk on their leading solution idea:

Product Name: {{product_name}}
Opportunity: {{problem}}
Leading Solution Idea: {{solution_idea}}

Risk Context the PM Provided:
- Value Risk context (will users want it?): {{value_risk_context}}
- Usability Risk context (can users figure it out?): {{usability_risk_context}}
- Feasibility Risk context (can the team build it?): {{feasibility_risk_context}}
- Business Viability Risk context (does it work commercially?): {{viability_risk_context}}

Please return a risk scorecard in the following format for each of the four risks:

## [Risk Name]
**Rating:** Low / Medium / High
**Rationale:** One sentence explaining the rating based on the PM's context and the nature of this type of problem.
**Suggested Mitigation:** One specific, actionable experiment or check the PM can run to reduce this risk before committing to engineering.

After the four risk sections, add:

## Overall Risk Summary
Two to three sentences summarizing the overall risk profile and the highest-priority risk to address first.
```

**Variables consumed:**
- `{{product_name}}` - `Product#name`
- `{{problem}}` - `DiscoveryStep#user_input` from step 1
- `{{solution_idea}}` - parsed from step 4's `user_input` (leading solution idea sub-field)
- `{{value_risk_context}}` - parsed from step 4's `user_input` (value risk context sub-field)
- `{{usability_risk_context}}` - parsed from step 4's `user_input` (usability risk context sub-field)
- `{{feasibility_risk_context}}` - parsed from step 4's `user_input` (feasibility risk context sub-field)
- `{{viability_risk_context}}` - parsed from step 4's `user_input` (business viability risk context sub-field)

**Model:** `gemini-2.0-flash`
**Max output tokens:** 1400
**Temperature:** 0.4

**Notes:** Low temperature is intentional - risk assessment should be structured and consistent, not creative. The most common failure mode is the model giving all Medium ratings to avoid being wrong; the system prompt directly addresses this. The mitigation suggestions are the highest-value output; if they become generic, add a constraint to the user prompt: "The mitigation must be something the PM can do in under one week with no engineering resources." Watch for the model inventing risk context the PM did not provide - the system prompt uses only what is given.

**Called from:** `DiscoveryStepsController#update` when `step.step_number == 4`

**Expected output format:** Markdown with five sections (four risks + summary).

**How parsed:** Rendered using the same markdown renderer as step 3. `gemini_raw` and `gemini_output` store the same content.

---

### Template 5: `prodmentum_step5_iteration_v1`

**Description:** Produces a prioritized experiment list, an iterate/pivot/proceed recommendation, and a stakeholder-ready discovery summary for step 5.

**System Prompt:**
```
You are a senior product coach who helps PMs synthesize what they have learned in discovery and decide what to do next.
You use the language of lean experimentation: iterate, pivot, or proceed to engineering.
Your recommendations are grounded in what the PM has actually learned, not what you think they should have learned.
You write the stakeholder summary in clear, jargon-free language that an executive who was not in the room can understand in 60 seconds.
You write in clean structured markdown.
```

**User Prompt Template:**
```
A product manager is completing their discovery cycle on:

Product Name: {{product_name}}
Opportunity: {{problem}}
Leading Solution: {{solution_idea}}

What They Learned from Research or Prototyping: {{learnings}}
What They Want to Change Based on What They Learned: {{changes}}

Please return the following in clean markdown:

## Next Experiments (Prioritized)
List 3 to 5 specific experiments the PM should run next, ordered from highest to lowest priority. For each:
- **Experiment:** What to test
- **Method:** How to test it (name a specific method)
- **Success Criterion:** What outcome would move them forward with confidence

## Recommendation
State clearly: **Iterate**, **Pivot**, or **Proceed to Engineering**.
Explain why in 2 to 3 sentences based on what the PM has shared. If the data is insufficient to make this call, say so directly and name what additional evidence is needed.

## Discovery Summary for Stakeholders
Write a single paragraph (4 to 6 sentences) suitable for sharing with a VP or executive. Cover: what opportunity was explored, who the customer is, what was tested, what was learned, and what happens next. Write it as a memo paragraph, not a list.
```

**Variables consumed:**
- `{{product_name}}` - `Product#name`
- `{{problem}}` - `DiscoveryStep#user_input` from step 1
- `{{solution_idea}}` - `DiscoveryStep#user_input` from step 4 (leading solution sub-field)
- `{{learnings}}` - parsed from step 5's `user_input` (learnings sub-field)
- `{{changes}}` - parsed from step 5's `user_input` (changes sub-field)

**Model:** `gemini-2.0-flash`
**Max output tokens:** 1400
**Temperature:** 0.6

**Notes:** The stakeholder summary is the highest-value output - PMs frequently copy it directly into status updates. If the model writes it as a bullet list instead of a paragraph, add "Do not use bullet points in this section" to the user prompt. The iterate/pivot/proceed recommendation is intentionally opinionated; if the PM's inputs are thin, the model sometimes hedges with "it depends" - the prompt explicitly addresses this by requiring a direct choice or an explicit acknowledgment of missing evidence. Watch for the model pulling in prior steps' content inaccurately; only step 1 problem and step 4 solution are carried forward.

**Called from:** `DiscoveryStepsController#update` when `step.step_number == 5`

**Expected output format:** Markdown with three sections.

**How parsed:** Rendered using the markdown renderer. `gemini_raw` and `gemini_output` store the same content.

---

## 8. AI Safety Considerations (Specific to This App)

**Content sensitivity.** This app deals with business strategy and product decisions, not personal or health-related topics. The domain is low-sensitivity compared to mental health, legal, or financial advice demos.

**Consequential outputs.** The highest-stakes output is the iterate/pivot/proceed recommendation in step 5. A PM acting on a "proceed to engineering" recommendation without sufficient evidence could direct real engineering time toward an unvalidated idea. However, this risk exists with or without AI - PMs make these judgment calls daily. The demo's risk is no greater than asking a colleague's opinion. The "Discovery Questions" in step 1 and the "Risk Scorecard" in step 4 actively work to surface uncertainty rather than paper over it.

**Domain accuracy.** The Cagan framework is well-understood and the prompts align closely with published INSPIRED and EMPOWERED methodology. There is no domain where Gemini would produce factually incorrect framework content with consequential results. The output is advisory, not authoritative.

**App-specific disclaimers.** The boilerplate footer disclaimer ("AI-generated content can be incorrect. Verify before acting.") is sufficient. On the step 5 output page, add one sentence of inline copy near the iterate/pivot/proceed recommendation: "This is an AI-assisted starting point. Your discovery data and judgment should drive the final call."

**Tightened settings.** No tightening needed beyond what the boilerplate provides. The default 50-call/day budget is appropriate. Steps 1-5 together represent five calls, so a user exploring ten products in a day reaches the limit only if they are heavily iterating - which is good product behavior, not abuse.

**What this demo deliberately does not do:**
- Does not claim to replace customer research. Step 2 generates an interview guide; it does not conduct interviews.
- Does not connect discovery outputs to engineering tickets or a real backlog. The full Prodmentum suite does this; the demo stops at the discovery summary.
- Does not store or analyze real customer interview data. All inputs are the PM's own notes and assumptions.

This is a low-stakes demo. The AI acts as a structured thinking partner, not an autonomous decision-maker. The PM retains all judgment and decision authority.

---

## 9. RSpec Outline

### `spec/models/product_spec.rb`

1. Validates presence of `name`, `target_customer`, `strategic_goal`
2. Validates `name` maximum length of 120 characters
3. `belongs_to :user` association
4. `has_many :discovery_steps, dependent: :destroy` - destroying a product destroys its steps
5. A product owned by user A is not visible via `user_b.products`

### `spec/models/discovery_step_spec.rb`

1. Validates presence of `step_number` and `step_name`
2. Validates `step_number` is unique scoped to `product_id`
3. Validates `step_number` inclusion in 1..5
4. `belongs_to :product` association
5. `completed` defaults to false

### `spec/requests/products_spec.rb`

1. `GET /products` - signed-in user sees only their products; another user's products are not in the response
2. `POST /products` with valid params - creates product and five DiscoveryStep records with correct step names and `completed: false`
3. `POST /products` with invalid params - re-renders new form, no product created
4. `DELETE /products/:id` - destroys product and associated steps; redirects to index
5. Unauthenticated `GET /products` redirects to sign in

### `spec/requests/discovery_steps_spec.rb`

1. `PATCH /products/:product_id/steps/:id` with valid step 1 inputs - calls `GeminiService.generate` with template `prodmentum_step1_opportunity_v1`; creates an `LlmRequest` record; sets `gemini_output` and `gemini_raw`; marks step as `completed: true`
2. Stubbed Gemini returns the expected formatted markdown; view renders without error
3. A step belonging to another user's product returns 404 (not 403)
4. `PATCH` with missing required sub-field input - does not call Gemini; re-renders the step form with an error message
5. When `GeminiService::GeminiError` is raised, the step remains incomplete and the inline error partial is rendered

### `spec/requests/admin/ai_templates_spec.rb` (inherited, verify five new templates)

1. All five `prodmentum_*_v1` templates are present after seeding
2. Admin can edit a template's `system_prompt` and the change persists
3. The live test endpoint calls Gemini with the draft template and returns a Turbo Stream response

---

## 10. Seed Data

### AiTemplate Seeds

`db/seeds.rb` creates all five templates described in Section 7 using `AiTemplate.find_or_create_by!(name: ...)`. The full `system_prompt`, `user_prompt_template`, `model`, `max_output_tokens`, `temperature`, and `notes` values match Section 7 exactly.

### Domain Seeds

`db/seeds.rb` creates one sample product for the seeded demo user, with all five steps populated with realistic inputs and saved Gemini outputs. This ensures the app looks finished and meaningful on first sign-in.

**Sample Product:**

```
name: "QuickFeedback"
target_customer: "B2B SaaS product managers at companies with 10 to 200 employees"
strategic_goal: "Increase feature adoption by 25% in Q3 by improving feedback loops between customers and product teams"
```

**Sample Step Inputs:**

- Step 1 - problem: "PMs have no lightweight way to collect targeted feature feedback from specific customer segments. Current tools are either too heavy (Typeform, Pendo) or too noisy (generic NPS). PMs end up guessing what features to prioritize."
- Step 2 - interviewees: "5 product managers at mid-size B2B SaaS companies who currently use NPS or ad-hoc Slack messages for feedback"; existing_knowledge: "We know they run quarterly NPS surveys but distrust the data. Most are using Notion or Confluence to manually collect and tag feedback."; biggest_assumption: "PMs would use a targeted micro-survey tool if it integrated with their existing ticketing system."
- Step 3 - solution_ideas: "1. In-app widget that triggers after specific feature usage events\n2. Slack bot that collects feedback in the channel where the PM already works\n3. Weekly digest email sent to a curated list of power users asking 1 question"; constraints: "2 engineers, 6 week timeline, must integrate with Jira"
- Step 4 - solution_idea: "In-app widget triggered after specific feature usage events"; risk contexts seeded with one sentence each per risk area
- Step 5 - learnings: "Interviewed 4 PMs. All 4 said they would use a trigger-based widget. 3 of 4 said Jira integration is a must-have, not a nice-to-have. 1 said they are already building something internal and would prefer to buy if the price is right."; changes: "Narrow the MVP to Jira integration only. Remove the Slack bot and email digest from v1. Add a pricing page to the landing page as a fake door test."

**Sample Gemini outputs** are seeded as realistic formatted markdown strings on each step, matching what the templates would plausibly produce for the given inputs. This gives a first-time visitor a complete walkthrough without needing an API key.

---

## 11. README Additions

### App Name and Tagline

**Prodmentum Demo** - Walk your product idea through a structured discovery process. AI guides you at every step.

### Description

Prodmentum Demo is an open source Rails 8 app that pairs a five-step product discovery workflow with Google Gemini. At each step of the discovery process - from framing the opportunity to assessing risk - the app collects your inputs and returns targeted, structured AI output designed to help you think more clearly, not think for you.

The workflow is based on Marty Cagan's continuous discovery framework as described in INSPIRED and EMPOWERED. It covers the four questions every product team should answer before engineering begins: does the customer want it, can they use it, can we build it, and does it work commercially?

[Screenshot placeholder - five-step wizard view with vertical tracker and risk scorecard output]

### Why I Built This

I built this as a demo of one feature from Prodmentum, a multi-tenant AI-powered product management platform I am building for product teams. The full version connects discovery to execution - from strategic themes through OKRs down to tasks and retrospectives. You can check out the production version at [prodmentum.com].

Most of the PMs I have talked to skip structured discovery because it feels heavyweight. They write a brief, add it to Jira, and start building. Cagan's framework is the right antidote, but it is hard to do alone. This demo shows what it looks like when AI plays the role of the experienced colleague who asks the questions you should have asked yourself.

This demo is open source under the MIT license. Clone it, run it, tune the prompts to your framework of choice.

### Editing the AI Prompts

Every prompt in this app is stored as an editable template, not hardcoded. After running `bin/setup`, sign in as `demo@example.com` (password: `password123`) and navigate to `/admin/ai_templates`. You can edit any of the five discovery prompts and test them live from the admin UI without restarting the server. Prompt iteration notes are stored in the `notes` field on each template.

### Setup Note

No additional setup beyond `bin/setup` is required. You need a Google Gemini API key (free tier works for typical use). Add it to your `.env` file as `GEMINI_API_KEY`. The seed data includes a complete pre-filled product example so you can see what the output looks like before entering your own inputs.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### UX Pattern

Five-step wizard with a vertical Bootstrap list-group nav on the left and a Turbo Frame content pane on the right. This avoids full page reloads when switching between steps and makes the progress state visually prominent throughout the workflow.

### Accent Color Application

- `var(--accent)` (`#1d4ed8`, blue): Applied to the active list-group item in the step tracker, all primary link colors, and the step number badges on completed steps.
- `var(--cta)` (`#ea580c`, orange): Applied to the "Generate with AI" submit button on each step form, the "Continue to Next Step" button after viewing output, and the "Start Discovery" CTA on the landing page. Set as a separate CSS variable in `_accent.scss`.
- The `active` Bootstrap list-group item overrides `background-color` with `var(--accent)` and `border-color` with `var(--accent)` to maintain dark mode consistency.

### Custom CSS

Beyond the accent overrides, one additional custom class is added:

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

These two utility classes are used exclusively in `_step_tracker.html.erb`. Everything else uses Bootstrap utilities (`text-muted`, `fw-semibold`, `d-flex`, `gap-2`). No additional custom CSS files.

### Component Choices

- Step tracker: Bootstrap `list-group` with `list-group-item-action` for clickable completed steps
- Step content pane: Bootstrap `card` with `card-body` wrapping the Turbo Frame
- Error state: Bootstrap `alert alert-danger` with a Stimulus-powered retry button
- Raw response toggle: Bootstrap `collapse` with a `btn btn-link btn-sm text-muted` trigger ("Show raw response")
- Comparison table in step 3: Rendered via `redcarpet` markdown with the `tables` extension; styled with `table table-sm table-bordered table-dark`

---

*v1.0 - Prodmentum Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*

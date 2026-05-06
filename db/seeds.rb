# Admin user — credentials for local demo use only
User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name                  = "Demo User"
  u.password              = "password123"
  u.password_confirmation = "password123"
  u.admin                 = true
end

puts "Demo user: demo@example.com / password123"

# Health ping template — used by /up/llm
AiTemplate.find_or_create_by!(name: "health_ping") do |t|
  t.description          = "Minimal prompt used by the /up/llm health check endpoint."
  t.system_prompt        = "You are a health check endpoint. Respond with exactly: ok"
  t.user_prompt_template = "ping"
  t.model                = "gemini-2.5-flash"
  t.max_output_tokens    = 10
  t.temperature          = 0.0
  t.notes                = "Do not modify. Used by HealthController#llm."
end

puts "Seeded: health_ping AI template"

# --- Prodmentum AI Templates ---

AiTemplate.find_or_create_by!(name: "prodmentum_step1_opportunity_v1") do |t|
  t.description = "Sharpens a product opportunity statement, extracts jobs-to-be-done, and surfaces discovery questions for step 1 of the Prodmentum discovery workflow."
  t.system_prompt = <<~PROMPT.strip
    You are an experienced product coach who specializes in Marty Cagan's continuous discovery framework.
    Your role is to help product managers think more clearly about the opportunity they are exploring.
    You write with precision and directness. You do not use buzzwords or filler.
    You always output in clean, structured markdown using headers and bullet points.
    You do not editorialize beyond what the user has given you. If the inputs are thin, you still produce useful output and note where the PM needs to do more thinking.
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 1200
  t.temperature       = 0.5
  t.notes             = "Lower temperature produces more structured, actionable output. Main failure mode: vague opportunity statement when inputs are thin. Watch for JTBD format being ignored — if model produces prose, reduce temperature. Discovery questions becoming generic ('Is there a market?') means the system prompt needs negative examples."
end

puts "Seeded: prodmentum_step1_opportunity_v1"

AiTemplate.find_or_create_by!(name: "prodmentum_step2_research_v1") do |t|
  t.description = "Generates a five-question discovery interview guide and flags commonly missed research pitfalls for step 2 of the discovery workflow."
  t.system_prompt = <<~PROMPT.strip
    You are a UX research coach who helps product managers design customer discovery interviews.
    You apply Teresa Torres's continuous discovery framework and Steve Portigal's interviewing principles.
    You write with clarity and precision. You do not pad responses.
    You output in clean structured markdown.
    You know that most PMs ask about solutions instead of exploring problems, and you design questions that avoid this mistake.
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 1400
  t.temperature       = 0.5
  t.notes             = "The controller carries step 1 problem forward into this template's variables. Most common failure mode: generic interview questions. If it still happens after the system prompt fix, add two or three example bad questions and why they fail. The 'commonly missed' section often becomes generic advice — tighten if needed."
end

puts "Seeded: prodmentum_step2_research_v1"

AiTemplate.find_or_create_by!(name: "prodmentum_step3_ideation_v1") do |t|
  t.description = "Compares solution ideas across effort and user value, generates a wildcard idea, and suggests the fastest prototype test for each idea for step 3."
  t.system_prompt = <<~PROMPT.strip
    You are a product design coach with deep experience in lean experimentation and rapid prototyping.
    You draw on the IDEO design thinking process and the Lean Startup validated learning loop.
    You are practical and opinionated. When you suggest prototype approaches, you name the specific type: concierge test, clickable prototype, fake door test, Wizard of Oz, paper prototype, landing page experiment, or smoke test.
    You do not recommend overbuilding. Your first suggestion is always the fastest way to learn.
    You write in clean structured markdown.
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 1600
  t.temperature       = 0.7
  t.notes             = "Higher temperature is justified here — ideation benefits from more variance. Wildcard idea is highest-value output; if it becomes obvious, increase temperature to 0.8. The markdown table sometimes breaks in simple_format — use redcarpet renderer. Known failure mode: model suggests 'build an MVP' instead of a specific lean test type; system prompt lists exact prototype names as a guard."
end

puts "Seeded: prodmentum_step3_ideation_v1"

AiTemplate.find_or_create_by!(name: "prodmentum_step4_risk_v1") do |t|
  t.description = "Generates a structured four-risk scorecard (Value, Usability, Feasibility, Business Viability) with ratings and mitigations for step 4."
  t.system_prompt = <<~PROMPT.strip
    You are a product risk coach who uses Marty Cagan's four product risks framework: Value Risk, Usability Risk, Feasibility Risk, and Business Viability Risk.
    You are direct and specific. You do not soften ratings to make them more palatable.
    You give each risk a clear Low, Medium, or High rating with a concrete one-sentence rationale.
    You suggest specific, actionable mitigations - not generic advice.
    You write in clean structured markdown.
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 1400
  t.temperature       = 0.4
  t.notes             = "Low temperature intentional — risk assessment should be structured and consistent, not creative. Most common failure mode: all Medium ratings to avoid being wrong; system prompt addresses this directly. Mitigation suggestions are highest-value output — if generic, add constraint: 'must be doable in under one week with no engineering resources.' Watch for model inventing risk context the PM did not provide."
end

puts "Seeded: prodmentum_step4_risk_v1"

AiTemplate.find_or_create_by!(name: "prodmentum_step5_iteration_v1") do |t|
  t.description = "Produces a prioritized experiment list, an iterate/pivot/proceed recommendation, and a stakeholder-ready discovery summary for step 5."
  t.system_prompt = <<~PROMPT.strip
    You are a senior product coach who helps PMs synthesize what they have learned in discovery and decide what to do next.
    You use the language of lean experimentation: iterate, pivot, or proceed to engineering.
    Your recommendations are grounded in what the PM has actually learned, not what you think they should have learned.
    You write the stakeholder summary in clear, jargon-free language that an executive who was not in the room can understand in 60 seconds.
    You write in clean structured markdown.
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT
  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 1400
  t.temperature       = 0.6
  t.notes             = "Stakeholder summary is highest-value output — PMs frequently copy it directly into status updates. If model writes it as a bullet list, add 'Do not use bullet points in this section' to the user prompt. Iterate/pivot/proceed is intentionally opinionated; if PM's inputs are thin, model sometimes hedges — prompt addresses this by requiring a direct choice or explicit acknowledgment of missing evidence."
end

puts "Seeded: prodmentum_step5_iteration_v1"

# --- Demo Product with seeded discovery outputs ---

demo_user = User.find_by!(email: "demo@example.com")

product = Product.find_or_create_by!(name: "QuickFeedback", user: demo_user) do |p|
  p.target_customer = "B2B SaaS product managers at companies with 10 to 200 employees"
  p.strategic_goal  = "Increase feature adoption by 25% in Q3 by improving feedback loops between customers and product teams"
end

# Ensure discovery steps exist
if product.discovery_steps.count < 5
  product.discovery_steps.destroy_all
  DiscoveryStep::STEP_NAMES.each do |num, name|
    product.discovery_steps.create!(step_number: num, step_name: name)
  end
end

steps = product.discovery_steps.order(:step_number).index_by(&:step_number)

step1_input = [
  "FIELD:problem",
  "PMs have no lightweight way to collect targeted feature feedback from specific customer segments. Current tools are either too heavy (Typeform, Pendo) or too noisy (generic NPS). PMs end up guessing what features to prioritize."
].join("\n")

step1_output = <<~MD.strip
  ## Sharpened Opportunity Statement
  B2B SaaS product managers at mid-size companies lack a lightweight, targeted way to collect feature-specific feedback from defined customer segments, causing them to prioritize features based on instinct rather than evidence — directly undermining the goal of increasing feature adoption by 25% in Q3.

  ## Jobs to Be Done Summary
  - **Functional job:** When I need to validate a feature priority, I want to send a targeted micro-survey to the customers most likely to use that feature, so I can get signal from the right segment without drowning in noise.
  - **Emotional job:** When I present roadmap decisions to stakeholders, I want to cite real customer data, so I can feel confident defending my prioritization choices.
  - **Social job:** When I collaborate with engineering, I want to show that my priorities are evidence-based, so I can be seen as a disciplined, data-driven PM.

  ## Discovery Questions
  1. Do PMs currently make targeting distinctions when collecting feedback, or do they broadcast to their full user base? (Hypothesis: most are broadcasting, which is why they distrust the signal.)
  2. Is the problem the absence of a tool, or the absence of a habit? (Hypothesis: PMs have access to feedback tools but do not use them consistently because the setup cost is too high relative to the perceived value.)
  3. Would a Jira-integrated micro-survey tool change prioritization behavior, or would PMs still default to HiPPO-driven decisions? (Hypothesis: the bottleneck is not the data, it is the organizational willingness to act on it.)
MD

step2_input = [
  "FIELD:interviewees",
  "5 product managers at mid-size B2B SaaS companies who currently use NPS or ad-hoc Slack messages for feedback",
  "---",
  "FIELD:existing_knowledge",
  "We know they run quarterly NPS surveys but distrust the data. Most are using Notion or Confluence to manually collect and tag feedback.",
  "---",
  "FIELD:biggest_assumption",
  "PMs would use a targeted micro-survey tool if it integrated with their existing ticketing system."
].join("\n")

step2_output = <<~MD.strip
  ## Discovery Interview Guide

  **Q1: Walk me through the last time you had to make a difficult feature prioritization call. What information did you have, and what were you missing?**
  Follow-up: What would it have taken for you to feel more confident in that decision?

  **Q2: How do you currently decide which customers to ask for feedback when you're evaluating a specific feature idea?**
  Follow-up: Has that approach ever produced feedback that surprised you or changed your direction? Tell me about that.

  **Q3: Tell me about the last time you ran a customer survey or collected structured feedback. What happened from the moment you decided to do it through to when you used the results?**
  Follow-up: Where did the process break down, if anywhere?

  **Q4: When you tag or categorize customer feedback in Notion or Confluence, who ends up reading those notes and acting on them?**
  Follow-up: What happens to feedback that doesn't get acted on?

  **Q5: Describe the last time a feature you shipped had lower-than-expected adoption. What did you learn after the fact about why that happened?**
  Follow-up: If you had known that beforehand, what would you have done differently?

  ## What PMs Commonly Miss

  1. **The interpretation gap between collection and action.** First-timers focus on gathering feedback but miss that the bottleneck is usually getting the right person to read it at the right time. Ask specifically about who reads the feedback, not just who submits it — you will likely find that feedback sits unread in Confluence until a quarterly planning cycle forces someone to look.

  2. **The difference between segment feedback and individual feedback.** Mid-size SaaS PMs often treat one loud customer as a data point rather than probing whether that customer represents a pattern. Watch for interviewees who describe changing a roadmap because of one enterprise customer complaint — this is a signal that the tool needs to support segmented aggregation, not just single-customer capture.
MD

step3_input = [
  "FIELD:solution_ideas",
  "1. In-app widget that triggers after specific feature usage events\n2. Slack bot that collects feedback in the channel where the PM already works\n3. Weekly digest email sent to a curated list of power users asking 1 question",
  "---",
  "FIELD:constraints",
  "2 engineers, 6 week timeline, must integrate with Jira"
].join("\n")

step3_output = <<~MD.strip
  ## Idea Comparison

  | Idea Name | Estimated Effort | Estimated User Value | Key Assumption to Test | Risk if Wrong |
  |---|---|---|---|---|
  | In-app widget (event-triggered) | Medium | High | PMs will configure trigger rules and act on widget responses | Engineers spend 4 weeks on a feature PMs don't configure because setup feels complex |
  | Slack bot | Low | Medium | PMs are willing to shift feedback collection into Slack rather than their PM tool | Slack becomes another place feedback gets lost; PMs don't tag or route bot responses |
  | Weekly digest email | Low | Low | Power users will respond to a weekly single-question email without survey fatigue | Low response rates make the data statistically meaningless; PMs abandon it after two weeks |

  ## Wildcard Idea
  **A Jira ticket enrichment layer** — when a PM creates or updates a Jira ticket, a sidebar automatically surfaces existing customer feedback tagged to that feature area (pulled from a lightweight feedback inbox). No new survey tool, no new workflow. The PM gets relevant signal exactly when they're making the prioritization decision, without having to go looking for it.

  Worth considering because it sidesteps the behavior-change problem entirely. The current ideas all require PMs to start a new habit (configure a widget, watch a Slack bot, send a digest). This idea meets PMs where they already are. The assumption it tests fastest: do PMs actually use feedback that is surfaced contextually, or do they still override it?

  ## Fastest Prototype Approach

  **In-app widget (event-triggered):** Fake door test. Add a "Give Feedback" button to your product's feature pages with a one-sentence description of the trigger-based widget concept. Track how many PMs click it and what they type into the placeholder form. A successful outcome: 3 of 5 pilot users click the button within two weeks and submit a response that shows they understand the trigger concept.

  **Slack bot:** Concierge test. Manually send a Slack DM to five target PMs once per week for three weeks with a single targeted question about a feature they used recently. Pretend the bot is automated. A successful outcome: at least 4 of 5 respond within 24 hours and their responses contain actionable signal (not just "looks good").

  **Weekly digest email:** Landing page experiment. Build a one-page description of the digest concept with a "Join the pilot" CTA. Send it to 20 PMs in your network. A successful outcome: 5 or more sign up, and at least 3 respond to a follow-up asking "what would make you stop reading after the first issue?"
MD

step4_input = [
  "FIELD:solution_idea",
  "In-app widget triggered after specific feature usage events",
  "---",
  "FIELD:value_risk_context",
  "4 of 5 interviewees said they would use a trigger-based widget. All 4 cited Jira integration as the reason they would actually act on the feedback.",
  "---",
  "FIELD:usability_risk_context",
  "PMs will need to configure trigger rules (which events, which user segments, which question). No one has tested whether PMs will actually do this configuration or whether they will leave it at the default.",
  "---",
  "FIELD:feasibility_risk_context",
  "2 engineers, 6-week timeline. Event tracking infrastructure already exists in the product. Jira webhook integration has been done before on a different feature.",
  "---",
  "FIELD:viability_risk_context",
  "Competitors charge $200-500/month for similar tools. We have not tested pricing yet. Our target customer segment (10-200 employee SaaS) is price-sensitive."
].join("\n")

step4_output = <<~MD.strip
  ## Value Risk
  **Rating:** Low
  **Rationale:** Four of five interviewed PMs confirmed they would use a trigger-based widget, and the Jira integration requirement — which is already scoped — is the specific reason they cited for acting on the feedback rather than ignoring it.
  **Suggested Mitigation:** Before building, send a one-paragraph description of the trigger-widget concept (no mockup, no demo) to 10 PMs outside your interview cohort and ask: "Would you pay $X/month for this if it took under 30 minutes to set up?" If fewer than 5 say yes unprompted, revisit the value framing.

  ## Usability Risk
  **Rating:** High
  **Rationale:** No one has tested whether PMs will configure trigger rules; the interview cohort expressed intent but intent and behavior diverge sharply for configuration-heavy tools — PMs routinely say they'll configure something and then leave it at default.
  **Suggested Mitigation:** Build a paper prototype of the trigger configuration UI and walk three PMs through it without any explanation. Measure whether they can set up a trigger rule (event → segment → question) in under five minutes without asking for help. If two of three cannot, simplify the configuration model before writing production code.

  ## Feasibility Risk
  **Rating:** Low
  **Rationale:** Existing event tracking infrastructure and a prior Jira webhook integration mean the two hardest technical problems are already solved; the remaining work is UI and plumbing, which is estimable within the 6-week constraint.
  **Suggested Mitigation:** Have the lead engineer do a one-day spike on the Jira webhook integration to confirm the prior implementation is reusable rather than just similar. If it is not reusable, re-estimate before committing.

  ## Business Viability Risk
  **Rating:** Medium
  **Rationale:** The $200–500/month competitive range is plausible for 50-200 employee SaaS companies, but the 10-50 employee segment is likely unable or unwilling to pay that — splitting the target customer into two pricing tiers adds complexity the team has not budgeted for.
  **Suggested Mitigation:** Run a fake door pricing test: create a landing page with three pricing tiers ($49, $99, $199/month) and drive 50 cold prospects to it via LinkedIn outreach. Measure which tier gets the most "Start free trial" clicks. Do this before engineering starts — it takes three days and eliminates the pricing guesswork.

  ## Overall Risk Summary
  The product's core value proposition is validated and the technical path is clear, but usability risk is the highest-priority concern: a widget that PMs don't configure is a widget that doesn't work. Address configuration usability with a paper prototype test before writing production code. The pricing uncertainty is real but resolvable with a lightweight fake door test that can run in parallel with early engineering.
MD

step5_input = [
  "FIELD:learnings",
  "Interviewed 4 PMs. All 4 said they would use a trigger-based widget. 3 of 4 said Jira integration is a must-have, not a nice-to-have. 1 said they are already building something internal and would prefer to buy if the price is right.",
  "---",
  "FIELD:changes",
  "Narrow the MVP to Jira integration only. Remove the Slack bot and email digest from v1. Add a pricing page to the landing page as a fake door test."
].join("\n")

step5_output = <<~MD.strip
  ## Next Experiments (Prioritized)

  1. **Experiment:** Paper prototype of the trigger configuration UI
     **Method:** Moderated usability test — walk 3 PMs through the configuration flow without explanation and measure time-to-completion and error rate
     **Success Criterion:** All 3 PMs configure a trigger rule (event → segment → question) in under 5 minutes without asking for help

  2. **Experiment:** Fake door pricing test
     **Method:** Landing page experiment — publish a pricing page with three tiers ($49, $99, $199/month) and drive 50 cold prospects via LinkedIn outreach
     **Success Criterion:** At least 20 clicks on a "Start free trial" CTA, with the majority on the $99 tier or above, within two weeks

  3. **Experiment:** Jira webhook integration spike
     **Method:** One-day technical spike — engineer confirms prior Jira webhook implementation is reusable for this use case
     **Success Criterion:** Engineer produces a written estimate confirming the integration can ship within the 6-week timeline without rework

  4. **Experiment:** Concierge test of the full trigger-to-feedback-to-Jira loop
     **Method:** Manually simulate the widget for 2 pilot customers — PM configures triggers via a spreadsheet, manually sends questions, manually tags responses to Jira tickets
     **Success Criterion:** Both pilot PMs review the Jira-tagged feedback within 48 hours and confirm it influenced at least one prioritization decision

  5. **Experiment:** Segment split on pricing willingness
     **Method:** Follow-up survey to interview cohort — ask "At what monthly price would you consider this a no-brainer vs. a tough sell?"
     **Success Criterion:** Clear price point emerges that 3 of 4 respondents agree on, enabling confident tier positioning

  ## Recommendation

  **Proceed to Engineering** — with the paper prototype usability test completed first.

  The value signal is strong (4 of 4 PMs confirmed intent, 3 of 4 named Jira integration as a must-have), the technical path is clear, and the team has correctly narrowed scope to the highest-value feature. The one remaining gate before engineering starts is the configuration UI test: if PMs cannot configure triggers without help, the MVP will ship and sit unused. Run the paper prototype test this week; if it passes, start the sprint.

  ## Discovery Summary for Stakeholders

  The team explored an opportunity to help B2B SaaS product managers collect targeted, feature-specific feedback from defined customer segments — a gap that currently leads PMs to prioritize based on instinct rather than evidence. We interviewed four PMs at mid-size SaaS companies and found consistent, strong demand for a trigger-based in-app widget that surfaces feedback directly in Jira. Jira integration emerged as a must-have, not a nice-to-have, in three of four interviews. Based on this research, we are proceeding to engineering on a scoped MVP — an event-triggered in-app widget with Jira integration — and running a one-week paper prototype test to de-risk the configuration UI before the sprint begins. A parallel fake door pricing test will validate tier positioning before launch.
MD

[
  [steps[1], step1_input, step1_output],
  [steps[2], step2_input, step2_output],
  [steps[3], step3_input, step3_output],
  [steps[4], step4_input, step4_output],
  [steps[5], step5_input, step5_output]
].each do |(step, input, output)|
  step.update!(
    user_input:    input,
    gemini_output: output,
    gemini_raw:    output,
    completed:     true
  )
end

puts "Seeded: QuickFeedback demo product with all 5 completed steps"

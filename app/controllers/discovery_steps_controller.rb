class DiscoveryStepsController < ApplicationController
  before_action :set_step

  rate_limit to: 10, within: 1.minute, only: [:update],
             with: -> { redirect_to product_path(@step.product), alert: "Please wait before generating again." }

  STEP_TEMPLATE_SUFFIXES = {
    1 => "opportunity",
    2 => "research",
    3 => "ideation",
    4 => "risk",
    5 => "iteration"
  }.freeze

  def show
  end

  def edit
    render :show
  end

  def update
    assemble_user_input

    if @step.user_input.blank?
      @step.errors.add(:base, "Please fill in the required fields before generating.")
      render :show, status: :unprocessable_entity
      return
    end

    @step.save!

    result = GeminiService.generate(
      template:  "prodmentum_step#{@step.step_number}_#{step_template_suffix}_v1",
      variables: step_variables(@step)
    )

    @step.update!(gemini_output: result, gemini_raw: result, completed: true)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("step_content",
            partial: "discovery_steps/step_output",
            locals:  { step: @step }
          ),
          turbo_stream.update("step_tracker",
            partial: "products/step_tracker",
            locals:  {
              product:     @step.product,
              steps:       @step.product.discovery_steps.order(:step_number),
              active_step: @step
            }
          )
        ]
      end
      format.html { redirect_to product_path(@step.product) }
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

  private

  def set_step
    product = current_user.products.find(params[:product_id])
    @step   = product.discovery_steps.find(params[:id])
  end

  def step_template_suffix
    STEP_TEMPLATE_SUFFIXES[@step.step_number]
  end

  # Serializes per-step sub-fields into the labeled-block format:
  #   FIELD:key\nvalue\n---\nFIELD:key2\nvalue2
  def assemble_user_input
    fields = step_params.to_h.reject { |_, v| v.blank? }
    @step.user_input = fields.map { |k, v| "FIELD:#{k}\n#{v.strip}" }.join("\n---\n")
  end

  def parse_user_input(input)
    return {} if input.blank?
    input.split("\n---\n").each_with_object({}) do |block, hash|
      lines = block.strip.split("\n", 2)
      key   = lines[0].sub("FIELD:", "").strip
      value = lines[1]&.strip || ""
      hash[key.to_sym] = value
    end
  end

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
        solution_idea:             current[:solution_idea],
        value_risk_context:        current[:value_risk_context],
        usability_risk_context:    current[:usability_risk_context],
        feasibility_risk_context:  current[:feasibility_risk_context],
        viability_risk_context:    current[:viability_risk_context]
      )
    when 5
      base.merge(
        solution_idea: step4[:solution_idea],
        learnings:     current[:learnings],
        changes:       current[:changes]
      )
    end
  end

  def step_params
    case @step.step_number
    when 1
      params.require(:discovery_step).permit(:problem)
    when 2
      params.require(:discovery_step).permit(:interviewees, :existing_knowledge, :biggest_assumption)
    when 3
      params.require(:discovery_step).permit(:solution_ideas, :constraints)
    when 4
      params.require(:discovery_step).permit(:solution_idea, :value_risk_context,
                                              :usability_risk_context, :feasibility_risk_context,
                                              :viability_risk_context)
    when 5
      params.require(:discovery_step).permit(:learnings, :changes)
    else
      params.require(:discovery_step).permit
    end
  end

  def render_step_error(error_type)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("step_content",
          partial: "shared/step_error",
          locals:  { step: @step, error_type: error_type }
        )
      end
      format.html { redirect_to product_path(@step.product), alert: "AI generation failed. Please try again." }
    end
  end
end

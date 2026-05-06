class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :export]

  def index
    @products = current_user.products.includes(:discovery_steps).order(created_at: :desc)
  end

  def new
    @product = Product.new
  end

  def create
    @product = current_user.products.build(product_params)
    if @product.save
      create_discovery_steps
      redirect_to product_path(@product)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @steps       = @product.discovery_steps.order(:step_number)
    @active_step = @steps.find { |s| !s.completed? } || @steps.first
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to product_path(@product)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path
  end

  def export
    steps    = @product.discovery_steps.order(:step_number)
    markdown = build_export_markdown(@product, steps)
    filename = "#{@product.name.parameterize}-discovery.md"
    send_data markdown, filename: filename, type: "text/plain", disposition: "attachment"
  end

  private

  def set_product
    @product = current_user.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :target_customer, :strategic_goal)
  end

  def create_discovery_steps
    DiscoveryStep::STEP_NAMES.each do |num, name|
      @product.discovery_steps.create!(step_number: num, step_name: name)
    end
  end

  FIELD_LABELS = {
    problem:                  "Problem Statement",
    interviewees:             "Who to Interview",
    existing_knowledge:       "What You Already Know",
    biggest_assumption:       "Biggest Assumption to Test",
    solution_ideas:           "Solution Ideas",
    constraints:              "Constraints",
    solution_idea:            "Leading Solution Idea",
    value_risk_context:       "Value Risk Context",
    usability_risk_context:   "Usability Risk Context",
    feasibility_risk_context: "Feasibility Risk Context",
    viability_risk_context:   "Business Viability Risk Context",
    learnings:                "What You Learned",
    changes:                  "What You'd Change"
  }.freeze

  def build_export_markdown(product, steps)
    lines = []
    lines << "# #{product.name} — Product Discovery Report"
    lines << ""
    lines << "**Target Customer:** #{product.target_customer}"
    lines << "**Strategic Goal:** #{product.strategic_goal}"
    lines << ""

    steps.each do |step|
      lines << "---"
      lines << ""
      lines << "## Step #{step.step_number}: #{step.step_name}"
      lines << ""

      if step.user_input.present?
        parse_user_input(step.user_input).each do |key, value|
          label = FIELD_LABELS[key] || key.to_s.humanize
          lines << "**#{label}**"
          lines << ""
          lines << value
          lines << ""
        end
      end

      if step.gemini_output.present?
        lines << "### AI Analysis"
        lines << ""
        lines << step.gemini_output
        lines << ""
      else
        lines << "_This step has not been completed yet._"
        lines << ""
      end
    end

    lines.join("\n")
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
end

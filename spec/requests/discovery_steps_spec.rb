require "rails_helper"

RSpec.describe "DiscoverySteps", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user) }
  let(:product) { create(:product, user: user) }

  let(:step) do
    product.discovery_steps.create!(
      step_number: 1,
      step_name: DiscoveryStep::STEP_NAMES[1]
    )
  end

  let(:other_product) { create(:product, user: other) }
  let(:other_step) do
    other_product.discovery_steps.create!(
      step_number: 1,
      step_name: DiscoveryStep::STEP_NAMES[1]
    )
  end

  describe "GET /products/:product_id/steps/:id" do
    it "redirects unauthenticated visitors to sign in" do
      get product_step_path(product, step)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "renders the step form for an incomplete step" do
        get product_step_path(product, step)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Generate with AI")
      end

      it "returns 404 for a step belonging to another user's product" do
        get product_step_path(other_product, other_step)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /products/:product_id/steps/:id/edit" do
    context "when signed in" do
      before { sign_in_as(user) }

      it "renders the step form" do
        get edit_product_step_path(product, step)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Generate with AI")
      end
    end
  end

  describe "PATCH /products/:product_id/steps/:id" do
    it "redirects unauthenticated visitors to sign in" do
      patch product_step_path(product, step),
            params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } }
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      context "with valid step 1 input" do
        let(:gemini_response) do
          "## Sharpened Opportunity Statement\nPMs at mid-size SaaS lack targeted feedback.\n\n## JTBD Summary\nWhen planning features..."
        end

        before do
          allow(GeminiService).to receive(:generate).and_return(gemini_response)
        end

        it "calls GeminiService with the correct template name" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(GeminiService).to have_received(:generate).with(
            hash_including(template: "prodmentum_step1_opportunity_v1")
          )
        end

        it "saves user_input in the labeled-block format" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }

          step.reload
          expect(step.user_input).to include("FIELD:problem")
          expect(step.user_input).to include("PMs lack a lightweight feedback tool.")
        end

        it "sets gemini_output and gemini_raw and marks the step completed" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }

          step.reload
          expect(step.gemini_output).to eq(gemini_response)
          expect(step.gemini_raw).to eq(gemini_response)
          expect(step.completed).to be true
        end

        it "returns a Turbo Stream response" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        end
      end

      context "with blank input" do
        it "does not call GeminiService" do
          allow(GeminiService).to receive(:generate)

          patch product_step_path(product, step),
                params: { discovery_step: { problem: "" } }

          expect(GeminiService).not_to have_received(:generate)
        end

        it "re-renders the step form with unprocessable entity status" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "" } }

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "when GeminiService raises GeminiError" do
        before do
          allow(GeminiService).to receive(:generate).and_raise(GeminiService::GeminiError, "API failure")
        end

        it "returns a Turbo Stream response with the error partial" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("AI generation failed")
        end

        it "leaves the step as incomplete" do
          patch product_step_path(product, step),
                params: { discovery_step: { problem: "PMs lack a lightweight feedback tool." } },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }

          step.reload
          expect(step.completed).to be false
        end
      end

      context "when step belongs to another user's product" do
        it "returns 404" do
          patch product_step_path(other_product, other_step),
                params: { discovery_step: { problem: "test" } }
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end

require "rails_helper"

RSpec.describe "Products", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user) }
  let(:product) { create(:product, user: user) }

  describe "GET /products" do
    it "redirects unauthenticated visitors to sign in" do
      get products_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "shows only the signed-in user's products" do
      sign_in_as(user)
      own_product   = create(:product, user: user, name: "My Product")
      other_product = create(:product, user: other, name: "Their Product")

      get products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Product")
      expect(response.body).not_to include("Their Product")
    end
  end

  describe "POST /products" do
    let(:valid_params) do
      { product: { name: "TestApp", target_customer: "PMs", strategic_goal: "Grow retention" } }
    end

    it "redirects unauthenticated visitors to sign in" do
      post products_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end

    context "with valid params" do
      before { sign_in_as(user) }

      it "creates a product and five discovery steps" do
        expect {
          post products_path, params: valid_params
        }.to change(Product, :count).by(1)
           .and change(DiscoveryStep, :count).by(5)
      end

      it "creates steps with correct names and completed: false" do
        post products_path, params: valid_params
        product = Product.last
        steps   = product.discovery_steps.order(:step_number)

        expect(steps.map(&:step_name)).to eq(DiscoveryStep::STEP_NAMES.values)
        expect(steps.map(&:completed)).to all(be false)
        expect(steps.map(&:step_number)).to eq([1, 2, 3, 4, 5])
      end

      it "redirects to the product show page" do
        post products_path, params: valid_params
        expect(response).to redirect_to(product_path(Product.last))
      end
    end

    context "with invalid params" do
      before { sign_in_as(user) }

      it "does not create a product and re-renders the form" do
        expect {
          post products_path, params: { product: { name: "", target_customer: "", strategic_goal: "" } }
        }.not_to change(Product, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /products/:id/export" do
    it "redirects unauthenticated visitors to sign in" do
      get export_product_path(product)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns a markdown file attachment" do
        get export_product_path(product)
        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".md")
        expect(response.body).to include("# #{product.name}")
        expect(response.body).to include(product.target_customer)
        expect(response.body).to include(product.strategic_goal)
      end

      it "includes completed step AI output in the export" do
        step = create(:discovery_step, :completed, product: product, step_number: 1,
                      step_name: "Opportunity Framing", gemini_output: "## Sharpened Opportunity\nTest output.")
        get export_product_path(product)
        expect(response.body).to include("Opportunity Framing")
        expect(response.body).to include("Test output.")
      end

      it "returns 404 for another user's product" do
        other_product = create(:product, user: other)
        get export_product_path(other_product)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /products/:id" do
    it "redirects unauthenticated visitors to sign in" do
      delete product_path(product)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "destroys the product and its discovery steps" do
        step_count = product.discovery_steps.count
        expect {
          delete product_path(product)
        }.to change(Product, :count).by(-1)

        expect(DiscoveryStep.where(product_id: product.id)).to be_empty
      end

      it "redirects to products index" do
        delete product_path(product)
        expect(response).to redirect_to(products_path)
      end

      it "returns 404 for another user's product" do
        other_product = create(:product, user: other)
        delete product_path(other_product)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end

require "rails_helper"

RSpec.describe Product, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:target_customer) }
    it { is_expected.to validate_presence_of(:strategic_goal) }

    it "rejects name longer than 120 characters" do
      product = build(:product, name: "a" * 121)
      expect(product).not_to be_valid
      expect(product.errors[:name]).to be_present
    end

    it "accepts name at exactly 120 characters" do
      product = build(:product, name: "a" * 120)
      expect(product).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:discovery_steps).dependent(:destroy) }

    it "destroys associated discovery steps when destroyed" do
      product = create(:product)
      create(:discovery_step, product: product)
      expect { product.destroy }.to change(DiscoveryStep, :count).by(-1)
    end
  end

  describe "user scoping" do
    it "is not accessible through another user's products" do
      user_a   = create(:user)
      user_b   = create(:user)
      product  = create(:product, user: user_a)

      expect(user_b.products).not_to include(product)
    end
  end
end

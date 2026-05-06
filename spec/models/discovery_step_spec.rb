require "rails_helper"

RSpec.describe DiscoveryStep, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:step_number) }
    it { is_expected.to validate_presence_of(:step_name) }

    it "rejects step_number outside 1..5" do
      expect(build(:discovery_step, step_number: 0)).not_to be_valid
      expect(build(:discovery_step, step_number: 6)).not_to be_valid
    end

    it "accepts step_number in 1..5" do
      (1..5).each do |n|
        step = build(:discovery_step, step_number: n, step_name: DiscoveryStep::STEP_NAMES[n])
        expect(step).to be_valid
      end
    end

    it "rejects duplicate step_number for the same product" do
      product = create(:product)
      create(:discovery_step, product: product, step_number: 1, step_name: "Opportunity Framing")
      duplicate = build(:discovery_step, product: product, step_number: 1, step_name: "Opportunity Framing")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:step_number]).to be_present
    end

    it "allows the same step_number on different products" do
      create(:discovery_step, step_number: 1, step_name: "Opportunity Framing")
      other = build(:discovery_step, step_number: 1, step_name: "Opportunity Framing")
      expect(other).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:product) }
  end

  describe "defaults" do
    it "defaults completed to false" do
      step = create(:discovery_step)
      expect(step.completed).to be false
    end
  end
end

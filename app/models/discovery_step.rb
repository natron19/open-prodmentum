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

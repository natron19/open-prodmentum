class Product < ApplicationRecord
  belongs_to :user
  has_many :discovery_steps, dependent: :destroy

  validates :name,            presence: true, length: { maximum: 120 }
  validates :target_customer, presence: true, length: { maximum: 200 }
  validates :strategic_goal,  presence: true, length: { maximum: 300 }
end

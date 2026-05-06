FactoryBot.define do
  factory :product do
    association :user
    sequence(:name)  { |n| "Product #{n}" }
    target_customer  { "B2B SaaS product managers" }
    strategic_goal   { "Increase feature adoption by 25% in Q3" }
  end
end

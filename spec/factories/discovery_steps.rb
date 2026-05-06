FactoryBot.define do
  factory :discovery_step do
    association :product
    step_number { 1 }
    step_name   { DiscoveryStep::STEP_NAMES[1] }
    completed   { false }

    trait :completed do
      completed     { true }
      gemini_output { "## AI Output\n\nThis is a sample Gemini response." }
      gemini_raw    { gemini_output }
    end

    trait :step1 do
      step_number { 1 }
      step_name   { DiscoveryStep::STEP_NAMES[1] }
    end

    trait :step2 do
      step_number { 2 }
      step_name   { DiscoveryStep::STEP_NAMES[2] }
    end

    trait :step3 do
      step_number { 3 }
      step_name   { DiscoveryStep::STEP_NAMES[3] }
    end

    trait :step4 do
      step_number { 4 }
      step_name   { DiscoveryStep::STEP_NAMES[4] }
    end

    trait :step5 do
      step_number { 5 }
      step_name   { DiscoveryStep::STEP_NAMES[5] }
    end
  end
end

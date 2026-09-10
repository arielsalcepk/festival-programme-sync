FactoryBot.define do
  factory :sync_run do
    status { "running" }
    started_at { Time.current }
  end
end

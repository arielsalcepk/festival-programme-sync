class ScreeningSyncJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 5

  def perform(generation: nil)
    ScreeningSync.new(generation: generation).call
  end
end

class SyncRun < ApplicationRecord
  STATUSES = %w[running succeeded failed skipped].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  scope :recent, -> { order(started_at: :desc) }

  def duration
    return nil unless finished_at

    finished_at - started_at
  end
end

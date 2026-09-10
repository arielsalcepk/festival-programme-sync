require "rails_helper"

RSpec.describe SyncRun do
  it "is valid with a known status and a started_at" do
    expect(build(:sync_run)).to be_valid
  end

  it "rejects an unknown status" do
    expect(build(:sync_run, status: "bogus")).not_to be_valid
  end

  it "has no duration while still running" do
    expect(build(:sync_run, finished_at: nil).duration).to be_nil
  end

  it "computes duration once finished" do
    run = build(:sync_run, started_at: 10.seconds.ago, finished_at: Time.current)

    expect(run.duration).to be_within(1).of(10)
  end
end

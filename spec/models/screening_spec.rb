require "rails_helper"

RSpec.describe Screening do
  it "is valid with an external_id, film, venue and starts_at" do
    expect(build(:screening)).to be_valid
  end

  it "requires a unique external_id" do
    create(:screening, external_id: "SCR-0001")

    expect(build(:screening, external_id: "SCR-0001")).not_to be_valid
  end

  it "defaults to scheduled" do
    expect(build(:screening).status).to eq("scheduled")
  end

  it "can be cancelled" do
    screening = create(:screening, status: "cancelled")

    expect(screening).to be_cancelled
  end
end

require "rails_helper"

RSpec.describe Venue do
  it "is valid with an external_id and a name" do
    expect(build(:venue)).to be_valid
  end

  it "requires a unique external_id" do
    create(:venue, external_id: "VEN-01")

    expect(build(:venue, external_id: "VEN-01")).not_to be_valid
  end

  it "requires a name" do
    expect(build(:venue, name: nil)).not_to be_valid
  end
end

require "rails_helper"

RSpec.describe Film do
  it "is valid with an external_id and a title" do
    expect(build(:film)).to be_valid
  end

  it "requires a unique external_id" do
    create(:film, external_id: "FILM-001")

    expect(build(:film, external_id: "FILM-001")).not_to be_valid
  end

  it "requires a title" do
    expect(build(:film, title: nil)).not_to be_valid
  end
end

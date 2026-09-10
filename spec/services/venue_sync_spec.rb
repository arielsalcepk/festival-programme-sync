require "rails_helper"

RSpec.describe VenueSync do
  describe "#call" do
    it "creates a venue that doesn't exist yet" do
      payload = [
        { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 }
      ]

      expect { VenueSync.new(payload).call }.to change(Venue, :count).by(1)

      venue = Venue.find_by(external_id: "VEN-01")
      expect(venue).to have_attributes(
        name: "Grand Cinema",
        address: "12 Main Street",
        capacity: 320
      )
    end

    it "updates the existing venue instead of duplicating it when the name changes" do
      create(:venue, external_id: "VEN-03", name: "City Gallery Screening Room")

      payload = [
        { "id" => "VEN-03", "name" => "City Gallery Auditorium", "address" => "1 Museum Square", "capacity" => 90 }
      ]

      expect { VenueSync.new(payload).call }.not_to change(Venue, :count)

      venue = Venue.find_by(external_id: "VEN-03")
      expect(venue.name).to eq("City Gallery Auditorium")
    end

    it "is idempotent across repeated runs" do
      payload = [
        { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 }
      ]

      VenueSync.new(payload).call

      expect { VenueSync.new(payload).call }.not_to change(Venue, :count)
    end

    it "reports created and updated counts" do
      create(:venue, external_id: "VEN-02", name: "Riverside Cinema")

      payload = [
        { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 },
        { "id" => "VEN-02", "name" => "Riverside Cinema Renamed", "address" => "4 Quay Road", "capacity" => 180 }
      ]

      result = VenueSync.new(payload).call

      expect(result.created).to eq(1)
      expect(result.updated).to eq(1)
      expect(result.errors).to be_empty
    end

    it "isolates a bad record instead of abandoning the whole batch" do
      payload = [
        { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 },
        { "name" => "Missing id", "address" => "nowhere", "capacity" => 1 }
      ]

      result = VenueSync.new(payload).call

      expect(Venue.find_by(external_id: "VEN-01")).to be_present
      expect(result.created).to eq(1)
      expect(result.errors.size).to eq(1)
    end
  end
end

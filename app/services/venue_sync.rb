class VenueSync
  Result = Struct.new(:created, :updated, :errors, keyword_init: true)

  def initialize(venues)
    @venues = venues
  end

  def call
    created = 0
    updated = 0
    errors  = []

    @venues.each do |attrs|
      venue = Venue.find_or_initialize_by(external_id: attrs.fetch("id"))
      was_new = venue.new_record?
      venue.name     = attrs["name"]
      venue.address  = attrs["address"]
      venue.capacity = attrs["capacity"]
      changed = venue.changed?
      venue.save!

      created += 1 if was_new
      updated += 1 if !was_new && changed
    rescue => e
      errors << { "external_id" => attrs["id"], "message" => e.message }
    end

    Result.new(created: created, updated: updated, errors: errors)
  end
end

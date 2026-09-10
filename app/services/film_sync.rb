class FilmSync
  Result = Struct.new(:created, :updated, :errors, keyword_init: true)

  def initialize(films)
    @films = films
  end

  def call
    created = 0
    updated = 0
    errors  = []

    @films.each do |attrs|
      film = Film.find_or_initialize_by(external_id: attrs.fetch("id"))
      was_new = film.new_record?
      film.title    = attrs["title"]
      film.synopsis = attrs["synopsis"]
      film.runtime  = attrs["runtime"]
      film.year     = attrs["year"]
      changed = film.changed?
      film.save!

      created += 1 if was_new
      updated += 1 if !was_new && changed
    rescue => e
      errors << { "external_id" => attrs["id"], "message" => e.message }
    end

    Result.new(created: created, updated: updated, errors: errors)
  end
end

require "rails_helper"

RSpec.describe FilmSync do
  describe "#call" do
    it "creates a film that doesn't exist yet" do
      payload = [
        { "id" => "FILM-001", "title" => "The Silent Orchard", "synopsis" => "...", "runtime" => 118, "year" => 2024 }
      ]

      expect { FilmSync.new(payload).call }.to change(Film, :count).by(1)
    end

    it "updates the existing film instead of duplicating it when the title changes" do
      create(:film, external_id: "FILM-005", title: "Autumn in Trieste")

      payload = [
        { "id" => "FILM-005", "title" => "Autumn in Trieste (Director's Cut)", "synopsis" => "...", "runtime" => 110, "year" => 2024 }
      ]

      expect { FilmSync.new(payload).call }.not_to change(Film, :count)

      film = Film.find_by(external_id: "FILM-005")
      expect(film.title).to eq("Autumn in Trieste (Director's Cut)")
    end

    it "is idempotent across repeated runs" do
      payload = [
        { "id" => "FILM-001", "title" => "The Silent Orchard", "synopsis" => "...", "runtime" => 118, "year" => 2024 }
      ]

      FilmSync.new(payload).call

      expect { FilmSync.new(payload).call }.not_to change(Film, :count)
    end
  end
end

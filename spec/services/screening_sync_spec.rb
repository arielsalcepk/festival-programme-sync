require "rails_helper"

RSpec.describe ScreeningSync do
  def sync(**opts)
    described_class.new(http: InProcessHttp.new, **opts).call
  end

  describe "a full sync of generation 1" do
    it "pulls every screening, film and venue and records a succeeded run" do
      sync_run = sync(generation: 1)

      expect(sync_run.status).to eq("succeeded")
      expect(Screening.count).to eq(60)
      expect(Film.count).to eq(12)
      expect(Venue.count).to eq(6)
      expect(sync_run.screenings_created).to eq(60)
      expect(sync_run.screenings_failed).to eq(0)
    end

    it "is idempotent: running it again creates and updates nothing" do
      sync(generation: 1)

      second_run = sync(generation: 1)

      expect(Screening.count).to eq(60)
      expect(second_run.screenings_created).to eq(0)
      expect(second_run.screenings_updated).to eq(0)
    end
  end

  describe "syncing generation 2 after generation 1" do
    before { sync(generation: 1) }

    it "updates moved venues and cancelled screenings without creating duplicates" do
      sync(generation: 2)

      moved = Screening.find_by!(external_id: "SCR-0001")
      expect(moved.venue.external_id).to eq("VEN-06")

      cancelled = Screening.find_by!(external_id: "SCR-0010")
      expect(cancelled).to be_cancelled
    end

    it "updates the retitled film in place instead of creating a second one" do
      sync(generation: 2)

      expect(Film.count).to eq(12)
      expect(Film.where(title: "Autumn in Trieste (Director's Cut)").count).to eq(1)
    end

    it "updates the renamed venue in place instead of creating a second one" do
      sync(generation: 2)

      expect(Venue.count).to eq(6)
      expect(Venue.where(name: "City Gallery Auditorium").count).to eq(1)
    end

    it "inserts newly added screenings" do
      sync(generation: 2)

      expect(Screening.find_by(external_id: "SCR-0061")).to be_present
      expect(Screening.find_by(external_id: "SCR-0062")).to be_present
    end
  end

  describe "a partial failure partway through" do
    it "keeps the records it already fetched and marks the run failed" do
      sync_run = sync(generation: 1, fail_after: 8)

      expect(sync_run.status).to eq("failed")
      expect(sync_run.error_message).to be_present
      expect(Screening.count).to eq(8)
    end

    it "doesn't lose the earlier pages on a later retry with clean data" do
      sync(generation: 1, fail_after: 8)

      sync_run = sync(generation: 1)

      expect(sync_run.status).to eq("succeeded")
      expect(Screening.count).to eq(60)
    end
  end

  describe "overlapping runs" do
    it "skips instead of racing when a run is already in progress" do
      cfg = ActiveRecord::Base.connection_db_config.configuration_hash
      other_session = PG.connect(
        host: cfg[:host], port: cfg[:port],
        user: cfg[:username], password: cfg[:password], dbname: cfg[:database]
      )
      lock_held = other_session.exec("SELECT pg_try_advisory_lock(#{ScreeningSync::LOCK_KEY})").getvalue(0, 0)
      expect(lock_held).to eq("t")

      begin
        sync_run = sync(generation: 1)
        expect(sync_run.status).to eq("skipped")
        expect(Screening.count).to eq(0)
      ensure
        other_session.exec("SELECT pg_advisory_unlock(#{ScreeningSync::LOCK_KEY})")
        other_session.close
      end
    end
  end
end

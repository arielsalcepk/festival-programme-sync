class ScreeningSync
  class ApiError < StandardError; end

  LOCK_KEY = 727_364_829

  def initialize(generation: nil, fail_after: nil, slow: nil, http: nil)
    @query = { generation: generation, fail_after: fail_after, slow: slow }.compact
    @http  = http || build_http
  end

  def call
    sync_run = SyncRun.new(status: "running", started_at: Time.current)

    unless acquire_lock
      sync_run.assign_attributes(
        status: "skipped",
        finished_at: Time.current,
        error_message: "another sync run is already in progress"
      )
      sync_run.save!
      return sync_run
    end

    sync_run.save!

    begin
      page = 1
      loop do
        body = fetch_page(page)
        sync_run.pages_fetched += 1
        process_page(body.fetch("screenings"), sync_run)
        sync_run.save!
        break if page >= body.fetch("total_pages")

        page += 1
      end
      sync_run.status = "succeeded"
    rescue ApiError => e
      sync_run.status = "failed"
      sync_run.error_message = e.message
    ensure
      sync_run.finished_at = Time.current
      sync_run.save!
      release_lock
    end

    sync_run
  end

  private

  def process_page(records, sync_run)
    films  = records.map { |r| r.fetch("film") }.uniq { |f| f["id"] }
    venues = records.map { |r| r.fetch("venue") }.uniq { |v| v["id"] }

    record_upsert_errors(sync_run, FilmSync.new(films).call.errors, "film")
    record_upsert_errors(sync_run, VenueSync.new(venues).call.errors, "venue")

    records.each { |record| sync_screening(record, sync_run) }
  end

  def sync_screening(record, sync_run)
    ActiveRecord::Base.transaction do
      film  = Film.find_by!(external_id: record.fetch("film").fetch("id"))
      venue = Venue.find_by!(external_id: record.fetch("venue").fetch("id"))

      screening = Screening.find_or_initialize_by(external_id: record.fetch("id"))
      was_new = screening.new_record?
      screening.assign_attributes(
        film: film,
        venue: venue,
        starts_at: record.fetch("starts_at"),
        status: record.fetch("status")
      )
      changed = screening.changed?
      screening.save!

      sync_run.screenings_created += 1 if was_new
      sync_run.screenings_updated += 1 if !was_new && changed
    end
  rescue => e
    sync_run.screenings_failed += 1
    sync_run.sync_errors += [ { "external_id" => record["id"], "message" => e.message } ]
  end

  def record_upsert_errors(sync_run, errors, kind)
    return if errors.empty?

    sync_run.screenings_failed += errors.size
    sync_run.sync_errors += errors.map { |e| e.merge("type" => kind) }
  end

  def fetch_page(page)
    response = @http.get("/mock_api/screenings", @query.merge(page: page))
    raise ApiError, "upstream returned #{response.status}" unless response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error => e
    raise ApiError, e.message
  end

  def build_http
    Faraday.new(url: ENV.fetch("FESTIVAL_API_URL", "http://localhost:3000")) do |f|
      f.options.timeout = 15
      f.options.open_timeout = 5
      f.adapter Faraday.default_adapter
    end
  end

  def acquire_lock
    ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})") == true
  end

  def release_lock
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{LOCK_KEY})")
  end
end

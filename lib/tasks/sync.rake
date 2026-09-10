namespace :sync do
  desc "Enqueue a screenings sync"
  task screenings: :environment do
    ScreeningSyncJob.perform_later
  end
end

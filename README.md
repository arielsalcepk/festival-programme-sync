# Festival Programme Sync — Take-Home

**Role:** Senior Rails / Hotwire Developer · **Time box:** 4 hours
**Stack:** Rails 8, Hotwire, PostgreSQL, Sidekiq, Tailwind (all in Docker)

## Context

You're joining a team that maintains a film festival's public website. It's a
Rails monolith that also acts as the editorial CMS, and it pulls programming data
from an external festival-management system over an API.

That external system is the source of truth for films, venues and screenings. Our
database holds a local copy so the site renders fast and stays up under load.
Today that copy is refreshed by a nightly script a colleague wrote in a hurry, and
it's been causing problems.

**Your job is to replace it.**

## What we've given you

A working Rails 8 app with `Film`, `Venue` and `Screening` models, a mock external
API at `/mock_api` that behaves like the real one including its failure modes, an
existing `VenueSync` service and its tests, a screenings index with a filter form,
and seed data.

### Running it

Everything runs in Docker. One step:

```bash
docker compose up --build
```

That starts Postgres, Redis, the Rails web server, a Tailwind watcher and Sidekiq,
and creates/migrates/seeds the database on first boot.

- App: <http://localhost:3000>
- Sidekiq dashboard: <http://localhost:3000/sidekiq>
- Postgres is exposed on host port **5544** (non-standard, so it won't collide)

Handy commands (see the `Makefile`):

```bash
make console   # rails console inside the web container
make test      # run the RSpec suite
make sh        # a shell in the web container
```

## What we'd like you to build

1. **A programme sync.** Pull screenings from `GET /mock_api/screenings` into our
   database. It's paginated, returns nested film and venue data, and behaves like a
   real third-party API: sometimes slow, sometimes failing partway through, and its
   records change between runs.

   Running it twice must not create duplicates. Running it after upstream data
   changes must update the local copy. If the API fails partway, records already
   retrieved shouldn't be lost. It should run on a schedule as a background job, and
   we should be able to tell afterwards whether a run succeeded and what it did.

2. **A filtered screenings list.** The index at `/screenings` has a filter form that
   reloads the whole page. Make it update just the results. Filters are date, venue,
   and a text search across titles. Keep it server-rendered; we're a Hotwire shop and
   aren't looking for a client-side rendering layer.

3. **A short README.** Half a page. What you'd do differently with more time, anything
   in the existing code you'd change and why, and any assumptions you made.

## Testing the mock API

| Parameter      | Effect                                                                                                     |
| -------------- | ---------------------------------------------------------------------------------------------------------- |
| `?page=2`      | Pagination, 25 records per page                                                                            |
| `?generation=2`| The dataset after upstream changes. Screenings have moved venue, some are cancelled, a film has been retitled, two screenings are new. |
| `?fail_after=8`| Returns 8 records, then a 500                                                                              |
| `?slow=true`   | Six-second delay                                                                                           |

Sync `generation=1`, then `generation=2`, and check the database is right. Then try
`generation=1&fail_after=8` and check nothing was lost.

## What we care about

- **Correctness under failure, ahead of feature completeness.** If you run short, a
  sync that handles the edge cases and a filter that doesn't quite work beats the
  reverse.
- Tests are expected — at least for the sync and the models. Tests for the view
  layer aren't. We're looking at how you test, not just that you did, so write
  your own; the repo doesn't hand you a test plan.

## Submitting

A private git repo with your commits. Please don't squash.

---

## Notes on this submission

### What I built

- `ScreeningSync` pulls `/mock_api/screenings` page by page. Each page is persisted
  before moving to the next, so a failure on page 3 doesn't lose pages 1-2. Within a
  page, each screening (and each film/venue it references) is upserted in its own
  transaction and a bad record is caught and logged rather than aborting the page.
  Everything is upserted on `external_id`, so re-running a generation is a no-op and
  re-running after an upstream change updates in place.
- A Postgres advisory lock (`pg_try_advisory_lock`) means a second sync started while
  one is already running skips instead of racing it.
- Every run writes a `SyncRun` row (status, timing, created/updated/failed counts,
  captured errors), including failed and skipped runs, so you can tell after the fact
  whether a run worked and what it touched.
- `ScreeningSyncJob` is a thin, retryable (`sidekiq_options retry: 5`) Sidekiq wrapper
  around `ScreeningSync`. `rake sync:screenings` enqueues one, for manual runs or a
  cron entry.
- The screenings index: fixed the filter form so it targets the `screenings` Turbo
  Frame instead of doing a full page reload, eager-loaded `film`/`venue` to remove the
  N+1 in the results table, and wired the `q` param (accepted by the form, silently
  dropped by the controller) to an actual `films.title ILIKE` filter.

### What I'd change in the existing code, and why

`VenueSync` matched venues by `name` instead of `external_id`. `external_id` is the
only field the API guarantees is stable — generation 2's fixture data renames a venue
on purpose to prove this. Matching on name meant a rename created a second venue
instead of updating the first, which is exactly the kind of drift a "local copy of an
external source of truth" can't afford. I fixed it to match on `external_id`, and also
gave it per-record error handling — the original raised on the first bad record and
lost the rest of the batch. I applied the same fix to a new `FilmSync`, since a
title-keyed match has the identical failure mode and generation 2 retitles a film on
purpose too.

### What I'd do differently with more time

- I didn't wire an actual scheduler (`sidekiq-cron` or similar) — `rake sync:screenings`
  is what a cron entry or scheduler would call, but nothing calls it automatically here.
  More importantly, I think a fixed-interval full sync is the wrong long-term shape for
  this data: a venue moving at 2pm during festival week needs to show up in minutes, not
  after up to an hour of polling drift. I'd rather the upstream system push changes
  (webhook or event feed) and keep the scheduled full sync as a periodic reconciliation
  safety net, not the primary path.
- The search field requires clicking "Filter" rather than submitting as you type. A
  debounced Stimulus controller would be a small, natural addition — left out to stay
  inside what the brief actually asked for.
- `SyncRun#errors` is a jsonb array. Fine at this scale; if error volume or alerting
  needs grew, I'd split it into its own table.

### Assumptions

- Generation 2 removes one screening (`SCR-0060`) upstream. I did not implement
  deletion handling. You can't safely tell "genuinely removed" apart from "just not on
  a page we've fetched yet" except after a fully successful run, and even then I'd
  rather mark a screening as no-longer-offered (the same way `cancelled` is already a
  status, not a delete) than hard-delete it — historical/booking data further down the
  line shouldn't dangle on a foreign key to a row that vanished. Calling this out
  rather than quietly leaving it undone.
- `generation` is a testing-only concept the mock API exposes; the real sync never
  passes it, so it always gets whichever generation the upstream API is currently
  serving.

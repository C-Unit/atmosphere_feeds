defmodule AtmosphereFeeds.Repo do
  use Ecto.Repo,
    otp_app: :atmosphere_feeds,
    adapter: Ecto.Adapters.Postgres
end

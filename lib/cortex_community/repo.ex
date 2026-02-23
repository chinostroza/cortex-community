defmodule CortexCommunity.Repo do
  use Ecto.Repo,
    otp_app: :cortex_community,
    adapter: Ecto.Adapters.Postgres
end

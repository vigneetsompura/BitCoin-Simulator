defmodule Project42.Repo do
  use Ecto.Repo,
    otp_app: :project4_2,
    adapter: Ecto.Adapters.Postgres
end

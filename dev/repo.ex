defmodule Demo.Repo do
  use Ecto.Repo, otp_app: :live_admin, adapter: Ecto.Adapters.Postgres

  def prefixes, do: ["public", "alt"]
end

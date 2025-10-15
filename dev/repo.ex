defmodule Demo.Repo do
  use Ecto.Repo, otp_app: :live_admin, adapter: Ecto.Adapters.Postgres

  def prefixes, do: ["public", "alt"] ++ Enum.map(0..100, & "fake #{&1}")
end

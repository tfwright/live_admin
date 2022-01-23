defmodule PhoenixLiveAdmin.Application do
  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Phoenix.LiveAdmin.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  defp children do
    [{Phoenix.LiveAdmin.SessionStore, %{}}]
  end
end

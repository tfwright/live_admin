defmodule LiveAdmin.Application do
  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: LiveAdmin.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  defp children do
    [{LiveAdmin.SessionStore, %{}}]
  end
end

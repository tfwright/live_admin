defmodule Phoenix.LiveAdmin do
  def list_resource(resource) do
    repo().all(resource)
  end

  defp repo, do: Application.fetch_env!(:phoenix_live_admin, :ecto_repo)
end

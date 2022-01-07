defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign(socket, :resource, params["resource"])}
  end
end

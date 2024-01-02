defmodule LiveAdmin.Components.Home do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={get_in(@config, [:components, :home])} id="content" />
    """
  end
end

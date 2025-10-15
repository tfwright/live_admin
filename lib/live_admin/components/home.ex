defmodule LiveAdmin.Components.Home do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <main class="content">
      <.live_component module={get_in(@config, [:components, :home])} id="content" />
    </main>
    """
  end
end

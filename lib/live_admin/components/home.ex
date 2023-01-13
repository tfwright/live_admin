defmodule LiveAdmin.Components.Home do
  use Phoenix.LiveView

  alias __MODULE__.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns = %{title: title}) do
    mod = Keyword.get(assigns.components, :home, Content)

    ~H"""
    <h1 class="home__title"><%= title %></h1>
    <.live_component module={mod} id="content" />
    """
  end
end

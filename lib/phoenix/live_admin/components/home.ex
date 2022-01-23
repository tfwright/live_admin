defmodule Phoenix.LiveAdmin.Components.Home do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns = %{title: title}) do
    ~H"""
    <h1 class="home__title"><%= title %></h1>
    <p class="home__intro">
      This is your admin home page.
      You will be able to customize this text with whatever copy you'd like to help orient admin users.
      Here will be some instructions for doing that customization.
    </p>
    """
  end
end

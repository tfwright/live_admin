defmodule LiveAdmin.Components.Home do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns = %{title: _title}) do
    ~H"""
    <h1 class="home__title"><%= @title %></h1>
    <%= render("home.html", assigns) %>
    """
  end

  def render("home.html", assigns) do
    {mod, func, args} = get_in(assigns, [:components, :home]) || {__MODULE__, :render_home, []}

    apply(mod, func, [assigns] ++ args)
  end

  def render_home(assigns) do
    ~H"""
    This is the default LiveAdmin home page.

    See README for instructions on how to configure your app to show something more useful here.
    """
  end
end

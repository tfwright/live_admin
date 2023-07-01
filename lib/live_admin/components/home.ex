defmodule LiveAdmin.Components.Home do
  use Phoenix.LiveView

  @impl true
  def mount(_params, %{"components" => %{home: mod}, "title" => title}, socket) do
    {:ok,
     assign(socket,
       mod: mod,
       title: title
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={@mod} id="content" />
    """
  end
end

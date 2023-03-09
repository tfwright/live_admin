defmodule LiveAdmin.Components.Home do
  use Phoenix.LiveView

  alias __MODULE__.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns = %{title: title}) do
    assigns = assign(assigns, mod: Application.get_env(:live_admin, :components, [])[:home] || Content, title: title)

    ~H"""
    <.live_component module={@mod} id="content" />
    """
  end
end

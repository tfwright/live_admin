defmodule DemoWeb.PostsAdmin.Home do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="content-header">
        Posts demo
      </div>
    </div>
    """
  end
end

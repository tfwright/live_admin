defmodule DemoWeb.Extra do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="content-header">
        Extra page
      </div>
    </div>
    """
  end
end

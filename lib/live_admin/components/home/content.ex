defmodule LiveAdmin.Components.Home.Content do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      This is the default LiveAdmin home page content.

      To use your own component, set the value of <code>:home</code>
      in the components option to a module that uses LiveComponent. LiveAdmin will render that component instead of this one in your app.
    </div>
    """
  end
end

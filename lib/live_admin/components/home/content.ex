defmodule LiveAdmin.Components.Home.Content do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="content-header">
        <h1 class="content-title">Dashboard</h1>
      </div>
      <div class="content-card">
        <div class="card-section">
          <p>Welcome to LiveAdmin!</p>
          <p>This is the default LiveAdmin home page content.</p>

          <p>
            To use your own component, set the value of <code>:home</code>
            in the components option to a module that uses LiveComponent. LiveAdmin will render that component instead of this one in your app.
          </p>

          <iframe
            src="https://github.com/sponsors/tfwright/card"
            title="Sponsor tfwright"
            height="225"
            width="600"
            style="border: 0;"
          >
          </iframe>
        </div>
      </div>
    </div>
    """
  end
end

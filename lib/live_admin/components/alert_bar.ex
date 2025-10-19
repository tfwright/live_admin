defmodule LiveAdmin.Components.AlertBar do
  use Phoenix.LiveView

  require Logger

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_, %{"session_id" => session_id}, socket) do
    if connected?(socket) do
      :ok = LiveAdmin.PubSub.subscribe(session_id)
      :ok = LiveAdmin.PubSub.subscribe()
    end

    {:ok, assign(socket, alerts: []), layout: false}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :current_alert, List.last(assigns.alerts))

    ~H"""
    <div id="alert-bar">
      <%= if @current_alert do %>
        <div class={"alert-bar #{elem(@current_alert, 1)}"}>
          <div class="alert-content">
            <svg
              class="alert-icon"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              phx-click={JS.push("dismiss", loading: "#alert-bar")}
              title="Close alert"
            >
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
            <span class="alert-message">{elem(@current_alert, 0)}</span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("dismiss", _, socket) do
    {:noreply, update(socket, :alerts, &Enum.drop(&1, 1))}
  end

  @impl true
  def handle_info(info = {:announce, %{message: message, type: type}}, socket) do
    Logger.debug("ANNOUNCE: #{inspect(info)}")
    {:noreply, update(socket, :alerts, &[{message, type} | &1])}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end

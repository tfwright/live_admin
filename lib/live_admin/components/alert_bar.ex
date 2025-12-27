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
    ~H"""
    <div id="alert-bar">
      <%= for {{alert, type}, index} <- Enum.with_index(@alerts) do %>
        <div
          class={"alert-bar #{type}"}
          id={"alert-#{index}"}
          phx-hook=".AlertItem"
          data-index={index}
          data-type={type}
        >
          <div class="alert-content">
            <%= if index == 0 && Enum.count(@alerts) > 1 do %>
              <div
                class="alert-count"
                phx-click={JS.push("dismiss", loading: "#alert-bar", value: %{index: index})}
              >
                {Enum.count(@alerts)}
              </div>
            <% else %>
              <svg
                class="alert-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                phx-click={JS.push("dismiss", loading: "#alert-bar", value: %{index: index})}
                title="Close alert"
              >
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            <% end %>

            <span class="alert-message">{alert}</span>
          </div>
        </div>
      <% end %>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".AlertItem">
      export default {
        mounted() {
          setTimeout(() => {
            if (this.el.dataset['type'] !== 'error') {
              this.pushEvent('dismiss', {index: parseInt(this.el.dataset['index'])});
            }
          }, 3000);
        }
      }
    </script>
    """
  end

  @impl true
  def handle_event("dismiss", %{"index" => 0}, socket),
    do: {:noreply, assign(socket, :alerts, [])}

  def handle_event("dismiss", %{"index" => index}, socket),
    do: {:noreply, update(socket, :alerts, &List.delete_at(&1, index))}

  @impl true
  def handle_info(info = {:announce, %{message: message, type: type}}, socket) do
    Logger.debug("ANNOUNCE: #{inspect(info)}")
    {:noreply, update(socket, :alerts, &[{message, type} | &1])}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end

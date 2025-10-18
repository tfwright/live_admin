defmodule LiveAdmin.Components.Container.Form.ArrayInput do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns = %{form: form, field: field}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:values, input_value(form, field) || [])

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns = %{disabled: true}) do
    ~H"""
    <div>
      <span class="resource__action--disabled">
        <ul>
          <%= for item <- @values do %>
            <li>{item}</li>
          <% end %>
        </ul>
      </span>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="array-input-wrapper" phx-hook="ArrayInput" id={@form[@field].id <> "_array_input"}>
      <%= for {item, idx} <- Enum.with_index(@values) do %>
        <button type="button" class="btn" phx-click={JS.push("remove", value: %{idx: idx}, target: @myself)}>
        {item}
        </button>
      <% end %>
      <input type="text" autocomplete="off" phx-keydown="add" phx-key="Enter" phx-target={@myself} />
    </div>
    """
  end

  @impl true
  def handle_event("add", %{"value" => item}, socket) do
    socket = assign(socket, values: socket.assigns.values ++ [item])

    {:noreply, socket}
  end

  def handle_event("remove", params, socket) do
    idx = params |> Map.fetch!("idx")

    socket =
      socket
      |> assign(values: List.delete_at(socket.assigns.values, idx))
      |> push_event("change", %{})

    {:noreply, socket}
  end
end

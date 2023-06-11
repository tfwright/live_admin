defmodule LiveAdmin.Components.Container.Form.SearchSelect do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin, only: [record_label: 2]
  alias LiveAdmin.Resource

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :options, [])}
  end

  @impl true
  def update(assigns = %{resource: resource, form: form, field: field}, socket) do
    selected_option =
      form
      |> input_value(field)
      |> case do
        nil -> nil
        "" -> nil
        id -> Resource.find!(id, resource.__live_admin_config__(:schema), assigns.session.prefix)
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:selected_option, selected_option)

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
        <%= if @selected_option do %>
          <%= record_label(@selected_option, @resource) %>
        <% else %>
          None
        <% end %>
      </span>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="resource__action--drop">
        <%= hidden_input(@form, @field, disabled: @disabled) %>
        <%= if @selected_option do %>
          <a
            href="#"
            phx-click={@handle_select}
            phx-value-field={@field}
            phx-value-value=""
            phx-target={@form_ref}
            class="resource__action--btn"
          >
            <%= record_label(@selected_option, @resource) %>
          </a>
        <% else %>
          <%= text_input(:search, :select,
            id: input_id(@form, @field) <> "search_select",
            disabled: @disabled,
            placeholder: "Search",
            phx_focus: "load_options",
            phx_keyup: "load_options",
            phx_target: @myself,
            phx_debounce: 200,
            autocomplete: "off"
          ) %>
        <% end %>
        <%= unless @selected_option do %>
          <nav>
            <ul>
              <%= if Enum.empty?(@options) do %>
                <li>No options</li>
              <% end %>
              <%= for option <- @options, option.id != input_value(@form, @field) do %>
                <li>
                  <a
                    href="#"
                    phx-click={@handle_select}
                    phx-value-field={@field}
                    phx-value-value={option.id}
                    phx-target={@form_ref}
                  >
                    <%= record_label(option, @resource) %>
                  </a>
                </li>
              <% end %>
            </ul>
          </nav>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "load_options",
        %{"value" => q},
        socket = %{assigns: %{resource: resource, session: session}}
      ) do
    options =
      resource
      |> Resource.list([search: q, prefix: socket.assigns.prefix], session)
      |> elem(0)

    {:noreply, assign(socket, :options, options)}
  end
end

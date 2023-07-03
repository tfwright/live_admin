defmodule LiveAdmin.Components.Container.Form.SearchSelect do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin, only: [record_label: 2, trans: 1]
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
        id -> Resource.find!(id, resource, assigns.session.prefix, assigns.repo)
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
          <%= trans("None") %>
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
            placeholder: trans("Search"),
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
                <li><%= trans("No options") %></li>
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
      |> Resource.list([search: q, prefix: socket.assigns.prefix], session, socket.assigns.repo)
      |> elem(0)

    {:noreply, assign(socket, :options, options)}
  end
end

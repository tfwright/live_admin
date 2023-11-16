defmodule LiveAdmin.Components.Container.Form.SearchSelect do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin, only: [record_label: 2, trans: 1]

  alias Phoenix.LiveView.JS
  alias LiveAdmin.Resource

  @impl true
  def update(assigns = %{form: form, field: field}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(options: [])
      |> assign_selected_option(input_value(form, field))

    {:ok, socket}
  end

  @impl true
  def render(assigns = %{disabled: true}) do
    ~H"""
    <div>
      <%= if @selected_option do %>
        <%= record_label(@selected_option, @resource) %>
      <% else %>
        <%= trans("None") %>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="search_select" phx-hook="SearchSelect" id={input_id(@form, @field) <> "_search_select"}>
      <%= hidden_input(@form, @field,
        disabled: @disabled,
        value: if(@selected_option, do: @selected_option.id)
      ) %>
      <%= if @selected_option do %>
        <a
          href="#"
          phx-click={JS.push("select", value: %{id: nil}, target: @myself, page_loading: true)}
          class="button__remove"
        />
        <%= record_label(@selected_option, @resource) %>
      <% else %>
        <div class="search_select--drop">
          <input
            type="text"
            id={input_id(@form, @field)}
            disabled={@disabled}
            placeholder={trans("Search")}
            autocomplete="off"
            phx-focus="load_options"
            phx-keyup="load_options"
            phx-target={@myself}
            phx-debounce={200}
          />
          <div>
            <nav>
              <ul>
                <%= if Enum.empty?(@options) do %>
                  <li><%= trans("No options") %></li>
                <% end %>
                <%= for option <- @options, option.id != input_value(@form, @field) do %>
                  <li>
                    <a
                      href="#"
                      phx-click={
                        JS.push("select",
                          value: %{id: option.id},
                          target: @myself,
                          page_loading: true
                        )
                      }
                    >
                      <%= record_label(option, @resource) %>
                    </a>
                  </li>
                <% end %>
              </ul>
            </nav>
          </div>
        </div>
      <% end %>
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

  def handle_event("select", %{"id" => id}, socket) do
    socket =
      socket
      |> assign_selected_option(id)
      |> push_event("change", %{})

    {:noreply, socket}
  end

  defp assign_selected_option(socket, id) when id in [nil, ""],
    do: assign(socket, :selected_option, nil)

  defp assign_selected_option(
         socket = %{assigns: %{selected_option: %{id: selected_option_id}}},
         id
       )
       when selected_option_id == id,
       do: socket

  defp assign_selected_option(socket, id),
    do:
      assign(
        socket,
        :selected_option,
        Resource.find!(id, socket.assigns.resource, socket.assigns.prefix, socket.assigns.repo)
      )
end

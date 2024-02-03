defmodule LiveAdmin.Components.Container.Form.SearchSelect do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  import LiveAdmin, only: [record_label: 3, trans: 1]
  import LiveAdmin.Components

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
        <%= record_label(@selected_option, @resource, @config) %>
      <% else %>
        <%= trans("None") %>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="search_select"
      phx-hook="SearchSelect"
      id={input_id(@form, @field) <> "_search_select"}
    >
      <%= hidden_input(@form, @field,
        disabled: @disabled,
        value:
          if(@selected_option,
            do: Map.fetch!(@selected_option, LiveAdmin.primary_key!(@resource))
          ),
        id: input_id(@form, @field) <> "_hidden"
      ) %>
      <%= if @selected_option do %>
        <a
          href="#"
          phx-click={JS.push("select", value: %{key: nil}, target: @myself, page_loading: true)}
          class="button__remove"
        />
        <%= record_label(@selected_option, @resource, @config) %>
      <% else %>
        <.dropdown
          :let={option}
          id={input_id(@form, @field) <> "_dropdown"}
          label="Select"
          items={
            Enum.filter(
              @options,
              &(Map.fetch!(&1, LiveAdmin.primary_key!(@resource)) != input_value(@form, @field))
            )
          }
        >
          <:empty_label>
            <%= trans("No options") %>
          </:empty_label>
          <:control>
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
          </:control>
          <a
            href="#"
            phx-click={
              JS.push("select",
                value: %{key: Map.fetch!(option, LiveAdmin.primary_key!(@resource))},
                target: @myself,
                page_loading: true
              )
            }
          >
            <%= record_label(option, @resource, @config) %>
          </a>
        </.dropdown>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event(
        "load_options",
        %{"value" => q},
        socket = %{assigns: %{resource: resource, session: session, config: config}}
      ) do
    options =
      resource
      |> Resource.list(
        [search: q, prefix: socket.assigns.prefix],
        session,
        socket.assigns.repo,
        config
      )
      |> elem(0)

    {:noreply, assign(socket, :options, options)}
  end

  def handle_event("select", %{"key" => key}, socket) do
    socket =
      socket
      |> assign_selected_option(key)
      |> push_event("change", %{})

    {:noreply, socket}
  end

  defp assign_selected_option(socket, key) when key in [nil, ""],
    do: assign(socket, :selected_option, nil)

  defp assign_selected_option(
         socket = %{assigns: %{selected_option: %{key: selected_option_key}}},
         key
       )
       when selected_option_key == key,
       do: socket

  defp assign_selected_option(socket, key),
    do:
      assign(
        socket,
        :selected_option,
        Resource.find!(key, socket.assigns.resource, socket.assigns.prefix, socket.assigns.repo)
      )
end

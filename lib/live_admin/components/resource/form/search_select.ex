defmodule LiveAdmin.Components.Container.Form.SearchSelect do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  import LiveAdmin
  import LiveAdmin.Components

  alias Phoenix.LiveView.JS
  alias LiveAdmin.Resource

  @impl true
  def update(assigns = %{form: form, field: field}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_selected_option(input_value(form, field))
      |> assign_async(
        [:options],
        fn ->
          options =
            assigns.resource
            |> Resource.list(
              [prefix: assigns.prefix],
              assigns.session,
              assigns.repo,
              assigns.config
            )
            |> elem(0)

          {:ok, %{options: options}}
        end,
        reset: true
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns = %{disabled: true}) do
    ~H"""
    <div>
      <%= if @selected_option do %>
        {record_label(@selected_option, @resource, @config)}
      <% else %>
        {trans("None")}
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={"search-select-container #{if @options.loading, do: "loading"}"}
      phx-hook="SearchSelect"
      id={@form[@field].id <> "_search_select"}
    >
      <input
        type="hidden"
        value={
          if(@selected_option,
            do: Map.fetch!(@selected_option, LiveAdmin.primary_key!(@resource))
          )
        }
        name={@form[@field].name}
      />
      <%= if @selected_option do %>
        <button
          type="button"
          phx-click={JS.push("select", value: %{key: nil}, target: @myself)}
          class="btn"
        >
          {record_label(@selected_option, @resource, @config)}
        </button>
      <% else %>
        <input
          type="text"
          class="form-input"
          phx-keyup="load_options"
          phx-target={@myself}
          phx-debounce={200}
          placeholder={trans("Search") <> "..."}
        />
        <ul class="select-options">
          <li class="spinner" />
          <%= if @options.ok? do %>
            <%= for record <- @options.result do %>
              <li phx-click={
                JS.push("select",
                  value: %{key: Map.fetch!(record, LiveAdmin.primary_key!(@resource))},
                  target: @myself,
                  loading: "#" <> @form[@field].id <> "_search_select"
                )
              }>
                {record_label(record, @resource, @config)}
              </li>
            <% end %>
            <%= if Enum.empty?(@options.result) do %>
              <li>{trans("No options")}</li>
            <% end %>
          <% end %>
        </ul>
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
    socket =
      assign_async(
        socket,
        [:options],
        fn ->
          options =
            resource
            |> Resource.list(
              [search: q, prefix: socket.assigns.prefix],
              session,
              socket.assigns.repo,
              config
            )
            |> elem(0)

          {:ok, %{options: options}}
        end,
        reset: true
      )

    {:noreply, socket}
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
